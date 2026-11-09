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
    @State private var discardAfterSheet = false
    @State var showingEmptyFinishConfirmation = false
    @State var showingIncompleteFinishConfirmation = false
    @State var completedRecord: WorkoutRecord?
    @State var saveErrorMessage: String?
    @State var isKeyboardVisible = false
    @State var didEndSession = false
    @State private var didPrefill = false
    @State private var didRestoreEntries = false
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

    private var presentation: some View {
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
                EmptyView()
            }
        }
        .environment(entryForm)
        .onChange(of: numberFields, initial: true) { _, fields in
            entryForm.configure(fields, order: fields.map(\.id))
            if !didRestoreEntries {
                entryForm.restoreEditedTexts(session.entryTexts)
                didRestoreEntries = true
            }
        }
        .onChange(of: entryForm.editedTexts) { _, texts in session.entryTexts = texts }
        .onChange(of: entryForm.focusedID) { _, id in
            guard let id else { return }
            if let field = inputFields.first(where: { $0.id == id }) {
                session.expandedExerciseID = field.exerciseID
                session.selectSet(field.setID, for: field.exerciseID)
            } else if id.hasPrefix("cardio-") { session.isCardioExpanded = true }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var guardedPresentation: some View {
        presentation
        .sheet(isPresented: $showingDiscardConfirmation, onDismiss: {
            if discardAfterSheet { discardAfterSheet = false; discardWorkout() }
        }) {
            CounterweightDiscardSheet(discard: {
                discardAfterSheet = true; showingDiscardConfirmation = false
            }, keep: { showingDiscardConfirmation = false })
        }
        .alert(
            "End this workout?",
            isPresented: $showingEmptyFinishConfirmation
        ) {
            Button("End workout", role: .destructive, action: discardWorkout)
            Button("Keep training", role: .cancel) {}
        } message: {
            Text("No completed sets or cardio entries will be saved.")
        }
        .alert(
            "Finish workout?",
            isPresented: $showingIncompleteFinishConfirmation
        ) {
            Button("Save recorded work", action: finishWorkout)
            Button("Keep training", role: .cancel) {}
        } message: {
            Text(finishReviewMessage)
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
    }

    var body: some View {
        guardedPresentation
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
                .task {
                    await Task.yield()
                    guard entryForm.focusedID == nil, let id = session.expandedExerciseID else { return }
                    proxy.scrollTo(id, anchor: .top)
                }
                .task(id: entryForm.focusRequest) {
                    await Task.yield()
                    if let id = entryForm.focusedID {
                        withAnimation(reduceMotion ? nil : CounterweightMotion.quiet) { proxy.scrollTo(id, anchor: .center) }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                    if let id = entryForm.focusedID {
                        withAnimation(reduceMotion ? nil : CounterweightMotion.quiet) { proxy.scrollTo(id, anchor: .center) }
                    }
                }
                .sheet(isPresented: $showingExerciseList) { exerciseOrderSheet }
        }
    }

    private var workoutFields: some View {
        @Bindable var session = session
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(routine.name).font(.title2.weight(.bold)).accessibilityAddTraits(.isHeader)
                Text("\(session.recordedSetCount) set\(session.recordedSetCount == 1 ? "" : "s") recorded")
                    .font(.caption).foregroundStyle(InkPalette.softInk).contentTransition(.numericText())
            }.padding(.vertical, 24)
            HStack {
                Text("Exercises").font(.caption).foregroundStyle(InkPalette.softInk)
                Spacer()
                CounterweightControl(title: "Reorder", symbol: "arrow.up.arrow.down") {
                    entryForm.done(); showingExerciseList = true
                }
            }.padding(.bottom, 8)
            ForEach($session.drafts) { $draft in
                ExerciseLoggingCard(
                    draft: $draft,
                    selectedSetID: Binding(get: { session.selectedSetID(for: draft.id) }, set: { id in
                        if let id { session.selectSet(id, for: draft.id) }
                    }),
                    previous: ProgressionEngine.latestCompleted(for: draft.template, in: history.filter { $0.date < session.startedAt }),
                    recommendation: nil,
                    isExpanded: session.expandedExerciseID == draft.id,
                    toggleExpanded: {
                        entryForm.done(); dismissKeyboard()
                        withAnimation(reduceMotion ? nil : CounterweightMotion.expand) {
                            session.expandedExerciseID = session.expandedExerciseID == draft.id ? nil : draft.id
                        }
                    },
                    didUpdateSet: { id, completed, kind in
                        focusedInput = nil
                        withAnimation(reduceMotion ? nil : CounterweightMotion.disclosure) {
                            if completed {
                                session.didCompleteSet(for: draft.id, kind: kind, setID: id,
                                                       restSeconds: ExerciseRestPreference.seconds(for: draft.template))
                            } else { session.undoSet(id) }
                        }
                    },
                    didRemoveSet: { session.undoSet($0) }
                ).id(draft.id)
            }
            InkDivider()
            Button {
                entryForm.done(); dismissKeyboard()
                withAnimation(reduceMotion ? nil : CounterweightMotion.disclosure) { session.isCardioExpanded.toggle() }
            } label: {
                HStack(spacing: 14) {
                    DemonstrationImage(assetName: "walk").frame(width: 54, height: 54)
                    Text("Walk").font(.headline)
                    Spacer()
                    Text(session.timedWalk != nil ? "In progress" : session.cardioDrafts.isEmpty ? "Optional" : "Recorded")
                        .font(.caption).foregroundStyle(InkPalette.softInk)
                    Image(systemName: "chevron.down").font(.caption)
                        .rotationEffect(.degrees(session.isCardioExpanded ? 180 : 0))
                }.padding(.vertical, 14).contentShape(Rectangle())
            }.buttonStyle(PressableButtonStyle())
                .accessibilityValue(session.isCardioExpanded ? "Expanded" : "Collapsed")
            if session.isCardioExpanded {
                CardioLoggingSection(prescribedWalk: true, entries: $session.cardioDrafts,
                                     timedWalk: session.timedWalk,
                                     startWalk: { focusedInput = nil; session.startTimedWalk() },
                                     finishWalk: { session.finishTimedWalk() })
                    .padding(.bottom, 20)
                    .transition(CounterweightMotion.transition(reduced: reduceMotion))
            }
            InkDivider()
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) { finishControls }
                VStack(alignment: .leading, spacing: 12) { finishControls }
            }.padding(.top, 20)
        }
        .padding(.horizontal, 24).padding(.bottom, 28)
        .animation(reduceMotion ? nil : CounterweightMotion.disclosure, value: session.isCardioExpanded)
    }

    @ViewBuilder private var finishControls: some View {
        Text("\(session.recordedSetCount) set\(session.recordedSetCount == 1 ? "" : "s")")
            .font(.caption).foregroundStyle(InkPalette.softInk)
        InkPrimaryButton(title: "Finish workout", action: requestFinish)
    }

    private var loggerFooter: some View {
        VStack(spacing: 0) {
            InkDivider()
            ZStack {
                if let end = session.restEnd {
                    RestTimer(end: end, compact: true, exerciseName: session.restExerciseName,
                              adjust: adjustRest, cancel: clearRest, complete: completeRest)
                        .transition(.opacity)
                } else {
                    HStack {
                        Button {
                            let exercise = session.drafts.first(where: { $0.id == session.expandedExerciseID })?.template
                            let seconds = exercise.map { ExerciseRestPreference.seconds(for: $0) } ?? 60
                            session.startManualRest(seconds: seconds > 0 ? seconds : 60)
                        } label: {
                            Label("Rest", systemImage: "timer").font(.subheadline).frame(minHeight: 44)
                        }.buttonStyle(PressableButtonStyle()).accessibilityLabel("Start rest timer")
                        Spacer()
                        if let exercise = session.drafts.first(where: { $0.id == session.expandedExerciseID })?.template {
                            ExerciseRestPicker(exercise: exercise).id(exercise.id)
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .transition(.opacity)
                }
            }
            .frame(minHeight: 76)
            .padding(.horizontal, 16).padding(.vertical, 4)
            if isKeyboardVisible {
                if focusedInput != nil {
                    EntryKeyboardControls(adjust: { adjustFocusedInput(by: $0) })
                } else {
                    EntryKeyboardControls()
                }
            }
        }
        .background(InkPalette.paper)
        .animation(reduceMotion ? nil : CounterweightMotion.quiet, value: session.restEnd != nil)
    }

    private var exerciseOrderSheet: some View {
            NavigationStack {
                List {
                    ForEach(session.drafts) { draft in
                        HStack {
                            DemonstrationImage(assetName: draft.template.assetName).frame(width: 44, height: 44)
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
                .toolbar(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .top, spacing: 0) {
                    HStack {
                        Text("Exercise order").font(.title3.weight(.semibold))
                        Spacer()
                        CounterweightIconButton(symbol: "xmark", label: "Close exercise order") { showingExerciseList = false }
                    }.padding(24).background(InkPalette.paper)
                }
            }
    }

}
