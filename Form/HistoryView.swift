import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var workouts: [WorkoutRecord]

    var body: some View {
        Group {
            if workouts.isEmpty {
                ContentUnavailableView(
                    "No workouts yet",
                    systemImage: "figure.strengthtraining.traditional",
                    description: Text("Completed sessions will appear here with every weight and repetition.")
                )
            } else {
                List {
                    ForEach(workouts) { workout in
                        NavigationLink {
                            WorkoutHistoryDetail(workout: workout)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(workout.routineName)
                                    .font(.headline)
                                HStack(spacing: 8) {
                                    Text(workout.date.formatted(date: .abbreviated, time: .omitted))
                                    Text("·")
                                    Text(durationText(workout.duration))
                                }
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 7)
                        }
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("History")
    }

    @Environment(\.modelContext) private var modelContext

    private func delete(at offsets: IndexSet) {
        for offset in offsets {
            modelContext.delete(workouts[offset])
        }
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let minutes = max(1, Int(duration / 60))
        return "\(minutes) min"
    }
}

private struct WorkoutHistoryDetail: View {
    let workout: WorkoutRecord

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(workout.exercises.sorted { $0.order < $1.order }) { exercise in
                    VStack(spacing: 0) {
                        HStack(spacing: 14) {
                            DemonstrationImage(assetName: exercise.assetName)
                                .frame(width: 72, height: 72)
                            Text(exercise.name)
                                .font(.headline)
                            Spacer()
                        }
                        .padding(10)

                        if exercise.sets.isEmpty {
                            Text("No completed sets")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding([.horizontal, .bottom], 14)
                        } else {
                            Divider().padding(.horizontal, 12)
                            ForEach(exercise.sets.sorted { $0.order < $1.order }) { set in
                                HStack {
                                    Text("Set \(set.order + 1)")
                                    Spacer()
                                    Text(setText(set))
                                        .font(.body.monospacedDigit().weight(.semibold))
                                }
                                .padding(.horizontal, 14)
                                .frame(height: 44)
                            }
                        }
                    }
                    .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(0.045), radius: 9, y: 3)
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(workout.routineName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func setText(_ set: SetRecord) -> String {
        if set.weight > 0 {
            return "\(set.weight.formatted(.number.precision(.fractionLength(0...1)))) kg × \(set.repetitions)"
        }
        return "\(set.repetitions) reps"
    }
}
