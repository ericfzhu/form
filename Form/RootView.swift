import SwiftUI
import SwiftData
import UIKit

enum InkPalette {
    static let ink = Color(red: 0.08, green: 0.075, blue: 0.065)
    static let softInk = Color(red: 0.34, green: 0.32, blue: 0.28)
    static let paper = Color(red: 0.955, green: 0.938, blue: 0.89)
    static let raisedPaper = Color(red: 0.982, green: 0.969, blue: 0.925)
    static let washedInk = Color(red: 0.83, green: 0.81, blue: 0.75)
    static let cinnabar = Color(red: 0.56, green: 0.12, blue: 0.09)
}

struct PaperSurface: View {
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
    }
}

struct PaperBackground: View {
    var body: some View {
        PaperSurface()
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

struct InkTextHeader: View {
    let title: String
    let leadingTitle: String
    let leadingAction: () -> Void
    var trailingTitle: String?
    var trailingAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Button(leadingTitle, action: leadingAction)
                    .font(.system(.subheadline, design: .serif, weight: .medium))
                    .foregroundStyle(InkPalette.ink)
                    .frame(minWidth: 58, minHeight: 44, alignment: .leading)
                    .buttonStyle(PressableButtonStyle())

                Spacer()

                Text(title)
                    .font(.caption.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(InkPalette.softInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Spacer()

                if let trailingTitle, let trailingAction {
                    Button(trailingTitle, action: trailingAction)
                        .font(.system(.subheadline, design: .serif, weight: .semibold))
                        .foregroundStyle(InkPalette.cinnabar)
                        .frame(minWidth: 58, minHeight: 44, alignment: .trailing)
                        .buttonStyle(PressableButtonStyle())
                } else {
                    Color.clear
                        .frame(width: 58, height: 44)
                        .accessibilityHidden(true)
                }
            }

            InkDivider()
        }
        .padding(.horizontal, 20)
        .padding(.top, 2)
        .padding(.bottom, 6)
        .background {
            PaperSurface()
        }
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

    func keyboardDismissToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
                .font(.system(.body, design: .serif, weight: .semibold))
                .tint(InkPalette.cinnabar)
            }
        }
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
    @State private var navigationPath = NavigationPath()

    private var isFooterVisible: Bool {
        navigationPath.isEmpty
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PaperBackground()

                NavigationStack(path: $navigationPath) {
                    TabView(selection: $selection) {
                        RoutineListView()
                            .tag(AppTab.train)

                        HistoryView()
                            .tag(AppTab.history)
                    }
                    .background(Color.clear)
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .navigationDestination(for: RoutineTemplate.self) { routine in
                        RoutineDetailView(routine: routine)
                    }
                    .navigationDestination(for: ExerciseTemplate.self) { exercise in
                        ExerciseProgressView(exercise: exercise)
                    }
                    .navigationDestination(for: WorkoutRecord.self) { workout in
                        WorkoutHistoryDetail(workout: workout)
                    }
                }
                .background(Color.clear)

                PaperSurface()
                    .frame(height: proxy.safeAreaInsets.top)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
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

}

private struct InkTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 56) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeOut(duration: 0.24)) {
                        selection = tab
                    }
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
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var workouts: [WorkoutRecord]
    @AppStorage("progression-load-increment") private var loadIncrement = 2.5
    @State private var resumeSnapshot: ActiveWorkoutSnapshot?
    @State private var showingResume = false

    private var nextRoutine: RoutineTemplate {
        guard let latestRoutineName = workouts.first?.routineName,
              let latestIndex = WorkoutCatalog.routines.firstIndex(where: {
                  $0.name == latestRoutineName
              }) else {
            return WorkoutCatalog.routines[0]
        }
        return WorkoutCatalog.routines[(latestIndex + 1) % WorkoutCatalog.routines.count]
    }

    private var remainingRoutines: [RoutineTemplate] {
        WorkoutCatalog.routines.filter { $0.id != nextRoutine.id }
    }

    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if let resumeRoutine {
                        Button {
                            showingResume = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("ACTIVE SESSION")
                                        .font(.caption2.weight(.semibold))
                                        .tracking(1.5)
                                        .foregroundStyle(InkPalette.cinnabar)
                                    Text("Resume \(resumeRoutine.name)")
                                        .font(.system(.title3, design: .serif, weight: .semibold))
                                        .foregroundStyle(InkPalette.ink)
                                    Text(resumeDetail)
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(InkPalette.softInk)
                                }
                                Spacer()
                                Text("RESUME")
                                    .font(.caption2.weight(.semibold))
                                    .tracking(1.1)
                                    .foregroundStyle(InkPalette.ink)
                                    .frame(minWidth: 54, minHeight: 44)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(InkPalette.raisedPaper.opacity(0.88))
                            )
                        }
                        .buttonStyle(PressableButtonStyle())
                        .padding(.bottom, 24)
                    }

                    Text("NEXT WORKOUT")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.8)
                        .foregroundStyle(InkPalette.softInk)
                        .padding(.bottom, 9)

                    NavigationLink(value: nextRoutine) {
                        RoutineCard(
                            routine: nextRoutine,
                            isRecommended: true,
                            lastCompleted: lastCompleted(nextRoutine)
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.bottom, 28)

                    Text("ROTATION")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.8)
                        .foregroundStyle(InkPalette.softInk)
                        .padding(.bottom, 9)

                    LazyVStack(spacing: 14) {
                        ForEach(remainingRoutines) { routine in
                            NavigationLink(value: routine) {
                                RoutineCard(
                                    routine: routine,
                                    lastCompleted: lastCompleted(routine)
                                )
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }

                    HStack {
                        Text("LOAD INCREMENT")
                            .font(.caption2.weight(.semibold))
                            .tracking(1.4)
                            .foregroundStyle(InkPalette.softInk)
                        Spacer()
                        Picker("Load increment", selection: $loadIncrement) {
                            ForEach([1.0, 1.25, 2.0, 2.5, 5.0], id: \.self) { value in
                                Text("\(value.formatted(.number.precision(.fractionLength(0...2)))) kg")
                                    .tag(value)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(InkPalette.ink)
                    }
                    .frame(minHeight: 52)
                    .padding(.top, 14)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 30)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            resumeSnapshot = ActiveWorkoutStore.load()
        }
        .fullScreenCover(isPresented: $showingResume, onDismiss: {
            resumeSnapshot = ActiveWorkoutStore.load()
        }) {
            if let resumeSnapshot, let resumeRoutine {
                ActiveWorkoutView(routine: resumeRoutine, snapshot: resumeSnapshot) {
                    self.resumeSnapshot = nil
                }
            }
        }
    }

    private var resumeRoutine: RoutineTemplate? {
        guard let resumeSnapshot else { return nil }
        return WorkoutCatalog.routines.first { $0.id == resumeSnapshot.routineID }
    }

    private var resumeDetail: String {
        guard let resumeSnapshot else { return "" }
        let completedSets = resumeSnapshot.exercises.reduce(0) {
            $0 + $1.sets.filter(\.completed).count
        }
        return "Started \(resumeSnapshot.startedAt.formatted(date: .omitted, time: .shortened)) · \(completedSets) sets"
    }

    private func lastCompleted(_ routine: RoutineTemplate) -> Date? {
        workouts.first { $0.routineName == routine.name }?.date
    }
}

private struct RoutineCard: View {
    let routine: RoutineTemplate
    var isRecommended = false
    var lastCompleted: Date?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                if isRecommended {
                    HStack(spacing: 7) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(InkPalette.cinnabar)
                            .frame(width: 8, height: 8)
                        Text("UP NEXT")
                            .font(.caption2.weight(.semibold))
                            .tracking(1.6)
                            .foregroundStyle(InkPalette.cinnabar)
                    }
                }

                Text(routine.id)
                    .font(.system(size: 48, weight: .medium, design: .serif))
                    .foregroundStyle(InkPalette.ink)
                Text(routine.focus.replacingOccurrences(of: " · ", with: ", "))
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundStyle(InkPalette.softInk.opacity(0.82))
                    .lineSpacing(3)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(lastCompletedText)
                    .font(.system(.caption, design: .serif))
                    .foregroundStyle(InkPalette.softInk.opacity(0.72))
                    .monospacedDigit()
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

    private var lastCompletedText: String {
        guard let lastCompleted else { return "Not completed yet" }
        return "Last · \(lastCompleted.formatted(.dateTime.day().month(.abbreviated)))"
    }
}

struct RoutineDetailView: View {
    let routine: RoutineTemplate
    @Environment(\.dismiss) private var dismiss
    @State private var showingWorkout = false
    @State private var shouldReturnToTrain = false

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(Array(routine.exercises.enumerated()), id: \.element.id) { index, exercise in
                        NavigationLink(value: exercise) {
                            ExercisePreviewRow(index: index + 1, exercise: exercise)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 104)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background {
            InteractivePopGestureBridge(isEnabled: true)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            InkTextHeader(
                title: routine.name.uppercased(),
                leadingTitle: "Back",
                leadingAction: { dismiss() }
            )
        }
        .safeAreaInset(edge: .bottom) {
            InkPrimaryButton(title: "Begin \(routine.name)") {
                showingWorkout = true
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(InkPalette.paper.opacity(0.94))
        }
        .fullScreenCover(isPresented: $showingWorkout, onDismiss: {
            if shouldReturnToTrain {
                dismiss()
            }
        }) {
            ActiveWorkoutView(routine: routine) {
                shouldReturnToTrain = true
            }
        }
    }
}

private struct ExercisePreviewRow: View {
    let index: Int
    let exercise: ExerciseTemplate
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var workouts: [WorkoutRecord]

    private var previous: ExercisePerformance? {
        ProgressionEngine.latestCompleted(for: exercise.name, in: workouts)
    }

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
                if let previous {
                    Text("Last · \(performanceText(previous))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(InkPalette.cinnabar)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .inkCard()
    }

    private func performanceText(_ performance: ExercisePerformance) -> String {
        switch exercise.measurement {
        case .weighted:
            guard let topSet = performance.topSet else { return "No completed sets" }
            let weight = topSet.weight.formatted(
                .number.precision(.fractionLength(topSet.weight.rounded() == topSet.weight ? 0 : 1))
            )
            return "\(weight) kg × \(topSet.repetitions)"
        case .bodyweight:
            return "\(performance.bestRepetitions) reps"
        case .timed:
            return "\(performance.bestRepetitions) sec"
        }
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

private struct LeadingEdgeSwipeModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content.overlay(alignment: .leading) {
            Color.clear
                .frame(width: 36)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 14)
                        .onEnded { value in
                            let horizontalDistance = value.translation.width
                            let projectedDistance = value.predictedEndTranslation.width
                            guard horizontalDistance > 45,
                                  projectedDistance > 90,
                                  horizontalDistance > abs(value.translation.height) * 1.4 else { return }
                            action()
                        }
                )
                .accessibilityHidden(true)
        }
    }
}

extension View {
    func leadingEdgeSwipe(action: @escaping () -> Void) -> some View {
        modifier(LeadingEdgeSwipeModifier(action: action))
    }
}

struct InteractivePopGestureBridge: UIViewRepresentable {
    let isEnabled: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> NavigationResolverView {
        let view = NavigationResolverView()
        view.onResolve = { [weak coordinator = context.coordinator] navigationController in
            coordinator?.configure(navigationController)
        }
        return view
    }

    func updateUIView(
        _ view: NavigationResolverView,
        context: Context
    ) {
        context.coordinator.isEnabled = isEnabled
        view.resolveNavigationController()
    }

    static func dismantleUIView(
        _ view: NavigationResolverView,
        coordinator: Coordinator
    ) {
        coordinator.restore()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var isEnabled = false

        private weak var navigationController: UINavigationController?
        private weak var gestureRecognizer: UIGestureRecognizer?
        private var previousDelegate: UIGestureRecognizerDelegate?

        func configure(_ navigationController: UINavigationController) {
            guard let gestureRecognizer = navigationController.interactivePopGestureRecognizer else {
                return
            }

            if self.navigationController !== navigationController {
                restore()
                self.navigationController = navigationController
                self.gestureRecognizer = gestureRecognizer
                previousDelegate = gestureRecognizer.delegate
            }

            gestureRecognizer.delegate = self
            gestureRecognizer.isEnabled = isEnabled
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard isEnabled,
                  let navigationController,
                  navigationController.viewControllers.count > 1,
                  navigationController.transitionCoordinator == nil,
                  let panGesture = gestureRecognizer as? UIPanGestureRecognizer else {
                return false
            }

            let velocity = panGesture.velocity(in: panGesture.view)
            return velocity.x > 0 && velocity.x > abs(velocity.y)
        }

        func restore() {
            guard let gestureRecognizer else { return }
            if gestureRecognizer.delegate === self {
                gestureRecognizer.delegate = previousDelegate
            }
            self.gestureRecognizer = nil
            navigationController = nil
            previousDelegate = nil
        }
    }
}

final class NavigationResolverView: UIView {
    var onResolve: ((UINavigationController) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        resolveNavigationController()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        resolveNavigationController()
    }

    func resolveNavigationController() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            var responder: UIResponder? = self
            while let current = responder {
                if let navigationController = current as? UINavigationController {
                    self.onResolve?(navigationController)
                    return
                }
                if let viewController = current as? UIViewController,
                   let navigationController = viewController.navigationController {
                    self.onResolve?(navigationController)
                    return
                }
                responder = current.next
            }
        }
    }
}
