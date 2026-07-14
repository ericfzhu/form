import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var workouts: [WorkoutRecord]

    var body: some View {
        ZStack {
            PaperBackground()

            if workouts.isEmpty {
                EmptyHistoryView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        historyHeader

                        ForEach(workouts) { workout in
                            NavigationLink {
                                WorkoutHistoryDetail(workout: workout)
                            } label: {
                                HistoryCard(workout: workout)
                            }
                            .buttonStyle(PressableButtonStyle())
                            .contextMenu {
                                Button("Delete workout", role: .destructive) {
                                    modelContext.delete(workout)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                    .padding(.bottom, 30)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var historyHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PRACTICE LOG")
                .font(.caption.weight(.semibold))
                .tracking(3)
                .foregroundStyle(InkPalette.softInk)
            Text("The work, recorded.")
                .font(.system(size: 36, weight: .semibold, design: .serif))
                .foregroundStyle(InkPalette.ink)
            InkDivider().padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 12)
    }
}

private struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image("plank")
                .resizable()
                .scaledToFit()
                .blendMode(.multiply)
                .frame(width: 230, height: 180)
                .mask(
                    LinearGradient(
                        colors: [.clear, .black, .black, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text("No marks yet.")
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundStyle(InkPalette.ink)
            InkDivider()
                .frame(width: 120)
            Text("Complete your first session and its weights, repetitions, and duration will gather here.")
                .font(.system(.body, design: .serif))
                .foregroundStyle(InkPalette.softInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 42)
        }
        .padding(.bottom, 54)
    }
}

private struct HistoryCard: View {
    let workout: WorkoutRecord

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text(workout.date.formatted(.dateTime.day()))
                    .font(.system(size: 31, weight: .medium, design: .serif))
                    .foregroundStyle(InkPalette.ink)
                Text(workout.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(1.4)
                    .foregroundStyle(InkPalette.softInk)
            }
            .frame(width: 62)

            Capsule()
                .fill(InkPalette.ink.opacity(0.18))
                .frame(width: 1, height: 58)

            VStack(alignment: .leading, spacing: 6) {
                Text(workout.routineName)
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(InkPalette.ink)
                Text("\(durationText(workout.duration)) · \(completedMovementCount) movements")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(InkPalette.softInk)
            }

            Spacer()

            Image(systemName: "arrow.up.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(InkPalette.softInk)
                .frame(width: 40, height: 40)
        }
        .padding(16)
        .inkCard()
    }

    private func durationText(_ duration: TimeInterval) -> String {
        "\(max(1, Int(duration / 60))) min"
    }

    private var completedMovementCount: Int {
        workout.exercises.filter { !$0.sets.isEmpty }.count
    }
}

private struct WorkoutHistoryDetail: View {
    let workout: WorkoutRecord

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                LazyVStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(workout.date.formatted(date: .long, time: .omitted).uppercased())
                            .font(.caption.weight(.semibold))
                            .tracking(1.8)
                            .foregroundStyle(InkPalette.softInk)
                        Text("A record of the session.")
                            .font(.system(size: 28, weight: .semibold, design: .serif))
                            .foregroundStyle(InkPalette.ink)
                        InkDivider().padding(.top, 3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 6)

                    ForEach(workout.exercises.sorted { $0.order < $1.order }) { exercise in
                        HistoryExerciseCard(exercise: exercise)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle(workout.routineName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(InkPalette.paper.opacity(0.95), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

private struct HistoryExerciseCard: View {
    let exercise: ExerciseRecord

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                DemonstrationImage(assetName: exercise.assetName)
                    .frame(width: 86, height: 86)
                Text(exercise.name)
                    .font(.system(.headline, design: .serif, weight: .semibold))
                    .foregroundStyle(InkPalette.ink)
                Spacer()
            }
            .padding(11)

            if exercise.sets.isEmpty {
                Text("No completed sets")
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(InkPalette.softInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding([.horizontal, .bottom], 16)
            } else {
                InkDivider()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 3)

                ForEach(exercise.sets.sorted { $0.order < $1.order }) { set in
                    HStack {
                        Text("Set \(set.order + 1)")
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(InkPalette.softInk)
                        Spacer()
                        Text(setText(set))
                            .font(.body.monospacedDigit().weight(.semibold))
                            .foregroundStyle(InkPalette.ink)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 46)
                }
            }
        }
        .inkCard()
    }

    private func setText(_ set: SetRecord) -> String {
        if set.weight > 0 {
            return "\(set.weight.formatted(.number.precision(.fractionLength(0...1)))) kg × \(set.repetitions)"
        }
        return "\(set.repetitions) reps"
    }
}
