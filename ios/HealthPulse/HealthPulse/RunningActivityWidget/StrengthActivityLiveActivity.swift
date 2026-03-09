//
//  StrengthActivityLiveActivity.swift
//  RunningActivityWidget
//
//  Live Activity views for the lock screen and Dynamic Island during strength workouts.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct StrengthActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StrengthWorkoutAttributes.self) { context in
            lockScreenView(context: context)
                .activityBackgroundTint(.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.attributes.workoutName)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "dumbbell.fill")
                    }
                    .font(.headline)
                    .foregroundStyle(.green)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Label {
                        Text("Set \(context.state.currentSetNumber)/\(context.state.totalSets)")
                    } icon: {
                        Image(systemName: "number")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        Text(context.state.currentExerciseName)
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                            .lineLimit(1)

                        Text(context.state.timerDate, style: .timer)
                            .font(.system(.title, design: .rounded).monospacedDigit().bold())
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(.green)
            } compactTrailing: {
                Text(context.state.timerDate, style: .timer)
                    .font(.system(.caption, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<StrengthWorkoutAttributes>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "dumbbell.fill")
                        .foregroundStyle(.green)

                    Text(context.attributes.workoutName)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("NOW")
                        .font(.caption2)
                        .foregroundStyle(.gray)

                    Text(context.state.currentExerciseName)
                        .font(.system(.body, design: .rounded).bold())
                        .foregroundStyle(.green)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(spacing: 4) {
                VStack(spacing: 2) {
                    Text("TIME")
                        .font(.caption2)
                        .foregroundStyle(.gray)

                    Text(context.state.timerDate, style: .timer)
                        .font(.system(.title2, design: .rounded).bold().monospacedDigit())
                        .foregroundStyle(.white)
                }

                Text("Set \(context.state.currentSetNumber)/\(context.state.totalSets)")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
        .padding()
    }
}
