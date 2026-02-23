import ActivityKit
import SwiftUI
import WidgetKit

struct WorkoutLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutLiveActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "dumbbell.fill")
                        .foregroundStyle(.tint)
                    Text(context.state.workoutName)
                        .font(.headline)
                        .lineLimit(1)
                }

                HStack {
                    Text(context.state.exerciseName)
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer()
                    Text(context.attributes.startedAt, style: .timer)
                        .font(.subheadline.monospacedDigit())
                }

                Text(context.state.isResting ? "Rest" : context.state.setLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "dumbbell.fill")
                        .foregroundStyle(.tint)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.exerciseName)
                        .font(.subheadline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.startedAt, style: .timer)
                        .font(.caption.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.isResting ? "Rest" : context.state.setLabel)
                        .font(.caption)
                        .lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill")
            } compactTrailing: {
                Text(context.attributes.startedAt, style: .timer)
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: "dumbbell.fill")
            }
        }
    }
}
