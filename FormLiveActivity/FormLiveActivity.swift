import ActivityKit
import SwiftUI
import WidgetKit

@main
struct FormLiveActivityBundle: WidgetBundle {
    var body: some Widget { FormWorkoutLiveActivity() }
}

struct FormWorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            CounterweightLockActivity(state: context.state, isStale: context.isStale, url: sessionURL(context))
                .activityBackgroundTint(.white)
                .activitySystemActionForegroundColor(ActivityInk.ink)
                .widgetURL(sessionURL(context))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 7) {
                        CounterweightActivityMark().frame(width: 22, height: 22)
                        Text("form").font(.system(size: 20, weight: .bold)).tracking(-1)
                    }
                    .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.phase(at: .now, isStale: context.isStale).title)
                        .font(.caption2).foregroundStyle(ActivityInk.islandQuiet)
                        .padding(.trailing, 8)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    CounterweightExpandedActivity(state: context.state, isStale: context.isStale, url: sessionURL(context))
                }
            } compactLeading: {
                CounterweightActivityMark().frame(width: 22, height: 22)
            } compactTrailing: {
                CounterweightCompactActivity(state: context.state, isStale: context.isStale)
            } minimal: {
                CounterweightActivityMark().frame(width: 24, height: 24)
            }
            .keylineTint(ActivityInk.blue)
            .widgetURL(sessionURL(context))
        }
    }

    private func sessionURL(_ context: ActivityViewContext<WorkoutActivityAttributes>) -> URL {
        URL(string: "form://session/\(context.attributes.sessionID.uuidString)")!
    }
}

private enum ActivityInk {
    static let ink = Color(red: 5/255, green: 18/255, blue: 48/255)
    static let blue = Color(red: 151/255, green: 172/255, blue: 200/255)
    static let quiet = Color(red: 0.38, green: 0.43, blue: 0.50)
    static let islandQuiet = Color(red: 0.69, green: 0.75, blue: 0.83)
    static let islandBlue = Color(red: 0.74, green: 0.82, blue: 0.92)
}

private extension LiveWorkoutState.Phase {
    var title: String {
        switch self {
        case .lifting: "Lifting"
        case .resting: "Resting"
        case .ready: "Ready"
        case .walking: "Walking"
        case .paused: "Paused"
        }
    }
    var timerLabel: String {
        switch self {
        case .lifting: "elapsed"
        case .resting: "rest"
        case .ready: "rest"
        case .walking: "walk"
        case .paused: "elapsed"
        }
    }
}

/// The mascot's face is reduced to three shapes for the smallest Island regions.
private struct CounterweightActivityMark: View {
    var body: some View {
        GeometryReader { proxy in
            let scale = CGAffineTransform(scaleX: proxy.size.width / 100, y: proxy.size.height / 100)
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 5, y: 70))
                    p.addCurve(to: CGPoint(x: 60, y: 10), control1: CGPoint(x: 10, y: 39), control2: CGPoint(x: 34, y: 8))
                    p.addCurve(to: CGPoint(x: 96, y: 72), control1: CGPoint(x: 84, y: 9), control2: CGPoint(x: 92, y: 42))
                    p.addCurve(to: CGPoint(x: 5, y: 70), control1: CGPoint(x: 100, y: 94), control2: CGPoint(x: 2, y: 96))
                }.transform(scale).fill(ActivityInk.blue)
                Path { p in
                    p.move(to: CGPoint(x: 19, y: 66))
                    p.addCurve(to: CGPoint(x: 60, y: 23), control1: CGPoint(x: 24, y: 43), control2: CGPoint(x: 41, y: 22))
                    p.addCurve(to: CGPoint(x: 82, y: 65), control1: CGPoint(x: 75, y: 23), control2: CGPoint(x: 81, y: 47))
                    p.addCurve(to: CGPoint(x: 19, y: 66), control1: CGPoint(x: 85, y: 79), control2: CGPoint(x: 15, y: 80))
                }.transform(scale).fill(.white)
                Path { p in
                    p.addEllipse(in: CGRect(x: 40, y: 48, width: 8, height: 15))
                    p.addEllipse(in: CGRect(x: 61, y: 47, width: 8, height: 15))
                }.transform(scale).fill(ActivityInk.ink)
            }
        }
        .accessibilityLabel("Form workout")
    }
}

private extension LiveWorkoutState {
    func artwork(for phase: Phase) -> String {
        switch phase {
        case .resting, .paused: return "pause"
        case .walking: return "walk"
        case .lifting, .ready:
            let supported = ["squat", "bench-press", "seated-row", "leg-curl", "rdl", "incline-press", "pulldown", "reverse-lunge"]
            return exerciseArtwork.flatMap { supported.contains($0) ? $0 : nil } ?? "arrive"
        }
    }
}

private struct ActivityTimer: View {
    let state: LiveWorkoutState
    let phase: LiveWorkoutState.Phase

    var body: some View {
        Group {
            switch phase {
            case .resting:
                if let end = state.restEnd {
                    Text(timerInterval: min(Date.now, end)...end, countsDown: true)
                }
            case .walking:
                if let start = state.walkTimerStartedAt {
                    Text(timerInterval: start...Date.distantFuture, countsDown: false, showsHours: false)
                }
                else { Text("0:00") }
            case .lifting:
                if let start = state.sessionTimerStartedAt {
                    Text(timerInterval: start...Date.distantFuture, countsDown: false, showsHours: false)
                }
            case .ready: Text("Ready")
            case .paused:
                let seconds = max(0, Int(state.pausedDuration))
                Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }

}

private struct CounterweightCompactActivity: View {
    let state: LiveWorkoutState
    let isStale: Bool
    private var phase: LiveWorkoutState.Phase { state.phase(isStale: isStale) }
    var body: some View {
        Group {
            switch phase {
            case .lifting:
                Text("\(state.completedMovements)/\(state.totalMovements)")
                    .accessibilityLabel(state.progress)
            case .paused:
                Image(systemName: "pause.fill").accessibilityLabel("Session paused")
            default: ActivityTimer(state: state, phase: phase)
            }
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(ActivityInk.islandBlue)
        .frame(width: 46)
    }
}

private struct CounterweightExpandedActivity: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let state: LiveWorkoutState
    let isStale: Bool
    let url: URL
    private var phase: LiveWorkoutState.Phase { state.phase(isStale: isStale) }
    var body: some View {
        HStack(spacing: 12) {
            if !typeSize.isAccessibilitySize {
                CounterweightActivityArtwork(name: state.artwork(for: phase))
                    .padding(5).frame(width: 48, height: 48)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityHidden(true)
            }
            Link(destination: url) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(state.currentExercise).font(.subheadline).foregroundStyle(.white)
                        .lineLimit(2)
                    HStack(spacing: 5) {
                        Text(state.progress).lineLimit(2)
                        Image(systemName: "arrow.up.right").accessibilityHidden(true)
                    }.font(.system(size: 10)).foregroundStyle(ActivityInk.islandQuiet)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }.accessibilityLabel("Open workout session, \(state.currentExercise), \(state.progress)")
            VStack(alignment: .trailing, spacing: 3) {
                ActivityTimer(state: state, phase: phase)
                    .font(.system(size: phase == .ready ? 22 : 27, weight: .medium))
                    .foregroundStyle(ActivityInk.islandBlue)
                    .frame(width: 84, alignment: .trailing)
                Text(phase.timerLabel).font(.system(size: 9)).foregroundStyle(ActivityInk.islandQuiet)
            }
        }
        .padding(.top, 8).padding(.horizontal, 6).padding(.bottom, 6)
    }
}

private struct ActivityProgress: View {
    let state: LiveWorkoutState
    var dark = false
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<min(8, max(0, state.totalMovements)), id: \.self) { index in
                    Capsule().fill(index < state.completedMovements
                        ? (dark ? ActivityInk.islandBlue : ActivityInk.blue)
                        : (dark ? Color.white.opacity(0.2) : ActivityInk.blue.opacity(0.25)))
                        .frame(width: 10, height: 3)
                }
            }.accessibilityHidden(true)
            Text(state.progress).font(.system(size: 10)).lineLimit(2)
                .foregroundStyle(dark ? ActivityInk.islandQuiet : ActivityInk.quiet)
        }
    }
}

private struct CounterweightLockActivity: View {
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.dynamicTypeSize) private var typeSize
    let state: LiveWorkoutState
    let isStale: Bool
    let url: URL
    private var phase: LiveWorkoutState.Phase { state.phase(isStale: isStale) }
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("form").font(.system(size: 20, weight: .bold)).tracking(-1)
                Spacer()
                Text(phase.title).font(.caption.weight(.medium)).foregroundStyle(ActivityInk.ink)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(ActivityInk.blue.opacity(0.18), in: Capsule())
            }
            HStack(spacing: 12) {
                if !typeSize.isAccessibilitySize {
                    CounterweightActivityArtwork(name: state.artwork(for: phase))
                        .frame(width: 56, height: 56)
                        .opacity(isLuminanceReduced ? 0.7 : 1)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(state.currentExercise).font(.subheadline)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 3) {
                    ActivityTimer(state: state, phase: phase)
                        .font(.system(size: isLuminanceReduced ? 20 : (phase == .ready ? 22 : 29), weight: .regular))
                        .frame(width: isLuminanceReduced ? 112 : 84, alignment: .trailing)
                    Text(phase.timerLabel).font(.system(size: 9)).foregroundStyle(ActivityInk.quiet)
                }
            }
            HStack {
                ActivityProgress(state: state)
                Spacer(minLength: 6)
                Link(destination: url) {
                    Label("Open", systemImage: "arrow.up.right")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 14).frame(minHeight: 44)
                        .background(ActivityInk.blue.opacity(0.18), in: Capsule())
                }.accessibilityLabel("Open workout session")
            }
        }
        .foregroundStyle(ActivityInk.ink)
        .padding(.horizontal, 18).padding(.vertical, 8)
    }
}

#if DEBUG
private extension WorkoutActivityAttributes {
    static let preview = Self(sessionID: UUID(), routineName: "Session A", startedAt: .now.addingTimeInterval(-720))
}
private extension LiveWorkoutState {
    static let lifting = Self(completedMovements: 0, totalMovements: 4, currentExercise: "Barbell back squat", restEnd: nil, sessionTimerStartedAt: .now.addingTimeInterval(-720), pausedDuration: 720, exerciseArtwork: "squat")
    static let resting = Self(completedMovements: 1, totalMovements: 4, currentExercise: "Barbell bench press", restEnd: .now.addingTimeInterval(84), sessionTimerStartedAt: .now.addingTimeInterval(-720), pausedDuration: 720, exerciseArtwork: "bench-press")
    static let ready = Self(completedMovements: 1, totalMovements: 4, currentExercise: "Barbell bench press", restEnd: .now.addingTimeInterval(-1), sessionTimerStartedAt: .now.addingTimeInterval(-720), pausedDuration: 720, exerciseArtwork: "bench-press")
    static let walking = Self(completedMovements: 4, totalMovements: 4, currentExercise: "Treadmill walk", restEnd: nil, sessionTimerStartedAt: .now.addingTimeInterval(-1800), pausedDuration: 1800, walkTimerStartedAt: .now.addingTimeInterval(-372), isWalk: true)
    static let paused = Self(completedMovements: 1, totalMovements: 4, currentExercise: "Barbell bench press", restEnd: nil, sessionTimerStartedAt: nil, pausedDuration: 1122)
}
#Preview("Lock Screen", as: .content, using: WorkoutActivityAttributes.preview) {
    FormWorkoutLiveActivity()
} contentStates: { LiveWorkoutState.resting; LiveWorkoutState.ready; LiveWorkoutState.walking; LiveWorkoutState.paused; LiveWorkoutState.lifting }
#Preview("Expanded", as: .dynamicIsland(.expanded), using: WorkoutActivityAttributes.preview) {
    FormWorkoutLiveActivity()
} contentStates: { LiveWorkoutState.lifting; LiveWorkoutState.resting; LiveWorkoutState.ready; LiveWorkoutState.walking; LiveWorkoutState.paused }
#Preview("Compact", as: .dynamicIsland(.compact), using: WorkoutActivityAttributes.preview) {
    FormWorkoutLiveActivity()
} contentStates: { LiveWorkoutState.lifting; LiveWorkoutState.resting; LiveWorkoutState.ready; LiveWorkoutState.walking; LiveWorkoutState.paused }
#Preview("Minimal", as: .dynamicIsland(.minimal), using: WorkoutActivityAttributes.preview) {
    FormWorkoutLiveActivity()
} contentStates: { LiveWorkoutState.resting }
#endif

private struct CounterweightActivityArtwork: View {
    let name: String
    var body: some View {
        if ["pause", "arrive", "finished", "pages"].contains(name) {
            GeometryReader { proxy in
                Image("counterweight-session").resizable()
                    .frame(width: proxy.size.width * 3, height: proxy.size.width)
                    .offset(x: -proxy.size.width * (name == "arrive" ? 1 : 2))
            }.aspectRatio(1, contentMode: .fit).clipped()
        } else {
            Image("counterweight-" + name).resizable().scaledToFit()
        }
    }
}
