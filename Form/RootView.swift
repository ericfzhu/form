import SwiftData
import SwiftUI

private enum AppTab: CaseIterable, Hashable {
    case train
    case history

    var title: String { self == .train ? "Train" : "Record" }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("did-see-training-introduction") private var didSeeIntroduction = false
    @State private var selection: AppTab = .train
    @State private var trainPath = NavigationPath()
    @State private var historyPath = NavigationPath()
    @State private var showingIntroduction = false

    private var isFooterVisible: Bool {
        selection == .train ? trainPath.isEmpty : historyPath.isEmpty
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PaperBackground()
                VStack(spacing: 0) {
                    ZStack {
                        NavigationStack(path: $trainPath) {
                            RoutineListView()
                                .navigationDestination(for: RoutineTemplate.self) {
                                    RoutineDetailView(routine: $0)
                                }
                                .navigationDestination(for: ExerciseTemplate.self) {
                                    ExerciseProgressView(exercise: $0)
                                }
                        }
                        .opacity(selection == .train ? 1 : 0)
                        .allowsHitTesting(selection == .train)
                        .accessibilityHidden(selection != .train)
                        .zIndex(selection == .train ? 1 : 0)

                        NavigationStack(path: $historyPath) {
                            HistoryView { historyPath.append($0) }
                                .navigationDestination(for: ExerciseTemplate.self) {
                                    ExerciseProgressView(exercise: $0)
                                }
                                .navigationDestination(for: WorkoutRecord.self) {
                                    WorkoutHistoryDetail(workout: $0)
                                }
                        }
                        .opacity(selection == .history ? 1 : 0)
                        .allowsHitTesting(selection == .history)
                        .accessibilityHidden(selection != .history)
                        .zIndex(selection == .history ? 1 : 0)
                    }

                    if isFooterVisible {
                        InkTabBar(selection: $selection)
                            .background {
                                InkPalette.paper.ignoresSafeArea(edges: .bottom)
                            }
                    }
                }

                PaperSurface()
                    .frame(height: proxy.safeAreaInsets.top)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
            }
            .tint(InkPalette.ink)
            .transaction { transaction in
                if reduceMotion { transaction.animation = nil }
            }
        }
        .task {
            try? WorkoutDataMigration.backfillLegacyRecords(in: modelContext)
            if !didSeeIntroduction { showingIntroduction = true }
        }
        .sheet(isPresented: $showingIntroduction, onDismiss: {
            didSeeIntroduction = true
        }) {
            TrainingIntroductionView {
                didSeeIntroduction = true
                showingIntroduction = false
            }
        }
    }
}

private struct TrainingIntroductionView: View {
    let done: () -> Void

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(alignment: .leading, spacing: 0) {
                RawScreenTitle(index: "00", title: "Begin")
                VStack(spacing: 0) {
                    row("I", "Follow the rotation", "Form keeps your place across Workouts A, B and C.")
                    row("II", "Record each completed set", "Your last load and repetitions return when the movement comes again.")
                    row("III", "Leave and return safely", "Close a session whenever needed. Your work, timer and Live Activity remain preserved.")
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                Spacer(minLength: 24)
                InkPrimaryButton(title: "Continue", action: done).padding(20)
            }
        }
        .presentationDetents([.large])
    }

    private func row(_ index: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(index)
                .font(.system(.title3, design: .serif))
                .foregroundStyle(InkPalette.cinnabar)
                .frame(width: 30, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(.headline, design: .serif, weight: .semibold))
                Text(detail)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(InkPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 18)
        .overlay(alignment: .bottom) { InkDivider() }
    }
}

private struct InkTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeOut(duration: 0.24)) { selection = tab }
                } label: {
                    HStack(spacing: 9) {
                        Text(tab == .train ? "I" : "II")
                            .foregroundStyle(selection == tab ? InkPalette.cinnabar : InkPalette.bronze)
                        Text(tab.title.uppercased())
                    }
                    .font(.system(.caption, design: .serif, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(selection == tab ? InkPalette.cinnabar : InkPalette.softInk)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(InkPalette.paper)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
                .overlay(alignment: .top) {
                    if selection == tab {
                        Rectangle().fill(InkPalette.cinnabar).frame(height: 2)
                    }
                }
            }
        }
        .overlay(alignment: .top) { ClassicalRule() }
    }
}

