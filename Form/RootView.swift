import SwiftData
import SwiftUI

private enum AppTab: Hashable { case plan, gym, record }

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var planner = PlannerStore()
    @State private var selection: AppTab = .plan

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                PlanHomeView { selection = .gym }
                    .navigationDestination(for: RoutineTemplate.self) { RoutineDetailView(routine: $0) }
                    .navigationDestination(for: ExerciseTemplate.self) { ExerciseProgressView(exercise: $0) }
            }.tabItem { Label("Plan", systemImage: "rectangle.stack") }.tag(AppTab.plan)
            NavigationStack {
                GymProfileView { selection = .plan }
            }.tabItem { Label("My gym", systemImage: "building.2") }.tag(AppTab.gym)
            NavigationStack {
                HistoryNavigationView()
                    .navigationDestination(for: ExerciseTemplate.self) { ExerciseProgressView(exercise: $0) }
                    .navigationDestination(for: WorkoutRecord.self) { WorkoutHistoryDetail(workout: $0) }
            }.tabItem { Label("Record", systemImage: "clock.arrow.circlepath") }.tag(AppTab.record)
        }
        .environmentObject(planner)
        .tint(InkPalette.ink)
        .environment(\.font, .system(.body))
        .task { try? WorkoutDataMigration.backfillLegacyRecords(in: modelContext) }
    }
}

private struct HistoryNavigationView: View {
    @State private var selectedWorkout: WorkoutRecord?
    var body: some View {
        HistoryView { selectedWorkout = $0 }
            .navigationDestination(item: $selectedWorkout) { WorkoutHistoryDetail(workout: $0) }
    }
}
