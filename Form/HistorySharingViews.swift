import SwiftUI

struct ExerciseIndexView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var exercises: [ExerciseTemplate] {
        let all = WorkoutCatalog.routines.flatMap(\.exercises).uniquedByName()
        guard !searchText.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                List(exercises) { exercise in
                    NavigationLink(value: exercise) {
                        HStack(spacing: 14) {
                            DemonstrationImage(assetName: exercise.assetName)
                                .frame(width: 64, height: 64)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(exercise.name)
                                    .font(.system(.headline, design: .serif, weight: .semibold))
                                Text(exercise.targetText)
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(InkPalette.softInk)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    .listRowBackground(InkPalette.raisedPaper)
                }
                .scrollContentBackground(.hidden)
                .searchable(text: $searchText, prompt: "Exercise")
            }
            .navigationTitle("Exercise progress")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ExerciseTemplate.self) {
                ExerciseProgressView(exercise: $0)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
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
                index: "03",
                title: "COACHING REPORT",
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
                    index: "04",
                    title: "WORKOUT BACKUP",
                    detail: "JSON · \(workouts.count) SESSIONS",
                    action: "EXPORT"
                )
            }
            .buttonStyle(PressableButtonStyle())

            InkDivider()

            Button(action: restore) {
                HStack(spacing: 14) {
                    Text("↥")
                        .font(.system(size: 22, weight: .regular, design: .serif))
                        .foregroundStyle(InkPalette.cinnabar)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RESTORE BACKUP")
                            .font(.system(.caption, design: .serif, weight: .semibold))
                            .tracking(1.5)
                        Text("Existing sessions are never duplicated")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(InkPalette.softInk)
                    }
                    Spacer()
                    Text("CHOOSE")
                        .font(.system(.caption, design: .serif, weight: .semibold))
                        .tracking(1.3)
                        .foregroundStyle(InkPalette.cinnabar)
                }
                .padding(.horizontal, 15)
                .frame(minHeight: 64)
            }
            .buttonStyle(PressableButtonStyle())
        }
        .background(InkPalette.raisedPaper)
        .overlay { Rectangle().stroke(InkPalette.bronze.opacity(0.62), lineWidth: 1) }
    }
}

private func recordAction(
    index: String,
    title: String,
    detail: String,
    action: String
) -> some View {
    HStack(spacing: 14) {
        Text(index)
            .font(.system(size: 24, weight: .regular, design: .serif))
            .foregroundStyle(InkPalette.cinnabar)
            .monospacedDigit()
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.caption, design: .serif, weight: .semibold))
                .tracking(1.5)
            Text(detail)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(InkPalette.softInk)
                .monospacedDigit()
        }
        Spacer(minLength: 12)
        Text(action)
            .font(.system(.caption, design: .serif, weight: .semibold))
            .tracking(1.3)
            .foregroundStyle(InkPalette.cinnabar)
    }
    .padding(.horizontal, 15)
    .frame(minHeight: 68)
    .background(InkPalette.raisedPaper)
    .overlay { Rectangle().stroke(InkPalette.bronze.opacity(0.62), lineWidth: 1) }
    .contentShape(Rectangle())
}

