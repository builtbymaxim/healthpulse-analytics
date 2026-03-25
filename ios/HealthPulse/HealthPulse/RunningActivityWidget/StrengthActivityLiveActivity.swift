//
//  StrengthActivityLiveActivity.swift
//  RunningActivityWidget
//
//  Live Activity views for the lock screen and Dynamic Island during strength workouts.
//  Shows active set info (exercise name, set progress) or rest countdown when resting.
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
                    if context.state.isResting {
                        Label {
                            Text("REST")
                                .foregroundStyle(.orange)
                        } icon: {
                            Image(systemName: "timer")
                                .foregroundStyle(.orange)
                        }
                        .font(.headline)
                    } else {
                        Label {
                            Text("Set \(context.state.currentSetNumber)/\(context.state.totalSets)")
                        } icon: {
                            Image(systemName: "number")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.isResting, let end = context.state.restEndDate {
                        VStack(spacing: 4) {
                            Text("RESTING")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            Text(end, style: .timer)
                                .font(.system(.title, design: .rounded).monospacedDigit().bold())
                                .foregroundStyle(.orange)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
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
                }
            } compactLeading: {
                Image(systemName: context.state.isResting ? "timer" : "dumbbell.fill")
                    .foregroundStyle(context.state.isResting ? .orange : .green)
            } compactTrailing: {
                if context.state.isResting, let end = context.state.restEndDate {
                    Text(end, style: .timer)
                        .font(.system(.caption, design: .rounded).monospacedDigit())
                        .foregroundStyle(.orange)
                } else {
                    Text(context.state.timerDate, style: .timer)
                        .font(.system(.caption, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                }
            } minimal: {
                Image(systemName: context.state.isResting ? "timer" : "dumbbell.fill")
                    .foregroundStyle(context.state.isResting ? .orange : .green)
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

                if context.state.isResting {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("RESTING")
                            .font(.caption2)
                            .foregroundStyle(.orange)

                        Text("Next: \(context.state.currentExerciseName)")
                            .font(.system(.body, design: .rounded).bold())
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                    }
                } else {
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
            }

            Spacer()

            VStack(spacing: 4) {
                if context.state.isResting, let end = context.state.restEndDate {
                    VStack(spacing: 2) {
                        Text("REST")
                            .font(.caption2)
                            .foregroundStyle(.orange)

                        Text(end, style: .timer)
                            .font(.system(.title2, design: .rounded).bold().monospacedDigit())
                            .foregroundStyle(.orange)
                    }
                } else {
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
        }
        .padding()
    }
}
