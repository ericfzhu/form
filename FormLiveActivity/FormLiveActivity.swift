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
            PaperLockActivity(state: context.state, isStale: context.isStale, url: sessionURL(context))
                .activityBackgroundTint(.white)
                .activitySystemActionForegroundColor(ActivityInk.ink)
                .widgetURL(sessionURL(context))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 7) {
                        PaperPlateMark().frame(width: 22, height: 22)
                        Text("form.").font(.custom("Gaegu-Regular", size: 20))
                    }
                    .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.phase(at: .now, isStale: context.isStale).title)
                        .font(.caption2).foregroundStyle(ActivityInk.islandQuiet)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    PaperExpandedActivity(state: context.state, isStale: context.isStale, url: sessionURL(context))
                }
            } compactLeading: {
                PaperPlateMark().frame(width: 22, height: 22)
            } compactTrailing: {
                PaperCompactActivity(state: context.state, isStale: context.isStale)
            } minimal: {
                PaperPlateMark().frame(width: 24, height: 24)
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
        case .ready: "Ready when you are"
        case .walking: "Walking"
        case .paused: "Paused"
        }
    }
    var context: String {
        switch self {
        case .lifting: "CURRENT EXERCISE"
        case .resting, .ready: "UP NEXT"
        case .walking: "TREADMILL"
        case .paused: "RETURN TO"
        }
    }
    var timerLabel: String {
        switch self {
        case .lifting: "session elapsed"
        case .resting: "rest remaining"
        case .ready: "rest complete"
        case .walking: "walk elapsed"
        case .paused: "session paused"
        }
    }
}

/// The mark is drawn natively so it stays crisp in the smallest Island region.
private struct PaperPlateMark: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Ellipse().fill(ActivityInk.blue).rotationEffect(.degrees(-8))
                Circle().fill(.black).frame(width: geometry.size.width * 0.32)
                Path { path in
                    path.move(to: CGPoint(x: geometry.size.width * 0.77, y: geometry.size.height * 0.80))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.92, y: geometry.size.height * 0.60))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.86, y: geometry.size.height * 0.89))
                    path.closeSubpath()
                }.fill(Color(red: 0.85, green: 0.90, blue: 0.96))
            }
        }
        .accessibilityLabel("Form workout")
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
                if let start = state.walkTimerStartedAt { Text(start, style: .timer) }
                else { Text("0:00") }
            case .lifting:
                if let start = state.sessionTimerStartedAt { Text(start, style: .timer) }
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

private struct PaperCompactActivity: View {
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

private struct PaperExpandedActivity: View {
    let state: LiveWorkoutState
    let isStale: Bool
    let url: URL
    private var phase: LiveWorkoutState.Phase { state.phase(isStale: isStale) }
    var body: some View {
        VStack(spacing: 15) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(phase.context).font(.system(size: 9)).foregroundStyle(ActivityInk.islandQuiet)
                    Text(state.currentExercise).font(.subheadline).foregroundStyle(.white)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 3) {
                    ActivityTimer(state: state, phase: phase)
                        .font(.system(size: phase == .ready ? 25 : 32, weight: .light))
                        .foregroundStyle(ActivityInk.islandBlue)
                        .frame(width: 94, alignment: .trailing)
                    Text(phase.timerLabel).font(.system(size: 9)).foregroundStyle(ActivityInk.islandQuiet)
                }
            }
            HStack(spacing: 10) {
                ActivityProgress(state: state, dark: true)
                Spacer(minLength: 0)
                Link(destination: url) {
                    Text("Open ↗").font(.caption2)
                        .padding(.horizontal, 13).padding(.vertical, 9)
                        .background(Color.white.opacity(0.13), in: Capsule())
                }.foregroundStyle(.white).accessibilityLabel("Open workout session")
            }
        }
        .padding(.top, 8)
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

private struct PaperLockActivity: View {
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.dynamicTypeSize) private var typeSize
    let state: LiveWorkoutState
    let isStale: Bool
    let url: URL
    private var phase: LiveWorkoutState.Phase { state.phase(isStale: isStale) }
    private var artwork: String {
        switch phase {
        case .resting, .paused: "pause"
        case .walking: "walk"
        default: state.exerciseArtwork ?? "arrive"
        }
    }
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("form.").font(.custom("Gaegu-Regular", size: 23))
                Spacer()
                Text(phase.title).font(.caption2).foregroundStyle(ActivityInk.quiet)
            }
            HStack(spacing: 12) {
                if !typeSize.isAccessibilitySize {
                    Image("activity-\(artwork)").resizable().scaledToFit()
                        .frame(width: 72, height: 64)
                        .opacity(isLuminanceReduced ? 0.7 : 1)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(phase.context).font(.system(size: 9)).foregroundStyle(ActivityInk.quiet)
                    Text(state.currentExercise).font(.subheadline)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 3) {
                    ActivityTimer(state: state, phase: phase)
                        .font(.system(size: phase == .ready ? 22 : 29, weight: .regular))
                        .frame(width: 84, alignment: .trailing)
                    Text(phase.timerLabel).font(.system(size: 9)).foregroundStyle(ActivityInk.quiet)
                }
            }
            Rectangle().fill(ActivityInk.blue.opacity(0.22)).frame(height: 0.5)
            HStack {
                ActivityProgress(state: state)
                Spacer(minLength: 6)
                Link("Open session ↗", destination: url).font(.caption2)
                    .padding(.vertical, 5).accessibilityLabel("Open workout session")
            }
        }
        .foregroundStyle(ActivityInk.ink)
        .padding(.horizontal, 18).padding(.vertical, 15)
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
} contentStates: { LiveWorkoutState.resting; LiveWorkoutState.ready; LiveWorkoutState.walking; LiveWorkoutState.paused }
#Preview("Compact", as: .dynamicIsland(.compact), using: WorkoutActivityAttributes.preview) {
    FormWorkoutLiveActivity()
} contentStates: { LiveWorkoutState.resting; LiveWorkoutState.ready; LiveWorkoutState.walking; LiveWorkoutState.paused }
#Preview("Minimal", as: .dynamicIsland(.minimal), using: WorkoutActivityAttributes.preview) {
    FormWorkoutLiveActivity()
} contentStates: { LiveWorkoutState.resting }
#endif
