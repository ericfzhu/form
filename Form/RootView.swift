import SwiftUI
import SwiftData

enum InkPalette {
    static let ink = Color(red: 0.08, green: 0.075, blue: 0.065)
    static let softInk = Color(red: 0.34, green: 0.32, blue: 0.28)
    static let paper = Color(red: 0.955, green: 0.938, blue: 0.89)
    static let raisedPaper = Color(red: 0.982, green: 0.969, blue: 0.925)
    static let washedInk = Color(red: 0.83, green: 0.81, blue: 0.75)
    static let cinnabar = Color(red: 0.56, green: 0.12, blue: 0.09)
}

struct PaperBackground: View {
    var body: some View {
        ZStack {
            InkPalette.paper
            Image("xuan-paper")
                .resizable(resizingMode: .tile)
                .blendMode(.multiply)
                .opacity(0.34)
            LinearGradient(
                colors: [.white.opacity(0.12), .clear, InkPalette.ink.opacity(0.018)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

struct InkDivider: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 2))
                path.addCurve(
                    to: CGPoint(x: proxy.size.width, y: 2),
                    control1: CGPoint(x: proxy.size.width * 0.30, y: 1.2),
                    control2: CGPoint(x: proxy.size.width * 0.70, y: 2.8)
                )
            }
            .stroke(
                InkPalette.ink.opacity(0.24),
                style: StrokeStyle(lineWidth: 1, lineCap: .round)
            )
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}

private struct InkCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
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
                BrushBandShape()
                    .fill(InkPalette.ink)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}

private struct BrushBandShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 5, y: rect.minY + 3))
        path.addCurve(
            to: CGPoint(x: rect.maxX - 3, y: rect.minY + 1),
            control1: CGPoint(x: rect.width * 0.28, y: rect.minY),
            control2: CGPoint(x: rect.width * 0.72, y: rect.minY + 5)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 5))
        path.addCurve(
            to: CGPoint(x: rect.minX + 2, y: rect.maxY - 2),
            control1: CGPoint(x: rect.width * 0.68, y: rect.maxY),
            control2: CGPoint(x: rect.width * 0.24, y: rect.maxY - 5)
        )
        path.closeSubpath()
        return path
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
    @State private var trainPath: [RoutineTemplate] = []
    @State private var historyPath: [WorkoutRecord] = []

    private var isFooterVisible: Bool {
        switch selection {
        case .train: trainPath.isEmpty
        case .history: historyPath.isEmpty
        }
    }

    var body: some View {
        ZStack {
            NavigationStack(path: $trainPath) {
                RoutineListView()
            }
            .opacity(selection == .train ? 1 : 0)
            .allowsHitTesting(selection == .train)
            .accessibilityHidden(selection != .train)

            NavigationStack(path: $historyPath) {
                HistoryView()
            }
            .opacity(selection == .history ? 1 : 0)
            .allowsHitTesting(selection == .history)
            .accessibilityHidden(selection != .history)
        }
        .tint(InkPalette.ink)
        .fontDesign(.serif)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isFooterVisible {
                InkTabBar(selection: $selection)
            }
        }
    }
}

private struct InkTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 56) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        HStack(spacing: 7) {
                            Image(systemName: tab.symbol)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(selection == tab ? InkPalette.cinnabar : InkPalette.softInk.opacity(0.55))
                            Text(tab.title)
                                .font(.system(.subheadline, design: .serif, weight: selection == tab ? .semibold : .regular))
                                .foregroundStyle(selection == tab ? InkPalette.ink : InkPalette.softInk.opacity(0.62))
                        }
                        Circle()
                            .fill(selection == tab ? InkPalette.cinnabar : .clear)
                            .frame(width: 4, height: 4)
                    }
                    .frame(minWidth: 96, minHeight: 50)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(InkPalette.raisedPaper.opacity(0.82))
        .animation(.easeOut(duration: 0.22), value: selection)
    }
}

private struct RoutineListView: View {
    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                LazyVStack(spacing: 0) {
                    VStack(spacing: 0) {
                        Text("Continue the A → B → C rotation, however often you train.")
                            .font(.system(.caption, design: .serif))
                            .foregroundStyle(InkPalette.softInk.opacity(0.72))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 28)

                    LazyVStack(spacing: 16) {
                        ForEach(WorkoutCatalog.routines) { routine in
                            NavigationLink(value: routine) {
                                RoutineCard(routine: routine)
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
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
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 9) {
                Text(routine.id)
                    .font(.system(size: 48, weight: .medium, design: .serif))
                    .foregroundStyle(InkPalette.ink)
                Text(routine.focus.replacingOccurrences(of: " · ", with: ", "))
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundStyle(InkPalette.softInk.opacity(0.82))
                    .lineSpacing(3)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            DemonstrationImage(assetName: routine.exercises[0].assetName, outlined: false)
                .frame(width: 136, height: 144)
                .offset(x: -10)
                .mask(
                    RadialGradient(
                        colors: [.black, .black, .clear],
                        center: .center,
                        startRadius: 42,
                        endRadius: 105
                    )
                )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .frame(minHeight: 174)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(InkPalette.raisedPaper.opacity(0.92))
                .shadow(color: InkPalette.ink.opacity(0.07), radius: 12, y: 6)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.black.opacity(0.08), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct RoutineDetailView: View {
    let routine: RoutineTemplate
    @Environment(\.dismiss) private var dismiss
    @State private var showingWorkout = false

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                LazyVStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 0) {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(InkPalette.ink)
                                    .frame(width: 40, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PressableButtonStyle())
                            .accessibilityLabel("Back")

                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(InkPalette.cinnabar)
                                    .frame(width: 9, height: 9)
                                Text(routine.focus.uppercased())
                                    .font(.caption.weight(.semibold))
                                    .tracking(2.2)
                                    .foregroundStyle(InkPalette.softInk)
                            }
                        }
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
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            InkPrimaryButton(title: "Begin \(routine.name)") {
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
        InkPalette.ink
            .mask {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .grayscale(1)
                    .contrast(3)
                    .colorInvert()
                    .luminanceToAlpha()
            }
            .clipShape(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
            )
            .overlay {
                if outlined {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
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
