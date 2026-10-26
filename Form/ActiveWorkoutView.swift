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
    var id: String { value == .load ? EntryID.load(setID) : EntryID.count(setID) }
}

@MainActor
struct ActiveWorkoutView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) var reduceMotion
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
    @State private var didPrefill = false
    @State private var restArrival = 0
    @State var snapshotSaveTask: Task<Void, Never>?
    @State var entryForm = NumberEntryForm()
    var focusedInput: WorkoutInputField? {
        get { inputFields.first { $0.id == entryForm.focusedID } }
        nonmutating set { entryForm.focusedID = newValue?.id }
    }

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
                .transition(.opacity)
            } else {
                workoutLogger
            }
        }
        .sensoryFeedback(.success, trigger: completedRecord != nil)
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
        .environment(entryForm)
        .onChange(of: numberFields, initial: true) { _, fields in
            entryForm.configure(fields, order: fields.map(\.id))
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
            Button("Save partial session", action: finishWorkout)
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
            if !didPrefill {
                session.prefillFromHistory(history)
                didPrefill = true
            }
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
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) { workoutFields }
                .scrollDismissesKeyboard(.interactively)
                .background(PaperBackground())
                .safeAreaInset(edge: .bottom, spacing: 0) { loggerFooter }
                .task(id: entryForm.focusRequest) {
                    await Task.yield()
                    if let id = entryForm.focusedID {
                        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                    if let id = entryForm.focusedID {
                        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) }
                    }
                }
                .sheet(isPresented: $showingExerciseList) { exerciseOrderSheet }
        }
    }

    private var workoutFields: some View {
        @Bindable var session = session
        return
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(routine.name.lowercased()).font(AtelierType.script(38))
                    HStack {
                        Text("Choose any movement. Check off each set.")
                            .font(.caption).foregroundStyle(InkPalette.softInk)
                        Spacer()
                        Button { focusedInput = nil; showingExerciseList = true } label: {
                            Image(systemName: "arrow.up.arrow.down").font(.system(size: 20)).frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Reorder exercises")
                    }
                }

                ForEach($session.drafts) { $draft in
                    ExerciseLoggingCard(
                        draft: $draft,
                        previous: ProgressionEngine.latestCompleted(for: draft.template, in: history),
                        recommendation: nil,
                        isExpanded: true,
                        toggleExpanded: {},
                        didUpdateSet: { completed, kind in
                            focusedInput = nil
                            guard completed else { return }
                            session.didCompleteSet(
                                for: draft.id, kind: kind,
                                restSeconds: ExerciseRestPreference.seconds(for: draft.template)
                            )
                            if session.restEnd != nil { restArrival += 1 }
                        }
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    InkDivider()
                    HStack {
                        Text("cardio").font(AtelierType.script(30))
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

    private var loggerFooter: some View {
        VStack(spacing: 0) {
            if let end = session.restEnd {
                VStack(spacing: 0) {
                    InkDivider()
                    RestTimer(end: end, arrival: restArrival, compact: isKeyboardVisible,
                              adjust: adjustRest, cancel: clearRest, complete: completeRest)
                }
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
            if isKeyboardVisible {
                if focusedInput != nil {
                    EntryKeyboardControls(adjust: { adjustFocusedInput(by: $0) })
                } else {
                    EntryKeyboardControls()
                }
            }
        }
        .background(InkPalette.paper)
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86), value: session.restEnd != nil)
    }

    private var exerciseOrderSheet: some View {
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
