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
    @Environment(\.modelContext) var modelContext
    @Query(sort: \WorkoutRecord.date, order: .reverse) var history: [WorkoutRecord]
    @AppStorage("keep-screen-awake") var keepScreenAwake = true
    @AppStorage("progression-load-increment") var loadIncrement = 2.5

    let routine: RoutineTemplate
    let onDone: () -> Void

    @State var session: WorkoutSessionState
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
            session.prefillFromHistory(history)
            session.resume()
            updateScreenAwakeState()
            persistImmediately()
            scheduleRestFeedback()
            Task { await WorkoutLiveActivityController.begin(session: session) }
        }
        .onChange(of: session.snapshot) { _, snapshot in
            scheduleSnapshotSave(snapshot)
            Task { await WorkoutLiveActivityController.update(session: session) }
        }
        .onChange(of: session.restEnd) { _, _ in
            scheduleRestFeedback()
        }
        .onChange(of: keepScreenAwake) { _, _ in
            updateScreenAwakeState()
        }
        .onDisappear {
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

        return ZStack {
            PaperBackground()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach($session.drafts) { $draft in
                            ExerciseLoggingCard(
                                draft: $draft,
                                previous: ProgressionEngine.latestCompleted(
                                    for: draft.template,
                                    in: history
                                ),
                                recommendation: ProgressionEngine.recommendation(
                                    for: draft.template,
                                    performances: ProgressionEngine.performances(
                                        for: draft.template,
                                        in: history
                                    )
                                ),
                                isExpanded: session.expandedExerciseID == draft.id,
                                focusedInput: $focusedInput,
                                toggleExpanded: {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        session.expandedExerciseID = session.expandedExerciseID == draft.id
                                            ? nil
                                            : draft.id
                                    }
                                },
                                didUpdateSet: { completed, kind in
                                    guard completed else { return }
                                    session.didCompleteSet(for: draft.id, kind: kind)
                                    withAnimation(.easeOut(duration: 0.22)) {}
                                }
                            )
                            .id(draft.id)
                        }

                        CardioLoggingSection(entries: $session.cardioDrafts)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 14)
                    .padding(.bottom, session.restEnd == nil ? 96 : 158)
                }
                .onChange(of: session.expandedExerciseID) { oldValue, newValue in
                    guard oldValue != nil, let newValue else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        withAnimation(.easeOut(duration: 0.24)) {
                            proxy.scrollTo(newValue, anchor: .top)
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Group {
                if isKeyboardVisible {
                    keyboardControls
                } else {
                    VStack(spacing: 9) {
                        if let restEnd = session.restEnd {
                            RestTimer(
                                end: restEnd,
                                adjust: adjustRest,
                                cancel: clearRest,
                                complete: completeRest
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        InkPrimaryButton(title: "Finish session", action: requestFinish)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(InkPalette.paper)
                    .overlay(alignment: .top) {
                        Rectangle().fill(InkPalette.ink).frame(height: 1)
                    }
                }
            }
            .animation(.easeOut(duration: 0.16), value: isKeyboardVisible)
            .animation(.easeOut(duration: 0.2), value: session.restEnd)
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
            .font(.system(.body, design: .serif, weight: .semibold))
            .foregroundStyle(InkPalette.cinnabar)
            .frame(minWidth: 64, minHeight: 44, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(PaperSurface())
    }

}
