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
                .activityBackgroundTint(Color(red: 0.955, green: 0.938, blue: 0.89))
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
                                .font(.caption2.weight(.semibold))
                                .tracking(1.2)
                                .foregroundStyle(.secondary)
                            Text(context.state.currentExercise)
                                .font(.subheadline.weight(.semibold))
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
        HStack(spacing: 14) {
            activityMark
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.routineName.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(1.4)
                    .foregroundStyle(softInk)
                Text(context.state.currentExercise)
                    .font(.system(.headline, design: .serif, weight: .semibold))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                progressText(context.state)
                    .foregroundStyle(softInk)
            }

            Spacer(minLength: 12)
            timerOrElapsed(context)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func timerOrElapsed(
        _ context: ActivityViewContext<WorkoutActivityAttributes>
    ) -> some View {
        if let restEnd = context.state.restEnd, restEnd > Date() {
            VStack(alignment: .trailing, spacing: 2) {
                Text("REST")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(cinnabar)
                Text(timerInterval: Date()...restEnd, countsDown: true)
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(ink)
            }
        } else {
            VStack(alignment: .trailing, spacing: 2) {
                Text("SESSION")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.2)
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
            .font(.caption.monospacedDigit())
    }

    private var activityMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(cinnabar)
                .frame(width: 22, height: 22)
            Circle()
                .fill(Color(red: 0.955, green: 0.938, blue: 0.89))
                .frame(width: 6, height: 6)
        }
        .accessibilityHidden(true)
    }

    private var ink: Color { Color(red: 0.08, green: 0.075, blue: 0.065) }
    private var softInk: Color { Color(red: 0.34, green: 0.32, blue: 0.28) }
    private var cinnabar: Color { Color(red: 0.56, green: 0.12, blue: 0.09) }
}
