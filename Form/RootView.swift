import SwiftUI
import SwiftData
import UIKit

enum InkPalette {
    static let ink = Color(red: 0.067, green: 0.067, blue: 0.059)
    static let softInk = Color(red: 0.29, green: 0.28, blue: 0.25)
    static let paper = Color(red: 0.914, green: 0.886, blue: 0.835)
    static let raisedPaper = Color(red: 0.957, green: 0.937, blue: 0.898)
    static let washedInk = Color(red: 0.69, green: 0.66, blue: 0.60)
    static let cinnabar = Color(red: 0.835, green: 0.169, blue: 0.118)
    static let acid = Color(red: 0.91, green: 1.0, blue: 0.21)
}

struct PaperSurface: View {
    var body: some View {
        InkPalette.paper
    }
}

struct PaperBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PaperSurface()
                HStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { column in
                        Color.clear
                            .frame(width: proxy.size.width / 4)
                            .overlay(alignment: .trailing) {
                                if column < 3 {
                                    Rectangle()
                                        .fill(InkPalette.ink.opacity(0.055))
                                        .frame(width: 1)
                                }
                            }
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct InkDivider: View {
    var body: some View {
        Rectangle()
            .fill(InkPalette.ink)
            .frame(height: 1)
        .accessibilityHidden(true)
    }
}

struct RawScreenTitle: View {
    let index: String
    let title: String
    var detail: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("FORM—\(index)")
                Spacer()
                if !detail.isEmpty { Text(detail) }
            }
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(1.1)
            .foregroundStyle(InkPalette.softInk)

            Text(title.uppercased())
                .font(.system(size: 64, weight: .black, design: .default))
                .tracking(-4.8)
                .foregroundStyle(InkPalette.ink)
                .minimumScaleFactor(0.62)
                .lineLimit(1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 30)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { InkDivider() }
    }
}

struct RawSectionHeader: View {
    let index: String
    let title: String
    var trailing: String = ""

    var body: some View {
        HStack(spacing: 0) {
            Text(index)
                .frame(width: 48)
                .overlay(alignment: .trailing) { Rectangle().fill(InkPalette.ink).frame(width: 1) }
            Text(title)
                .padding(.leading, 12)
            Spacer()
            if !trailing.isEmpty {
                Text(trailing)
                    .foregroundStyle(InkPalette.softInk)
                    .padding(.trailing, 12)
            }
        }
        .font(.system(size: 9, weight: .bold, design: .monospaced))
        .tracking(1)
        .frame(height: 42)
        .overlay { Rectangle().stroke(InkPalette.ink, lineWidth: 1) }
    }
}

struct InkTextHeader: View {
    let title: String
    let leadingTitle: String
    let leadingAction: () -> Void
    var trailingTitle: String?
    var trailingAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
                Button(leadingTitle, action: leadingAction)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .textCase(.uppercase)
                    .foregroundStyle(InkPalette.ink)
                    .frame(width: 76, height: 52)
                    .overlay(alignment: .trailing) {
                        Rectangle().fill(InkPalette.ink).frame(width: 1)
                    }
                    .buttonStyle(PressableButtonStyle())

                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(InkPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                    .frame(maxWidth: .infinity)

                if let trailingTitle, let trailingAction {
                    Button(trailingTitle, action: trailingAction)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .textCase(.uppercase)
                        .foregroundStyle(InkPalette.cinnabar)
                        .frame(width: 76, height: 52)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(InkPalette.ink).frame(width: 1)
                        }
                        .buttonStyle(PressableButtonStyle())
                } else {
                    Color.clear
                        .frame(width: 76, height: 52)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(InkPalette.ink).frame(width: 1)
                        }
                        .accessibilityHidden(true)
                }
        }
        .background { PaperSurface() }
        .overlay(alignment: .bottom) { Rectangle().fill(InkPalette.ink).frame(height: 1) }
    }
}

private struct InkCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(InkPalette.raisedPaper)
            .overlay { Rectangle().stroke(InkPalette.ink, lineWidth: 1) }
    }
}

@MainActor
func dismissKeyboard() {
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil,
        from: nil,
        for: nil
    )
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
                    dismissKeyboard()
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
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .textCase(.uppercase)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .semibold))
                    .offset(x: 1)
            }
            .foregroundStyle(InkPalette.paper)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(InkPalette.cinnabar)
            .overlay { Rectangle().stroke(InkPalette.ink, lineWidth: 1.5) }
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
            .fontDesign(.default)
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
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeOut(duration: 0.24)) {
                        selection = tab
                    }
                } label: {
                    HStack(spacing: 9) {
                        Text(tab == .train ? "01" : "02")
                            .foregroundStyle(selection == tab ? InkPalette.acid : InkPalette.softInk)
                        Text(tab.title.uppercased())
                    }
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(selection == tab ? InkPalette.raisedPaper : InkPalette.ink)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(selection == tab ? InkPalette.ink : InkPalette.paper)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
                .overlay(alignment: .trailing) {
                    if tab == .train { Rectangle().fill(InkPalette.ink).frame(width: 1) }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(InkPalette.paper)
        .overlay(alignment: .top) { Rectangle().fill(InkPalette.ink).frame(height: 1) }
        .animation(.easeOut(duration: 0.22), value: selection)
    }
}

private struct RoutineListView: View {
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var workouts: [WorkoutRecord]
    @AppStorage("progression-load-increment") private var loadIncrement = 2.5
    @AppStorage("keep-screen-awake") private var keepScreenAwake = true
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
                    RawScreenTitle(index: "01", title: "Train", detail: "A → B → C")
                        .padding(.horizontal, -20)
                        .padding(.bottom, 24)

                    if let resumeRoutine {
                        Button {
                            showingResume = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("00 / ACTIVE SESSION")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .tracking(1)
                                        .foregroundStyle(InkPalette.cinnabar)
                                    Text("Resume \(resumeRoutine.name)")
                                        .font(.system(.title3, design: .default, weight: .black))
                                        .foregroundStyle(InkPalette.ink)
                                    Text(resumeDetail)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(InkPalette.softInk)
                                }
                                Spacer()
                                Text("RESUME")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .tracking(1)
                                    .foregroundStyle(InkPalette.ink)
                                    .frame(minWidth: 54, minHeight: 44)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(InkPalette.acid)
                            .overlay { Rectangle().stroke(InkPalette.ink, lineWidth: 1) }
                        }
                        .buttonStyle(PressableButtonStyle())
                        .padding(.bottom, 24)
                    }

                    RawSectionHeader(index: "01", title: "NEXT WORKOUT", trailing: "UP NEXT")
                        .padding(.bottom, 10)

                    NavigationLink(value: nextRoutine) {
                        RoutineCard(
                            routine: nextRoutine,
                            isRecommended: true,
                            lastCompleted: lastCompleted(nextRoutine)
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.bottom, 28)

                    RawSectionHeader(index: "02", title: "ROTATION", trailing: "CONTINUE")
                        .padding(.bottom, 10)

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
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(1)
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
                    .padding(.horizontal, 12)
                    .overlay { Rectangle().stroke(InkPalette.ink, lineWidth: 1) }

                    InkDivider()

                    Toggle(isOn: $keepScreenAwake) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("KEEP SCREEN AWAKE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(1)
                                .foregroundStyle(InkPalette.softInk)
                            Text("While a workout is in progress")
                                .font(.system(.caption, design: .serif))
                                .foregroundStyle(InkPalette.softInk.opacity(0.76))
                        }
                    }
                    .tint(InkPalette.cinnabar)
                    .frame(minHeight: 58)
                    .padding(.horizontal, 12)
                    .overlay { Rectangle().stroke(InkPalette.ink, lineWidth: 1) }
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
                    .font(.system(size: 62, weight: .black, design: .default))
                    .tracking(-4)
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
        .background(InkPalette.raisedPaper)
        .overlay {
            Rectangle().stroke(InkPalette.ink, lineWidth: isRecommended ? 2 : 1)
        }
        .overlay(alignment: .top) {
            if isRecommended { Rectangle().fill(InkPalette.cinnabar).frame(height: 5) }
        }
        .contentShape(Rectangle())
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
                    RawScreenTitle(
                        index: routine.id,
                        title: routine.name,
                        detail: "\(routine.exercises.count) MOVEMENTS"
                    )
                    .padding(.horizontal, -20)
                    .padding(.bottom, 6)

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
                Rectangle()
            )
            .overlay {
                if outlined {
                    Rectangle().stroke(.black.opacity(0.10), lineWidth: 1)
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
