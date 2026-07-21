import SwiftUI
import SwiftData

@main
struct FormApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.light)
                .task {
                    if ActiveWorkoutStore.load() == nil {
                        await WorkoutLiveActivityController.end()
                    }
                }
        }
        .modelContainer(for: [WorkoutRecord.self, ExerciseRecord.self, SetRecord.self, CardioRecord.self])
    }
}
