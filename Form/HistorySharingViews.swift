import SwiftUI

struct ExerciseIndexView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var exercises: [ExerciseTemplate] {
        let all = WorkoutCatalog.allExercises.uniquedByName()
        guard !searchText.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                VStack(spacing: 0) {
                    HStack {
                        Text("exercise progress")
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Button("done") { dismiss() }
                            .font(.system(.subheadline, design: .monospaced))
                            .frame(minWidth: 52, minHeight: 44, alignment: .trailing)
                    }
                    .padding(.horizontal, 20)

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundStyle(InkPalette.softInk)
                        TextField("exercise", text: $searchText)
                            .font(.system(.body, design: .monospaced))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .frame(minHeight: 52)
                    .padding(.horizontal, 20)

                    List(exercises) { exercise in
                        NavigationLink(value: exercise) {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(exercise.name)
                                        .font(.system(.body, design: .monospaced))
                                    Text(exercise.targetText)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(InkPalette.softInk.opacity(0.8))
                                }
                                Spacer()
                                DemonstrationImage(assetName: exercise.assetName, outlined: false)
                                    .frame(width: 72, height: 64)
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ExerciseTemplate.self) {
                ExerciseProgressView(exercise: $0)
            }
        }
        .tint(InkPalette.cinnabar)
    }
}

struct CoachingReportShareRow: View {
    let workouts: [WorkoutRecord]

    var body: some View {
        ShareLink(
            item: CoachingReportBuilder.build(from: workouts),
            preview: SharePreview("Form coaching report")
        ) {
            recordAction(
                title: "Coaching report",
                detail: "12 WEEKS · \(includedSessionCount) SESSIONS",
                action: "SHARE"
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var includedSessionCount: Int {
        workouts.filter { ProgressPeriod.twelveWeeks.includes($0.date) }.count
    }
}

struct BackupManagementView: View {
    let workouts: [WorkoutRecord]
    let restore: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ShareLink(
                item: WorkoutBackup(workouts: workouts),
                preview: SharePreview("Form workout backup")
            ) {
                recordAction(
                    title: "Workout backup",
                    detail: "JSON · \(workouts.count) SESSIONS",
                    action: "EXPORT"
                )
            }
            .buttonStyle(PressableButtonStyle())

            Button(action: restore) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Restore backup")
                            .font(AtelierType.script(20))
                        Text("Existing sessions are never duplicated")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(InkPalette.softInk)
                    }
                    Spacer()
                    Text("CHOOSE")
                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                        .foregroundStyle(InkPalette.cinnabar)
                }
                .padding(.horizontal, 15)
                .frame(minHeight: 72)
            }
            .buttonStyle(PressableButtonStyle())
        }
    }
}

private func recordAction(
    title: String,
    detail: String,
    action: String
) -> some View {
    HStack(spacing: 14) {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AtelierType.script(20))
            Text(detail)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(InkPalette.softInk)
                .monospacedDigit()
        }
        Spacer(minLength: 12)
        Text(action)
            .font(.system(.caption, design: .monospaced, weight: .semibold))
            .foregroundStyle(InkPalette.cinnabar)
    }
    .padding(.horizontal, 15)
    .frame(minHeight: 72)
    .contentShape(Rectangle())
}
