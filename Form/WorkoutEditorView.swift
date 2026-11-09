import Foundation
import SwiftData
import SwiftUI
import UIKit

struct WorkoutEditorView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let workout: WorkoutRecord
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var entryForm = NumberEntryForm()
    @State private var isKeyboardVisible = false
    @State private var sessionTitle: String
    @State private var date: Date
    @State private var durationMinutes: Double
    @State private var exercises: [EditableExerciseDraft]
    @State private var cardioEntries: [CardioDraft]
    @State private var saveErrorMessage: String?
    @State private var showingDiscardConfirmation = false
    @State private var discardAfterSheet = false
    @State private var showingExercisePicker = false

    // Keep the baseline alongside the drafts: SwiftUI can recreate this view
    // while retaining its State, and new draft UUIDs would look like edits.
    @State private var initialTitle: String
    @State private var initialDate: Date
    @State private var initialDuration: Double
    @State private var initialExercises: [EditableExerciseDraft]
    @State private var initialCardio: [CardioDraft]

    init(workout: WorkoutRecord) {
        self.workout = workout
        let title = workout.sessionTitle ?? ""
        let duration = workout.duration / 60
        let exercises = workout.exercises.sorted { $0.order < $1.order }.map { exercise in
            EditableExerciseDraft(
                record: exercise,
                template: WorkoutCatalog.exercise(for: exercise) ?? ExerciseTemplate(
                    id: exercise.assetName,
                    name: exercise.name,
                    assetName: exercise.assetName,
                    sets: max(1, exercise.sets.count),
                    minimumRepetitions: 1,
                    maximumRepetitions: 20,
                    measurement: exercise.sets.contains { $0.weight > 0 } ? .weighted : .bodyweight,
                    restSeconds: 90
                ),
                sets: exercise.sets.sorted { $0.order < $1.order }.map {
                    EditableSetDraft(weight: $0.weight, repetitions: $0.repetitions, kind: $0.kind)
                }
            )
        }
        let cardio = workout.cardioEntries.sorted { $0.order < $1.order }.map(CardioDraft.init)
        _initialTitle = State(initialValue: title)
        _initialDate = State(initialValue: workout.date)
        _initialDuration = State(initialValue: duration)
        _initialExercises = State(initialValue: exercises)
        _initialCardio = State(initialValue: cardio)
        _sessionTitle = State(initialValue: title)
        _date = State(initialValue: workout.date)
        _durationMinutes = State(initialValue: duration)
        _exercises = State(initialValue: exercises)
        _cardioEntries = State(initialValue: cardio)
    }

    var body: some View {
        ScrollViewReader { proxy in
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(spacing: 18) {
                    sessionDetails
                    ForEach($exercises) { $exercise in
                        EditableExerciseCard(
                            exercise: $exercise,
                            remove: { exercises.removeAll { $0.id == exercise.id } }
                        )
                    }
                    addExerciseMenu
                    CardioLoggingSection(entries: $cardioEntries)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 36)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: numberFields, initial: true) { _, fields in
            entryForm.configure(fields, order: [EntryID.title] + fields.map(\.id))
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
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in isKeyboardVisible = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in isKeyboardVisible = false }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isKeyboardVisible { EntryKeyboardControls() }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            InkTextHeader(
                title: "Edit session",
                leadingTitle: "Cancel",
                leadingAction: requestCancel,
                trailingTitle: "Save",
                trailingAction: save
            )
        }
        .interactiveDismissDisabled()
        .sheet(isPresented: $showingDiscardConfirmation, onDismiss: {
            if discardAfterSheet { discardAfterSheet = false; dismiss() }
        }) {
            CounterweightConfirmationSheet(
                title: "Discard changes?", message: "Your saved session will stay as it was before editing.",
                actionTitle: "Discard changes", destructive: true, cancelTitle: "Keep editing",
                confirm: { discardAfterSheet = true; showingDiscardConfirmation = false },
                cancel: { showingDiscardConfirmation = false }
            )
        }
        .counterweightNotice("Couldn’t save changes", message: $saveErrorMessage)
        }
        .environment(entryForm)
    }

    private var sessionDetails: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Title · optional")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(InkPalette.softInk)
                TextField(workout.routineName, text: $sessionTitle)
                    .accessibilityLabel("Session title, optional").inkInput()
                    .textInputAutocapitalization(.sentences)
                    .entryFocus(EntryID.title).id(EntryID.title)
            }
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Date").font(.caption)
                    DatePicker("Session date", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                    Text("Time").font(.caption)
                    DatePicker("Session time", selection: $date, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
            } else {
                DatePicker("Date and time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .font(.body)
                    .tint(InkPalette.cinnabar)
            }
            NumberEntryField(id: EntryID.duration, label: "Session duration in minutes", value: $durationMinutes, caption: "Duration · minutes")
        }
        .padding(.vertical, 12)
        .inkCard()
    }

    private var addExerciseMenu: some View {
        CounterweightControl(title: "Exercise", symbol: "plus") {
            entryForm.done()
            dismissKeyboard()
            showingExercisePicker = true
        }
        .accessibilityLabel("Add exercise")
        .disabled(availableExercises.isEmpty)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showingExercisePicker) {
            CounterweightSheet(title: "Add exercise") {
                ForEach(availableExercises) { template in
                    Button {
                        exercises.append(EditableExerciseDraft(
                            record: nil, template: template,
                            sets: (0..<template.sets).map { _ in
                                EditableSetDraft(weight: 0, repetitions: template.minimumRepetitions)
                            }
                        ))
                        showingExercisePicker = false
                    } label: {
                        HStack(spacing: 16) {
                            DemonstrationImage(assetName: template.assetName).frame(width: 56, height: 56)
                            Text(template.name).font(.subheadline.weight(.medium)).multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Image(systemName: "plus").font(.subheadline)
                        }.contentShape(Rectangle())
                    }.buttonStyle(PressableButtonStyle())
                    InkDivider()
                }
            }
        }
    }

    private var availableExercises: [ExerciseTemplate] {
        WorkoutCatalog.allExercises.uniquedByName().filter { template in
            !exercises.contains { $0.template.id == template.id }
        }
    }

    private var numberFields: [NumberFieldSpec] {
        [NumberFieldSpec(id: EntryID.duration, label: "Session duration in minutes", value: durationMinutes, rule: .duration)]
            + exercises.flatMap { exercise in
                exercise.sets.flatMap { set -> [NumberFieldSpec] in
                    var fields: [NumberFieldSpec] = []
                    if exercise.template.recordsLoad {
                        fields.append(NumberFieldSpec(id: EntryID.load(set.id), label: "\(exercise.template.name), weight", value: set.weight, rule: .load))
                    }
                    fields.append(NumberFieldSpec(id: EntryID.count(set.id), label: "\(exercise.template.name), \(exercise.template.recordsTime ? "seconds" : "repetitions")", value: Double(set.repetitions), rule: .count))
                    return fields
                }
            } + cardioEntries.flatMap(\.numberFields)
    }

    private var hasUnsavedChanges: Bool {
        entryForm.hasInvalidEdits || sessionTitle != initialTitle
            || date != initialDate
            || durationMinutes != initialDuration
            || exercises != initialExercises
            || cardioEntries != initialCardio
    }

    private func requestCancel() {
        entryForm.done()
        dismissKeyboard()
        if hasUnsavedChanges { showingDiscardConfirmation = true }
        else { dismiss() }
    }

    private func save() {
        guard entryForm.validate() else { return }
        entryForm.done()
        dismissKeyboard()
        let previousUUID = workout.healthKitWorkoutUUID
        do {
            try WorkoutRepository.update(
                workout, title: sessionTitle, date: date, durationMinutes: durationMinutes,
                exercises: exercises, cardioEntries: cardioEntries, in: modelContext
            )
            Task {
                await HealthSyncCoordinator.shared.enqueueSave(
                    workout,
                    replacing: previousUUID,
                    in: modelContext
                )
            }
            dismiss()
        } catch {
            saveErrorMessage = "Your edits are still on this screen. Try saving again."
        }
    }
}

private struct EditableExerciseCard: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @Binding var exercise: EditableExerciseDraft
    let remove: () -> Void

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
        VStack(spacing: 0) {
            layout {
                DemonstrationImage(assetName: exercise.template.assetName)
                    .frame(width: 72, height: 72)
                Text(exercise.template.name)
                    .font(.body)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                CounterweightIconButton(symbol: "minus", label: "Remove \(exercise.template.name)", action: remove)
            }
            .padding(.vertical, 11)
            ForEach($exercise.sets) { $set in
                let setNumber = (exercise.sets.firstIndex { $0.id == set.id } ?? 0) + 1
                VStack(spacing: 12) {
                    layout {
                        Text("Set \(setNumber)").font(.caption).foregroundStyle(InkPalette.softInk)
                        Spacer(minLength: 0)
                        EditorSetKindControl(kind: $set.kind, label: "\(exercise.template.name), set \(setNumber)")
                        CounterweightIconButton(symbol: "minus", label: "Remove \(exercise.template.name), set \(setNumber)") {
                            exercise.sets.removeAll { $0.id == set.id }
                        }
                    }
                    layout {
                        if exercise.template.recordsLoad {
                            editField(exercise.template.loadLabel, id: EntryID.load(set.id), value: $set.weight,
                                      accessibilityLabel: "\(exercise.template.name), set \(setNumber), weight in kilograms")
                        }
                        VStack(spacing: 4) {
                            Text(exercise.template.recordsTime ? "SEC" : "REPS")
                                .font(.caption2.weight(.semibold)).foregroundStyle(InkPalette.softInk)
                            NumberEntryField(id: EntryID.count(set.id), label: "\(exercise.template.name), set \(setNumber), \(exercise.template.recordsTime ? "seconds" : "repetitions")", value: Binding(get: { Double(set.repetitions) }, set: { set.repetitions = Int($0) }), whole: true, alignment: .center)
                        }.frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 12)
            }

            CounterweightControl(title: "Set", symbol: "plus") {
                let last = exercise.sets.last
                exercise.sets.append(EditableSetDraft(
                    weight: last?.weight ?? 0,
                    repetitions: last?.repetitions ?? exercise.template.minimumRepetitions
                ))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Add set to \(exercise.template.name)")
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            InkDivider()
        }
        .inkCard()
    }

    private func editField(_ label: String, id: String, value: Binding<Double>, accessibilityLabel: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(InkPalette.softInk)
            NumberEntryField(id: id, label: accessibilityLabel, value: value, alignment: .center)
        }
        .frame(maxWidth: .infinity)
    }
}

extension Array where Element == ExerciseTemplate {
    func uniquedByName() -> [ExerciseTemplate] {
        var seen = Set<String>()
        return filter { seen.insert($0.name).inserted }
    }
}

private struct EditorSetKindControl: View {
    @Binding var kind: SetKind
    let label: String
    @State private var showingKinds = false

    var body: some View {
        CounterweightControl(title: kind.title, symbol: "chevron.down") {
            dismissKeyboard()
            showingKinds = true
        }
        .accessibilityLabel("\(label), type")
        .accessibilityValue(kind.title)
        .sheet(isPresented: $showingKinds) {
            CounterweightSheet(title: "Set type", subtitle: label) {
                ForEach(SetKind.allCases) { option in
                    CounterweightChoice(title: option.title, selected: kind == option) {
                        kind = option
                        showingKinds = false
                    }
                }
            }
        }
    }
}
