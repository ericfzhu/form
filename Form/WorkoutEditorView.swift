import Foundation
import SwiftData
import SwiftUI

struct WorkoutEditorView: View {
    let workout: WorkoutRecord
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var sessionTitle: String
    @State private var date: Date
    @State private var durationMinutes: Double
    @State private var exercises: [EditableExerciseDraft]
    @State private var cardioEntries: [CardioDraft]
    @State private var saveErrorMessage: String?
    @State private var showingDiscardConfirmation = false

    private let initialTitle: String
    private let initialDate: Date
    private let initialDuration: Double
    private let initialExercises: [EditableExerciseDraft]
    private let initialCardio: [CardioDraft]

    init(workout: WorkoutRecord) {
        self.workout = workout
        let title = workout.sessionTitle ?? ""
        let duration = max(1, workout.duration / 60)
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
        initialTitle = title
        initialDate = workout.date
        initialDuration = duration
        initialExercises = exercises
        initialCardio = cardio
        _sessionTitle = State(initialValue: title)
        _date = State(initialValue: workout.date)
        _durationMinutes = State(initialValue: duration)
        _exercises = State(initialValue: exercises)
        _cardioEntries = State(initialValue: cardio)
    }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                LazyVStack(spacing: 18) {
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
        .keyboardDismissToolbar()
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
                    .accessibilityLabel("Session title").inkInput()
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
            VStack(alignment: .leading, spacing: 5) {
                Text("DURATION · MINUTES")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(InkPalette.softInk)
                TextField("60", value: $durationMinutes, format: .number.precision(.fractionLength(0...1)))
                    .accessibilityLabel("Session duration in minutes")
                    .keyboardType(.decimalPad)
                    .inkInput()
            }
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

    private var hasUnsavedChanges: Bool {
        sessionTitle != initialTitle
            || date != initialDate
            || durationMinutes != initialDuration
            || exercises != initialExercises
            || cardioEntries != initialCardio
    }

    private func requestCancel() {
        if hasUnsavedChanges { showingDiscardConfirmation = true }
        else { dismiss() }
    }

    private func save() {
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
                        editField(exercise.template.loadLabel, value: $set.weight,
                                  accessibilityLabel: "\(exercise.template.name), set \(setNumber), weight in kilograms")
                    }
                    VStack(spacing: 4) {
                        Text(exercise.template.recordsTime ? "SEC" : "REPS")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(InkPalette.softInk)
                        TextField("0", value: $set.repetitions, format: .number)
                            .accessibilityLabel("\(exercise.template.name), set \(setNumber), \(exercise.template.recordsTime ? "seconds" : "repetitions")")
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .inkInput()
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

    private func editField(_ label: String, value: Binding<Double>, accessibilityLabel: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(InkPalette.softInk)
            TextField("0", value: value, format: .number.precision(.fractionLength(0...1)))
                .accessibilityLabel(accessibilityLabel)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .inkInput()
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
