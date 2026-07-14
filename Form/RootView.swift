import SwiftUI
import SwiftData

enum InkPalette {
    static let ink = Color(red: 0.08, green: 0.075, blue: 0.065)
    static let softInk = Color(red: 0.34, green: 0.32, blue: 0.28)
    static let paper = Color(red: 0.955, green: 0.938, blue: 0.89)
    static let raisedPaper = Color(red: 0.982, green: 0.969, blue: 0.925)
    static let washedInk = Color(red: 0.83, green: 0.81, blue: 0.75)
}

struct PaperBackground: View {
    var body: some View {
        ZStack {
            InkPalette.paper
            GeometryReader { proxy in
                Path { path in
                    path.move(to: CGPoint(x: -30, y: proxy.size.height * 0.18))
                    path.addCurve(
                        to: CGPoint(x: proxy.size.width + 30, y: proxy.size.height * 0.13),
                        control1: CGPoint(x: proxy.size.width * 0.24, y: proxy.size.height * 0.12),
                        control2: CGPoint(x: proxy.size.width * 0.68, y: proxy.size.height * 0.22)
                    )
                    path.move(to: CGPoint(x: -20, y: proxy.size.height * 0.72))
                    path.addCurve(
                        to: CGPoint(x: proxy.size.width + 20, y: proxy.size.height * 0.78),
                        control1: CGPoint(x: proxy.size.width * 0.34, y: proxy.size.height * 0.82),
                        control2: CGPoint(x: proxy.size.width * 0.72, y: proxy.size.height * 0.68)
                    )
                }
                .stroke(InkPalette.ink.opacity(0.025), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            }
        }
        .ignoresSafeArea()
    }
}

struct InkDivider: View {
    var body: some View {
        HStack(spacing: 4) {
            Capsule().fill(InkPalette.ink.opacity(0.62)).frame(width: 34, height: 2)
            Capsule().fill(InkPalette.ink.opacity(0.20)).frame(height: 1)
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}

private struct InkCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 24, bottomLeading: 18, bottomTrailing: 25, topTrailing: 20),
                    style: .continuous
                )
                .fill(InkPalette.raisedPaper)
                .shadow(color: InkPalette.ink.opacity(0.07), radius: 14, y: 7)
            )
            .overlay {
                UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 24, bottomLeading: 18, bottomTrailing: 25, topTrailing: 20),
                    style: .continuous
                )
                .stroke(InkPalette.ink.opacity(0.10), lineWidth: 1)
            }
    }
}

extension View {
    func inkCard() -> some View {
        modifier(InkCardModifier())
    }
}

struct InkPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(.headline, design: .serif, weight: .semibold))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .semibold))
                    .offset(x: 1)
            }
            .foregroundStyle(InkPalette.paper)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 18, bottomLeading: 15, bottomTrailing: 20, topTrailing: 14),
                    style: .continuous
                )
                .fill(InkPalette.ink)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}

private enum AppTab: CaseIterable, Hashable {
    case train
    case history

    var title: String {
        switch self {
        case .train: "Train"
        case .history: "History"
        }
    }

    var symbol: String {
        switch self {
        case .train: "circle.grid.cross"
        case .history: "clock"
        }
    }
}

struct RootView: View {
    @State private var selection: AppTab = .train

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                RoutineListView()
            }
            .tag(AppTab.train)

            NavigationStack {
                HistoryView()
            }
            .tag(AppTab.history)
        }
        .toolbar(.hidden, for: .tabBar)
        .tint(InkPalette.ink)
        .fontDesign(.serif)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            InkTabBar(selection: $selection)
                .padding(.horizontal, 42)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .background(
                    LinearGradient(
                        colors: [InkPalette.paper.opacity(0), InkPalette.paper],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
        }
    }
}

private struct InkTabBar: View {
    @Binding var selection: AppTab
    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 5) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    selection = tab
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 20, height: 20)
                        Text(tab.title)
                            .font(.system(.subheadline, design: .serif, weight: .semibold))
                    }
                    .foregroundStyle(selection == tab ? InkPalette.paper : InkPalette.softInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background {
                        if selection == tab {
                            UnevenRoundedRectangle(
                                cornerRadii: .init(
                                    topLeading: 16,
                                    bottomLeading: 13,
                                    bottomTrailing: 17,
                                    topTrailing: 12
                                ),
                                style: .continuous
                            )
                            .fill(InkPalette.ink)
                            .matchedGeometryEffect(id: "selected-tab", in: selectionNamespace)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(5)
        .background(
            UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: 22,
                    bottomLeading: 19,
                    bottomTrailing: 24,
                    topTrailing: 18
                ),
                style: .continuous
            )
            .fill(InkPalette.raisedPaper)
            .shadow(color: InkPalette.ink.opacity(0.12), radius: 18, y: 8)
        )
        .overlay {
            UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: 22,
                    bottomLeading: 19,
                    bottomTrailing: 24,
                    topTrailing: 18
                ),
                style: .continuous
            )
            .stroke(.black.opacity(0.10), lineWidth: 1)
        }
        .animation(.easeOut(duration: 0.22), value: selection)
    }
}

private struct RoutineListView: View {
    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                LazyVStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("FORM")
                            .font(.caption.weight(.semibold))
                            .tracking(4)
                            .foregroundStyle(InkPalette.softInk)
                        Text("Train with intent.")
                            .font(.system(size: 39, weight: .semibold, design: .serif))
                            .foregroundStyle(InkPalette.ink)
                        InkDivider()
                            .padding(.vertical, 2)
                        Text("Continue the A → B → C rotation, however often you train.")
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(InkPalette.softInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 12)

                    ForEach(WorkoutCatalog.routines) { routine in
                        NavigationLink(value: routine) {
                            RoutineCard(routine: routine)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 30)
            }
        }
        .navigationDestination(for: RoutineTemplate.self) { routine in
            RoutineDetailView(routine: routine)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct RoutineCard: View {
    let routine: RoutineTemplate

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                Text(routine.id)
                    .font(.system(size: 42, weight: .medium, design: .serif))
                    .foregroundStyle(InkPalette.ink)
                Text(routine.name)
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(InkPalette.ink)
                Text(routine.focus)
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(InkPalette.softInk)
                Capsule()
                    .fill(InkPalette.ink.opacity(0.48))
                    .frame(width: 42, height: 2)
                    .padding(.top, 4)
            }
            .padding(.leading, 18)
            .padding(.vertical, 18)

            Spacer(minLength: 0)

            DemonstrationImage(assetName: routine.exercises[0].assetName, outlined: false)
                .frame(width: 138, height: 142)
                .mask(
                    LinearGradient(
                        colors: [.clear, .black, .black],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .frame(minHeight: 154)
        .inkCard()
        .contentShape(
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 24, bottomLeading: 18, bottomTrailing: 25, topTrailing: 20)
            )
        )
    }
}

private struct RoutineDetailView: View {
    let routine: RoutineTemplate
    @State private var showingWorkout = false

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                LazyVStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(routine.focus.uppercased())
                            .font(.caption.weight(.semibold))
                            .tracking(2.2)
                            .foregroundStyle(InkPalette.softInk)
                        Text("Six movements.\nOne deliberate session.")
                            .font(.system(size: 30, weight: .semibold, design: .serif))
                            .foregroundStyle(InkPalette.ink)
                        InkDivider().padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 8)

                    ForEach(Array(routine.exercises.enumerated()), id: \.element.id) { index, exercise in
                        ExercisePreviewRow(index: index + 1, exercise: exercise)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 104)
            }
        }
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(InkPalette.paper.opacity(0.94), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            InkPrimaryButton(title: "Begin (routine.name)") {
                showingWorkout = true
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(InkPalette.paper.opacity(0.94))
        }
        .fullScreenCover(isPresented: $showingWorkout) {
            NavigationStack {
                ActiveWorkoutView(routine: routine)
            }
        }
    }
}

private struct ExercisePreviewRow: View {
    let index: Int
    let exercise: ExerciseTemplate

    var body: some View {
        HStack(spacing: 16) {
            DemonstrationImage(assetName: exercise.assetName)
                .frame(width: 106, height: 106)

            VStack(alignment: .leading, spacing: 7) {
                Text(String(format: "%02d", index))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(InkPalette.softInk)
                Text(exercise.name)
                    .font(.system(.headline, design: .serif, weight: .semibold))
                    .foregroundStyle(InkPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(exercise.targetText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(InkPalette.softInk)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .inkCard()
    }
}

struct DemonstrationImage: View {
    let assetName: String
    var outlined = true

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .blendMode(.multiply)
            .clipShape(
                UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 15, bottomLeading: 12, bottomTrailing: 16, topTrailing: 11),
                    style: .continuous
                )
            )
            .overlay {
                if outlined {
                    UnevenRoundedRectangle(
                        cornerRadii: .init(topLeading: 15, bottomLeading: 12, bottomTrailing: 16, topTrailing: 11),
                        style: .continuous
                    )
                    .stroke(.black.opacity(0.10), lineWidth: 1)
                }
            }
            .accessibilityLabel("Ink illustration demonstrating the exercise")
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.84 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
