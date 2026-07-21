import ActivityKit
import SwiftUI
import WidgetKit

@main
struct FormLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        FormWorkoutLiveActivity()
    }
}

struct FormWorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            lockScreenView(context)
                .activityBackgroundTint(paper)
                .activitySystemActionForegroundColor(ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    activityMark
                }
                DynamicIslandExpandedRegion(.trailing) {
                    progressText(context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(context.attributes.routineName.uppercased())
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(1)
                                .foregroundStyle(.secondary)
                            Text(context.state.currentExercise)
                                .font(.subheadline.weight(.black))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 12)
                        timerOrElapsed(context)
                    }
                }
            } compactLeading: {
                activityMark
            } compactTrailing: {
                compactTimerOrProgress(context)
            } minimal: {
                activityMark
            }
            .keylineTint(cinnabar)
        }
    }

    private func lockScreenView(
        _ context: ActivityViewContext<WorkoutActivityAttributes>
    ) -> some View {
        HStack(spacing: 0) {
            activityMark
                .frame(width: 50, height: 68)
                .background(cinnabar)

            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.routineName.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(softInk)
                Text(context.state.currentExercise)
                    .font(.system(.headline, design: .default, weight: .black))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                progressText(context.state)
                    .foregroundStyle(softInk)
            }
            .padding(.leading, 12)

            Spacer(minLength: 12)
            timerOrElapsed(context)
        }
        .padding(.trailing, 16)
        .overlay(alignment: .bottom) {
            Rectangle().fill(ink).frame(height: 1)
        }
    }

    @ViewBuilder
    private func timerOrElapsed(
        _ context: ActivityViewContext<WorkoutActivityAttributes>
    ) -> some View {
        if let restEnd = context.state.restEnd, restEnd > Date() {
            VStack(alignment: .trailing, spacing: 2) {
                Text("REST")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(cinnabar)
                Text(timerInterval: Date()...restEnd, countsDown: true)
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(ink)
            }
        } else {
            VStack(alignment: .trailing, spacing: 2) {
                Text("SESSION")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(softInk)
                Text(context.attributes.startedAt, style: .timer)
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(ink)
            }
        }
    }

    @ViewBuilder
    private func compactTimerOrProgress(
        _ context: ActivityViewContext<WorkoutActivityAttributes>
    ) -> some View {
        if let restEnd = context.state.restEnd, restEnd > Date() {
            Text(timerInterval: Date()...restEnd, countsDown: true)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(cinnabar)
                .frame(width: 44)
        } else {
            Text("\(context.state.completedMovements)/\(context.state.totalMovements)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white)
        }
    }

    private func progressText(
        _ state: WorkoutActivityAttributes.ContentState
    ) -> some View {
        Text("\(state.completedMovements) of \(state.totalMovements) movements")
            .font(.system(.caption, design: .monospaced))
    }

    private var activityMark: some View {
        ZStack {
            Rectangle().fill(cinnabar)
            Text("F")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(acid)
        }
        .frame(width: 22, height: 22)
        .accessibilityHidden(true)
    }

    private var ink: Color { Color(red: 0.067, green: 0.067, blue: 0.059) }
    private var softInk: Color { Color(red: 0.29, green: 0.28, blue: 0.25) }
    private var paper: Color { Color(red: 0.914, green: 0.886, blue: 0.835) }
    private var cinnabar: Color { Color(red: 0.835, green: 0.169, blue: 0.118) }
    private var acid: Color { Color(red: 0.91, green: 1.0, blue: 0.21) }
}
