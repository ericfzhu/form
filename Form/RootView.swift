import SwiftData
import SwiftUI

private enum AppTab: Hashable { case today, history }

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var planner = PlannerStore()
    @State private var liveRoute: LiveSessionRoute?
    @State private var selection: AppTab = .today

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                TodayView()
                    .navigationDestination(for: RoutineTemplate.self) { RoutineDetailView(routine: $0) }
                    .navigationDestination(for: ExerciseTemplate.self) { ExerciseProgressView(exercise: $0) }
            }
            .toolbar(.hidden, for: .tabBar)
            .tabItem { Label("Today", systemImage: "sun.max") }.tag(AppTab.today)
            NavigationStack {
                HistoryNavigationView()
                    .navigationDestination(for: ExerciseTemplate.self) { ExerciseProgressView(exercise: $0) }
                    .navigationDestination(for: WorkoutRecord.self) { WorkoutHistoryDetail(workout: $0) }
            }
            .toolbar(.hidden, for: .tabBar)
            .tabItem { Label("History", systemImage: "book.closed") }.tag(AppTab.history)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PaperTabBar(selection: $selection)
        }
        .onOpenURL { url in
            guard let id = LiveWorkoutState.sessionID(from: url),
                  !WorkoutLiveActivityController.isSessionPresented,
                  let snapshot = ActiveWorkoutStore.load(),
                  snapshot.sessionID == id, snapshot.resolvedRoutine != nil else { return }
            selection = .today
            liveRoute = LiveSessionRoute(id: id, snapshot: snapshot)
        }
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

private struct LiveSessionRoute: Identifiable {
    let id: UUID
    let snapshot: ActiveWorkoutSnapshot
}


private struct PaperTabBar: View {
    @Binding var selection: AppTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            InkDivider().padding(.horizontal, 28)
            HStack(spacing: 8) {
                tab(.today, title: "Today")
                tab(.history, title: "History")
            }
            .padding(.horizontal, 28)
            .padding(.top, 8)
            .padding(.bottom, 2)
        }
        .background(InkPalette.paper.ignoresSafeArea(edges: .bottom))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main navigation")
    }

    private func tab(_ tab: AppTab, title: String) -> some View {
        let selected = selection == tab
        return Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { selection = tab }
        } label: {
            VStack(spacing: 3) {
                HStack(spacing: 9) {
                    PaperTabSymbol(isBook: tab == .history)
                        .stroke(style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                        .frame(width: 23, height: 23)
                        .accessibilityHidden(true)
                    Text(title.lowercased()).font(AtelierType.script(24))
                }
                .foregroundStyle(selected ? InkPalette.ink : InkPalette.softInk)
                PaperSelectionMark()
                    .fill(selected ? InkPalette.salvia : .clear)
                    .frame(width: 55, height: 5)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// Small ink drawings and a cut-paper underline keep navigation in the same
// visual language as the illustrations without competing with the page.
private struct PaperSelectionMark: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 1, y: rect.height * 0.25))
            path.addLine(to: CGPoint(x: rect.width - 2, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.8))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.closeSubpath()
        }
    }
}

private struct PaperTabSymbol: Shape {
    var isBook: Bool
    func path(in rect: CGRect) -> Path {
        let scale = CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24)
        var path = Path()
        if isBook {
            path.move(to: CGPoint(x: 12, y: 5))
            path.addLines([CGPoint(x: 3, y: 3), CGPoint(x: 2, y: 19), CGPoint(x: 12, y: 21), CGPoint(x: 22, y: 18), CGPoint(x: 22, y: 3), CGPoint(x: 12, y: 5), CGPoint(x: 12, y: 21)])
            path.move(to: CGPoint(x: 6, y: 8))
            path.addLine(to: CGPoint(x: 9, y: 9))
            path.move(to: CGPoint(x: 6, y: 12))
            path.addLine(to: CGPoint(x: 9, y: 13))
        } else {
            path.move(to: CGPoint(x: 7, y: 12))
            path.addCurve(to: CGPoint(x: 12, y: 6), control1: CGPoint(x: 6, y: 8), control2: CGPoint(x: 9, y: 6))
            path.addCurve(to: CGPoint(x: 18, y: 12), control1: CGPoint(x: 16, y: 5), control2: CGPoint(x: 19, y: 9))
            path.addCurve(to: CGPoint(x: 12, y: 18), control1: CGPoint(x: 18, y: 16), control2: CGPoint(x: 15, y: 19))
            path.addCurve(to: CGPoint(x: 7, y: 12), control1: CGPoint(x: 8, y: 18), control2: CGPoint(x: 6, y: 15))
            for (start, end) in [(CGPoint(x: 12, y: 1), CGPoint(x: 12, y: 3)), (CGPoint(x: 20, y: 4), CGPoint(x: 19, y: 5)), (CGPoint(x: 21, y: 12), CGPoint(x: 23, y: 12)), (CGPoint(x: 19, y: 20), CGPoint(x: 20, y: 22)), (CGPoint(x: 12, y: 21), CGPoint(x: 12, y: 23)), (CGPoint(x: 3, y: 20), CGPoint(x: 5, y: 18)), (CGPoint(x: 1, y: 11), CGPoint(x: 3, y: 11)), (CGPoint(x: 3, y: 3), CGPoint(x: 5, y: 5))] {
                path.move(to: start); path.addLine(to: end)
            }
        }
        return path.applying(scale)
    }
}
