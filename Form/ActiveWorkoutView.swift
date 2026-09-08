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
    @State var showingMovementNotes = false
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
                    close: saveAndClose,
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
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(session.restEnd != nil ? "SET SAVED" : (session.expandedExerciseID == nil ? "CARDIO" : "EXERCISE \(currentIndex + 1) OF \(session.drafts.count)"))
                        .font(.caption2).tracking(2).foregroundStyle(InkPalette.softInk)
                    Spacer()
                    Button { showingExerciseList = true } label: {
                        Image(systemName: "list.bullet").frame(width: 44, height: 44)
                    }.accessibilityLabel("Session exercise list")
                }
                if let end = session.restEnd {
                    Text("room to rest.").font(AtelierType.script(42))
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let seconds = max(0, Int(end.timeIntervalSince(context.date).rounded(.up)))
                        Text(seconds == 0 ? "ready." : String(format: "%d:%02d", seconds / 60, seconds % 60))
                            .font(.system(size: 58, weight: .light)).monospacedDigit()
                            .onChange(of: seconds) { _, value in if value == 0 { completeRest() } }
                    }
                    PaperVignette(name: "pause", height: 230)
                    Text("UP NEXT").font(.caption2).tracking(2).foregroundStyle(InkPalette.softInk)
                    Text(session.currentExerciseName).font(.title3)
                    HStack {
                        Button("−30 sec") { adjustRest(by: -30) }
                        Spacer()
                        Button("+30 sec") { adjustRest(by: 30) }
                    }.font(.subheadline).frame(minHeight: 44)
                } else if session.expandedExerciseID != nil, session.drafts.indices.contains(currentIndex) {
                    ExerciseLoggingCard(
                        draft: $session.drafts[currentIndex],
                        previous: ProgressionEngine.latestCompleted(for: session.drafts[currentIndex].template, in: history),
                        recommendation: nil,
                        isExpanded: true, focusedInput: $focusedInput,
                        toggleExpanded: {},
                        didUpdateSet: { completed, kind in
                            guard completed else { return }
                            focusedInput = nil
                            session.didCompleteSet(for: session.drafts[currentIndex].id, kind: kind)
                        }
                    )
                    Button("Movement notes") { showingMovementNotes = true }
                        .font(AtelierType.script(20)).frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    Text("a little further.").font(AtelierType.script(42))
                    Text("Treadmill walk").font(.subheadline).foregroundStyle(InkPalette.softInk)
                    PaperVignette(name: "walk", height: 230)
                    if let start = session.timedWalk?.timerStartedAt {
                        Text(start, style: .timer).font(.system(size: 48, weight: .light)).monospacedDigit()
                    } else {
                        Text("15 min").font(.system(size: 44, weight: .light))
                    }
                    HStack(spacing: 65) {
                        VStack(alignment: .leading, spacing: 6) { Text("SPEED").font(.caption2); Text("5").font(.title2) }
                        VStack(alignment: .leading, spacing: 6) { Text("INCLINE").font(.caption2); Text("7.5").font(.title2) }
                    }.padding(.vertical, 8)
                    Text("Check console units.\nKeep the effort conversational.")
                        .font(.caption).foregroundStyle(InkPalette.softInk).lineSpacing(5)
                    CardioLoggingSection(prescribedWalk: true, entries: $session.cardioDrafts)
                }
            }.padding(.horizontal, 28).padding(.bottom, 24)
        }
        .background(PaperBackground())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isKeyboardVisible { keyboardControls }
            else {
                VStack(spacing: 3) {
                    InkPrimaryButton(title: primaryTitle, action: primaryAction)
                    if session.expandedExerciseID == nil && session.restEnd == nil && session.timedWalk == nil {
                        Button(session.cardioDrafts.isEmpty ? "Skip cardio" : "Finish session", action: requestFinish)
                            .font(AtelierType.script(19)).frame(minHeight: 44)
                    }
                }.padding(.horizontal, 28).padding(.vertical, 10).background(.white)
            }
        }
        .sheet(isPresented: $showingExerciseList) {
            NavigationStack {
                List {
                    ForEach(session.drafts) { draft in
                        Button {
                            session.finishTimedWalk()
                            clearRest()
                            session.expandedExerciseID = draft.id
                            showingExerciseList = false
                        } label: {
                            HStack {
                                Text(draft.template.name)
                                Spacer()
                                Text(session.isExerciseComplete(draft) ? "✓" : "\(draft.sets.filter(\.completed).count)/\(draft.template.sets)")
                            }.frame(minHeight: 44)
                        }
                    }
                    Button("Treadmill walk") {
                        clearRest(); session.expandedExerciseID = nil; showingExerciseList = false
                    }
                    Button("Finish partial session") { showingExerciseList = false; requestFinish() }
                }.navigationTitle("This session").navigationBarTitleDisplayMode(.inline)
                    .toolbar { Button("Done") { showingExerciseList = false } }
            }
        }
        .sheet(isPresented: $showingMovementNotes) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(session.currentExerciseName).font(AtelierType.script(32))
                        Text("Leave about 2 reps in reserve.")
                        if session.drafts.indices.contains(currentIndex) {
                            ForEach(session.drafts[currentIndex].template.formCues, id: \.self) { Text($0) }
                            if session.drafts[currentIndex].id == "reverse-lunge" { Text("Record repetitions per side.") }
                        }
                    }.padding(28)
                }.toolbar { Button("Done") { showingMovementNotes = false } }
            }.presentationDetents([.medium, .large])
        }
    }

    private var currentIndex: Int {
        session.drafts.firstIndex { $0.id == session.expandedExerciseID } ?? 0
    }

    private var primaryTitle: String {
        if session.restEnd != nil { return "Ready for the next one →" }
        if session.expandedExerciseID == nil { return session.timedWalk == nil ? "Start walk →" : "Finish walk →" }
        if session.drafts.indices.contains(currentIndex), session.isExerciseComplete(session.drafts[currentIndex]) { return "Next exercise →" }
        return "Complete set ✓"
    }

    private func primaryAction() {
        dismissKeyboard(); focusedInput = nil
        if session.restEnd != nil { clearRest(); return }
        if session.expandedExerciseID == nil {
            if session.timedWalk == nil { session.startTimedWalk() }
            else { session.finishTimedWalk(); requestFinish() }
            return
        }
        guard session.drafts.indices.contains(currentIndex) else { return }
        let index = currentIndex
        if let set = session.drafts[index].sets.firstIndex(where: { !$0.completed }) {
            session.drafts[index].sets[set].completed = true
            session.didCompleteSet(for: session.drafts[index].id, kind: session.drafts[index].sets[set].kind)
        } else {
            session.expandedExerciseID = session.drafts.dropFirst(index + 1).first(where: { !session.isExerciseComplete($0) })?.id
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
