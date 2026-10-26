import Foundation
import SwiftData
import SwiftUI
import UIKit

struct WorkoutEditorView: View {
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
                .padding(.horizontal, 20)
                .padding(.top, 14)
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
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
            if let id = entryForm.focusedID {
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in isKeyboardVisible = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in isKeyboardVisible = false }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isKeyboardVisible { EntryKeyboardControls() }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            InkTextHeader(
                title: "edit session",
                leadingTitle: "Cancel",
                leadingAction: requestCancel,
                trailingTitle: "Save",
                trailingAction: save
            )
        }
        .interactiveDismissDisabled()
        .confirmationDialog("Discard unsaved changes?", isPresented: $showingDiscardConfirmation) {
            Button("Discard changes", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
        .alert("Couldn’t save changes", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? "")
        }
        }
        .environment(entryForm)
    }

    private var sessionDetails: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("session")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(InkPalette.softInk)
            VStack(alignment: .leading, spacing: 5) {
                Text("OPTIONAL TITLE")
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
                    .font(.system(.body, design: .monospaced))
                    .tint(InkPalette.cinnabar)
            }
            NumberEntryField(id: EntryID.duration, label: "Session duration in minutes", value: $durationMinutes, caption: "DURATION · MINUTES")
        }
        .padding(.vertical, 12)
        .inkCard()
    }

    private var addExerciseMenu: some View {
        Menu {
            ForEach(availableExercises) { template in
                Button(template.name) {
                    exercises.append(EditableExerciseDraft(
                        record: nil,
                        template: template,
                        sets: (0..<template.sets).map { _ in
                            EditableSetDraft(weight: 0, repetitions: template.minimumRepetitions)
                        }
                    ))
                }
            }
        } label: {
            Text("Add exercise")
                .font(AtelierType.script(17))
                .frame(maxWidth: .infinity, minHeight: 48)
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
                    .font(.system(.body, design: .monospaced))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Remove", role: .destructive, action: remove)
                    .accessibilityLabel("Remove \(exercise.template.name)")
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .foregroundStyle(InkPalette.cinnabar)
                    .frame(minHeight: 44)
            }
            .padding(.vertical, 11)
            ForEach($exercise.sets) { $set in
                let setNumber = (exercise.sets.firstIndex { $0.id == set.id } ?? 0) + 1
                layout {
                    Picker("Set type", selection: $set.kind) {
                        ForEach(SetKind.allCases) { Text($0.shortTitle).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("\(exercise.template.name), set \(setNumber), type")
                    .accessibilityValue(set.kind.title)
                    .frame(minWidth: 44)
                    if exercise.template.recordsLoad {
                        editField(exercise.template.loadLabel, id: EntryID.load(set.id), value: $set.weight,
                                  accessibilityLabel: "\(exercise.template.name), set \(setNumber), weight in kilograms")
                    }
                    VStack(spacing: 4) {
                        Text(exercise.template.recordsTime ? "SEC" : "REPS")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(InkPalette.softInk)
                        NumberEntryField(id: EntryID.count(set.id), label: "\(exercise.template.name), set \(setNumber), \(exercise.template.recordsTime ? "seconds" : "repetitions")", value: Binding(get: { Double(set.repetitions) }, set: { set.repetitions = Int($0) }), whole: true, alignment: .center)
                    }
                    .frame(maxWidth: .infinity)
                    Button {
                        exercise.sets.removeAll { $0.id == set.id }
                    } label: {
                        Image(systemName: "minus")
                            .foregroundStyle(InkPalette.cinnabar)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Remove \(exercise.template.name), set \(setNumber)")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
            }

            Button {
                let last = exercise.sets.last
                exercise.sets.append(EditableSetDraft(
                    weight: last?.weight ?? 0,
                    repetitions: last?.repetitions ?? exercise.template.minimumRepetitions
                ))
            } label: {
                Text("Add set")
                    .font(AtelierType.script(17))
                    .frame(maxWidth: .infinity, minHeight: 46)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Add set to \(exercise.template.name)")
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
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
