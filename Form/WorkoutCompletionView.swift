import SwiftUI

struct WorkoutCompletionView: View {
    let record: WorkoutRecord
    let done: () -> Void
    var body: some View {
        NavigationStack {
            SavedWorkoutView(workout: record, justSaved: true, done: done)
                .navigationDestination(for: ExerciseTemplate.self) { ExerciseProgressView(exercise: $0) }
        }
    }
}
