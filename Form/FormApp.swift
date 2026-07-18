import SwiftUI
import SwiftData

@main
struct FormApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.light)
        }
        .modelContainer(for: [WorkoutRecord.self, ExerciseRecord.self, SetRecord.self, CardioRecord.self])
    }
}
