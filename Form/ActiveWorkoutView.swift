import SwiftData
import SwiftUI
import UIKit

struct WorkoutInputField: Hashable {
    enum Value: Hashable {
        case load
        case repetitions
    }

    let exerciseID: String
    let setID: UUID
    let value: Value
}

@MainActor
struct ActiveWorkoutView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) var modelContext
    @Query(sort: \WorkoutRecord.date, order: .reverse) var history: [WorkoutRecord]
    @AppStorage("keep-screen-awake") var keepScreenAwake = true
    @AppStorage("progression-load-increment") var loadIncrement = 2.5

    let routine: RoutineTemplate
    let onDone: () -> Void

    @State var session: WorkoutSessionState
    @State var showingExerciseList = false
    @State var showingDiscardConfirmation = false
    @State var showingEmptyFinishConfirmation = false
    @State var showingIncompleteFinishConfirmation = false
    @State var completedRecord: WorkoutRecord?
    @State var saveErrorMessage: String?
    @State var isKeyboardVisible = false
    @State var didEndSession = false
    @State var snapshotSaveTask: Task<Void, Never>?
    @FocusState var focusedInput: WorkoutInputField?

    init(
        routine: RoutineTemplate,
        snapshot: ActiveWorkoutSnapshot? = nil,
        onDone: @escaping () -> Void = {}
    ) {
        self.routine = routine
        self.onDone = onDone
        _session = State(initialValue: WorkoutSessionState(
            routine: routine,
            snapshot: snapshot
        ))
    }

    var body: some View {
        Group {
            if let completedRecord {
                WorkoutCompletionView(record: completedRecord) {
                    onDone()
                    dismiss()
                }
            } else {
                workoutLogger
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if completedRecord == nil {
                ActiveWorkoutHeader(
                    index: routine.id,
                    progress: "\(session.completedMovementCount) of \(session.drafts.count) movements",
                    requestFinish: requestFinish,
                    pause: saveAndClose,
                    requestDiscard: { showingDiscardConfirmation = true }
                )
            } else {
                CompletionHeader()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Discard this session?", isPresented: $showingDiscardConfirmation) {
            Button("Discard session", role: .destructive, action: discardWorkout)
            Button("Keep training", role: .cancel) {}
        }
        .confirmationDialog(
            "Finish without recording anything?",
            isPresented: $showingEmptyFinishConfirmation
        ) {
            Button("Finish empty session", role: .destructive, action: finishWorkout)
            Button("Keep training", role: .cancel) {}
        } message: {
            Text("No completed sets or cardio entries will be saved.")
        }
        .confirmationDialog(
            "Finish this partial session?",
            isPresented: $showingIncompleteFinishConfirmation
        ) {
            Button("Finish partial session", role: .destructive, action: finishWorkout)
            Button("Keep training", role: .cancel) {}
        } message: {
            Text("\(session.completedMovementCount) of \(session.drafts.count) movements are complete. Only completed sets and cardio entries will be saved.")
        }
        .leadingEdgeSwipe {
            if completedRecord == nil { saveAndClose() }
        }
        .alert("Couldn’t save session", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? "")
        }
        .onAppear {
            guard !didEndSession, completedRecord == nil else { return }
            WorkoutLiveActivityController.isSessionPresented = true
            session.prefillFromHistory(history)
            session.resume()
            updateScreenAwakeState()
            persistImmediately()
            scheduleRestFeedback()
            Task { await WorkoutLiveActivityController.begin(session: session) }
        }
        .onChange(of: session.snapshot) { _, snapshot in
            guard !didEndSession, completedRecord == nil else { return }
            scheduleSnapshotSave(snapshot)
            Task { await WorkoutLiveActivityController.update(session: session) }
        }
        .onChange(of: session.restEnd) { _, _ in
            scheduleRestFeedback()
        }
        .onChange(of: scenePhase) { _, phase in
            guard !didEndSession, completedRecord == nil else { return }
            if phase == .background { persistImmediately() }
            if phase == .active { Task { await WorkoutLiveActivityController.update(session: session) } }
        }
        .onChange(of: keepScreenAwake) { _, _ in
            updateScreenAwakeState()
        }
        .onDisappear {
            WorkoutLiveActivityController.isSessionPresented = false
            UIApplication.shared.isIdleTimerDisabled = false
            snapshotSaveTask?.cancel()
            guard !didEndSession, completedRecord == nil else { return }
            session.pause()
            persistImmediately()
            Task { await WorkoutLiveActivityController.pause(snapshot: session.snapshot) }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillShowNotification
        )) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillHideNotification
        )) { _ in
            isKeyboardVisible = false
        }
    }

    private var workoutLogger: some View {
        @Bindable var session = session
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("your own pace.").font(AtelierType.script(38))
                    HStack {
                        Text("Choose any movement. Check off each set.")
                            .font(.caption).foregroundStyle(InkPalette.softInk)
                        Spacer()
                        Button { focusedInput = nil; showingExerciseList = true } label: {
                            Image(systemName: "arrow.up.arrow.down").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Reorder exercises")
                    }
                }

                ForEach($session.drafts) { $draft in
                    ExerciseLoggingCard(
                        draft: $draft,
                        previous: ProgressionEngine.latestCompleted(for: draft.template, in: history),
                        recommendation: nil,
                        isExpanded: true, focusedInput: $focusedInput,
                        toggleExpanded: {},
                        didUpdateSet: { completed, kind in
                            focusedInput = nil
                            guard completed else { return }
                            session.didCompleteSet(
                                for: draft.id, kind: kind,
                                restSeconds: ExerciseRestPreference.seconds(for: draft.template)
                            )
                        }
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    InkDivider()
                    HStack {
                        Text("a little further.").font(AtelierType.script(30))
                        Spacer()
                        DemonstrationImage(assetName: "walk").frame(width: 64, height: 64)
                    }
                    Text("Treadmill walk · 15 min suggested")
                        .font(.subheadline).foregroundStyle(InkPalette.softInk)
                    Text("Speed 5 · incline 7.5. Check console units and keep the effort conversational.")
                        .font(.caption).foregroundStyle(InkPalette.softInk)
                    CardioLoggingSection(
                        prescribedWalk: true, entries: $session.cardioDrafts,
                        timedWalk: session.timedWalk,
                        startWalk: { focusedInput = nil; session.startTimedWalk() },
                        finishWalk: { session.finishTimedWalk() }
                    )
                }
                InkPrimaryButton(title: "Finish session", action: requestFinish)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(PaperBackground())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if let end = session.restEnd {
                    InkDivider()
                    RestTimer(end: end, adjust: adjustRest, cancel: clearRest, complete: completeRest)
                }
                if isKeyboardVisible { keyboardControls }
            }
            .background(InkPalette.paper)
        }
        .sheet(isPresented: $showingExerciseList) {
            NavigationStack {
                List {
                    ForEach(session.drafts) { draft in
                        HStack {
                            Text(draft.template.name)
                            Spacer()
                            Text("\(draft.sets.filter { $0.completed && $0.kind == .working }.count)/\(draft.sets.filter { $0.kind == .working }.count)")
                                .font(.caption.monospacedDigit()).foregroundStyle(InkPalette.softInk)
                        }.padding(.vertical, 8)
                    }
                    .onMove { source, destination in
                        session.drafts.move(fromOffsets: source, toOffset: destination)
                    }
                }
                .environment(\.editMode, .constant(.active))
                .scrollContentBackground(.hidden)
                .background(PaperBackground())
                .navigationTitle("Your exercise order")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { showingExerciseList = false } }
            }
        }
    }

    private var keyboardControls: some View {
        HStack(spacing: 2) {
            Button { moveInputFocus(by: -1) } label: {
                Image(systemName: "chevron.up").frame(width: 44, height: 44)
            }
            .disabled(!canMoveInputFocus(by: -1))
            .accessibilityLabel("Previous field")

            Button { moveInputFocus(by: 1) } label: {
                Image(systemName: "chevron.down").frame(width: 44, height: 44)
            }
            .disabled(!canMoveInputFocus(by: 1))
            .accessibilityLabel("Next field")

            Spacer(minLength: 8)

            Button { adjustFocusedInput(by: -1) } label: {
                Image(systemName: "minus").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Decrease value")

            Button { adjustFocusedInput(by: 1) } label: {
                Image(systemName: "plus").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Increase value")

            Button("Done") {
                dismissKeyboard()
                focusedInput = nil
            }
            .font(AtelierType.script(17))
            .foregroundStyle(InkPalette.cinnabar)
            .frame(minWidth: 64, minHeight: 44, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(PaperSurface())
    }

}
