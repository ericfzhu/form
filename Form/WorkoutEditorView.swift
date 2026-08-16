import Foundation
import SwiftData
import SwiftUI

private struct EditableSetDraft: Identifiable, Equatable {
    let id = UUID()
    var weight: Double
    var repetitions: Int
    var kind: SetKind = .working
}

private struct EditableExerciseDraft: Identifiable, Equatable {
    let id = UUID()
    let record: ExerciseRecord?
    let template: ExerciseTemplate
    var sets: [EditableSetDraft]

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
            && lhs.record?.persistentModelID == rhs.record?.persistentModelID
            && lhs.template == rhs.template
            && lhs.sets == rhs.sets
    }
}

struct WorkoutEditorView: View {
    let workout: WorkoutRecord
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
                title: "EDIT SESSION",
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
            Text("SESSION")
                .font(.caption2.weight(.semibold))
                .tracking(1.8)
                .foregroundStyle(InkPalette.softInk)
            VStack(alignment: .leading, spacing: 5) {
                Text("OPTIONAL TITLE")
                    .font(.caption2.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(InkPalette.softInk)
                TextField(workout.routineName, text: $sessionTitle).inkInput()
            }
            DatePicker("Date and time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .font(.system(.body, design: .serif))
                .tint(InkPalette.cinnabar)
            VStack(alignment: .leading, spacing: 5) {
                Text("DURATION · MINUTES")
                    .font(.caption2.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(InkPalette.softInk)
                TextField("60", value: $durationMinutes, format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .inkInput()
            }
        }
        .padding(16)
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
                .font(.system(.subheadline, design: .serif, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(InkPalette.raisedPaper)
                .overlay { Rectangle().stroke(InkPalette.bronze.opacity(0.62), lineWidth: 1) }
        }
    }

    private var availableExercises: [ExerciseTemplate] {
        WorkoutCatalog.routines.flatMap(\.exercises).uniquedByName().filter { template in
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
        let trimmed = sessionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        workout.sessionTitle = trimmed.isEmpty ? nil : trimmed
        workout.date = date
        workout.duration = max(60, durationMinutes * 60)

        let retained = Set(exercises.compactMap { $0.record?.persistentModelID })
        for existing in workout.exercises where !retained.contains(existing.persistentModelID) {
            modelContext.delete(existing)
        }

        workout.exercises = exercises.enumerated().compactMap { exerciseIndex, draft in
            if draft.record == nil && draft.sets.isEmpty { return nil }
            let record = draft.record ?? ExerciseRecord(
                exerciseID: draft.template.id,
                name: draft.template.name,
                assetName: draft.template.assetName,
                order: exerciseIndex
            )
            record.exerciseID = draft.template.id
            record.name = draft.template.name
            record.assetName = draft.template.assetName
            record.order = exerciseIndex
            let oldSets = record.sets
            record.sets = []
            oldSets.forEach(modelContext.delete)
            record.sets = draft.sets.enumerated().map { index, set in
                SetRecord(
                    order: index,
                    weight: draft.template.recordsLoad ? max(0, set.weight) : 0,
                    repetitions: max(0, set.repetitions),
                    kind: set.kind
                )
            }
            return record
        }

        let oldCardio = workout.cardioEntries
        workout.cardioEntries = []
        oldCardio.forEach(modelContext.delete)
        workout.cardioEntries = cardioEntries.enumerated().compactMap { index, entry in
            guard entry.durationMinutes > 0 else { return nil }
            return CardioRecord(
                kind: entry.kind,
                order: index,
                durationMinutes: max(0, entry.durationMinutes),
                distanceKilometers: max(0, entry.distanceKilometers),
                averageSpeed: max(0, entry.averageSpeed),
                incline: entry.kind.supportsIncline ? max(0, entry.incline) : 0
            )
        }
        workout.healthSyncStatus = workout.hasTrainingData ? .pending : .notRequested
        workout.healthSyncLastError = nil

        do {
            try modelContext.save()
            Task {
                await HealthSyncCoordinator.shared.enqueueSave(
                    workout,
                    replacing: previousUUID,
                    in: modelContext
                )
            }
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Your edits are still on this screen. Try saving again."
        }
    }
}

private struct EditableExerciseCard: View {
    @Binding var exercise: EditableExerciseDraft
    let remove: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                DemonstrationImage(assetName: exercise.template.assetName)
                    .frame(width: 72, height: 72)
                Text(exercise.template.name)
                    .font(.system(.headline, design: .serif, weight: .semibold))
                Spacer()
                Button("Remove", role: .destructive, action: remove)
                    .font(.system(.caption, design: .serif, weight: .semibold))
                    .foregroundStyle(InkPalette.cinnabar)
                    .frame(minHeight: 44)
            }
            .padding(11)
            InkDivider().padding(.horizontal, 14).padding(.vertical, 4)

            ForEach($exercise.sets) { $set in
                HStack(spacing: 10) {
                    Picker("Set type", selection: $set.kind) {
                        ForEach(SetKind.allCases) { Text($0.shortTitle).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 44)
                    if exercise.template.recordsLoad {
                        editField(exercise.template.loadLabel, value: $set.weight)
                    }
                    VStack(spacing: 4) {
                        Text(exercise.template.recordsTime ? "SEC" : "REPS")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(InkPalette.softInk)
                        TextField("0", value: $set.repetitions, format: .number)
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
                            .frame(width: 42, height: 42)
                    }
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
                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 46)
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .inkCard()
    }

    private func editField(_ label: String, value: Binding<Double>) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(InkPalette.softInk)
            TextField("0", value: value, format: .number.precision(.fractionLength(0...1)))
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
