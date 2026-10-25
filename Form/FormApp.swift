import SwiftData
import SwiftUI

@main
struct FormApp: App {
    private let modelContainer: ModelContainer

    init() {
        modelContainer = AppModelContainer.make()
    }

    var body: some Scene {
        WindowGroup {
            AppBootstrapView()
                .preferredColorScheme(.light)
        }
        .modelContainer(modelContainer)
    }
}

private struct AppBootstrapView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var workouts: [WorkoutRecord]
    @StateObject private var health = HealthKitService.shared
    @StateObject private var healthSync = HealthSyncCoordinator.shared

    var body: some View {
        RootView()
            .task {
                try? WorkoutDataMigration.backfillLegacyRecords(in: modelContext)
                await health.refresh()
                await healthSync.retryPending(
                    in: modelContext,
                    workouts: workouts
                )
                if ActiveWorkoutStore.load() == nil {
                    await WorkoutLiveActivityController.forceEnd()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task {
                    await health.refresh()
                    await healthSync.processPending(in: modelContext)
                }
            }
            .onChange(of: health.accessState) { _, state in
                guard state == .connected else { return }
                Task {
                    await healthSync.retryPending(
                        in: modelContext,
                        workouts: workouts
                    )
                }
            }
    }
}
