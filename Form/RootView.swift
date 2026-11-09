import SwiftData
import SwiftUI

private enum AppTab: Hashable { case today, history }

struct RootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Query private var history: [WorkoutRecord]
    @StateObject private var planner = PlannerStore()
    @State private var recoveryError: String?
    @State private var liveRoute: LiveSessionRoute?
    @State private var selection: AppTab = .today
    @State private var historyPath = NavigationPath()

    var body: some View {
        // Keep both navigation stacks alive without a hidden system tab bar
        // competing with the custom bar for the bottom safe area.
        VStack(spacing: 0) {
            ZStack {
                NavigationStack {
                    TodayView()
                        .navigationDestination(for: WorkoutRecord.self) { WorkoutHistoryDetail(workout: $0) }
                        .navigationDestination(for: RoutineTemplate.self) { RoutineDetailView(routine: $0) }
                        .navigationDestination(for: ExerciseTemplate.self) { ExerciseProgressView(exercise: $0) }
                }
                .opacity(selection == .today ? 1 : 0)
                .allowsHitTesting(selection == .today)
                .accessibilityHidden(selection != .today)
                NavigationStack(path: $historyPath) {
                    HistoryView { historyPath.append($0) }
                        .navigationDestination(for: ExerciseTemplate.self) { ExerciseProgressView(exercise: $0) }
                        .navigationDestination(for: WorkoutRecord.self) { WorkoutHistoryDetail(workout: $0) }
                }
                .opacity(selection == .history ? 1 : 0)
                .allowsHitTesting(selection == .history)
                .accessibilityHidden(selection != .history)
            }
            PaperTabBar(selection: $selection)
        }
        .onOpenURL { url in
            guard let id = LiveWorkoutState.sessionID(from: url),
                  !WorkoutLiveActivityController.isSessionPresented else { return }
            do {
                guard let snapshot = try ActiveWorkoutStore.loadChecked(completedWorkouts: history),
                      snapshot.sessionID == id else { return }
                guard snapshot.resolvedRoutine != nil else { throw ActiveSessionStore.RecoveryError.unreadable }
                selection = .today
                liveRoute = LiveSessionRoute(id: id, snapshot: snapshot)
            } catch { recoveryError = error.localizedDescription; selection = .today }
        }
        .counterweightNotice("Couldn’t restore session", message: $recoveryError)
        .fullScreenCover(item: $liveRoute) { route in
            if let routine = route.snapshot.resolvedRoutine {
                ActiveWorkoutView(routine: routine, snapshot: route.snapshot)
                    .environmentObject(planner)
            }
        }
        .environmentObject(planner)
        .preferredColorScheme(.light)
        .tint(InkPalette.ink)
        .environment(\.font, .system(.body))
        .transaction { if reduceMotion { $0.animation = nil } }
        .task { try? WorkoutDataMigration.backfillLegacyRecords(in: modelContext) }
    }
}

private struct LiveSessionRoute: Identifiable {
    let id: UUID
    let snapshot: ActiveWorkoutSnapshot
}


private struct PaperTabBar: View {
    @Namespace private var tabMark
    @Environment(\.dynamicTypeSize) private var typeSize
    @Binding var selection: AppTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            InkDivider().padding(.horizontal, CounterweightLayout.pageInset)
            HStack(spacing: 8) {
                tab(.today, title: "Today")
                tab(.history, title: "History")
            }
            .padding(.horizontal, CounterweightLayout.pageInset)
            .padding(.top, 8)
            .padding(.bottom, 2)
        }
        .background(InkPalette.paper.ignoresSafeArea(edges: .bottom))
    }

    private func tab(_ tab: AppTab, title: String) -> some View {
        let selected = selection == tab
        return Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { selection = tab }
        } label: {
            VStack(spacing: 3) {
                Text(title).font(.subheadline.weight(selected ? .semibold : .regular))
                    .foregroundStyle(selected ? InkPalette.ink : InkPalette.softInk)
                ZStack {
                    if selected { Circle().fill(InkPalette.ink).matchedGeometryEffect(id: "tab", in: tabMark) }
                }.frame(width: 4, height: 4).accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
