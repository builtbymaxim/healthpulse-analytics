//
//  RunningActivityLiveActivity.swift
//  RunningActivityWidget
//
//  Live Activity views for the lock screen and Dynamic Island during runs.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct RunningActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RunningActivityAttributes.self) { context in
            // Lock Screen / StandBy view
            lockScreenView(context: context)
                .activityBackgroundTint(.black)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(formatDistance(context.state.distanceMeters))
                    } icon: {
                        Image(systemName: "figure.run")
                    }
                    .font(.headline)
                    .foregroundStyle(.green)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Label {
                        Text("\(context.state.paceFormatted) /km")
                    } icon: {
                        Image(systemName: "speedometer")
                    }
                    .font(.headline)
                    .foregroundStyle(.orange)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    timerView(context: context)
                        .font(.system(.title, design: .rounded).monospacedDigit().bold())
                        .frame(maxWidth: .infinity)
                }
            } compactLeading: {
                Image(systemName: "figure.run")
                    .foregroundStyle(.green)
            } compactTrailing: {
                timerView(context: context)
                    .font(.system(.caption, design: .rounded).monospacedDigit())
            } minimal: {
                Image(systemName: "figure.run")
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<RunningActivityAttributes>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.run")
                        .foregroundStyle(.green)

                    Text(context.state.isPaused ? "Paused" : "Running")
                        .font(.headline)
                        .foregroundStyle(.white)
                }

                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DIST")
                            .font(.caption2)
                            .foregroundStyle(.gray)

                        Text(formatDistance(context.state.distanceMeters))
                            .font(.system(.title3, design: .rounded).bold().monospacedDigit())
                            .foregroundStyle(.green)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("PACE")
                            .font(.caption2)
                            .foregroundStyle(.gray)

                        Text("\(context.state.paceFormatted) /km")
                            .font(.system(.title3, design: .rounded).bold().monospacedDigit())
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            VStack(spacing: 2) {
                Text("TIME")
                    .font(.caption2)
                    .foregroundStyle(.gray)

                timerView(context: context)
                    .font(.system(.title2, design: .rounded).bold().monospacedDigit())
                    .foregroundStyle(.white)
            }
        }
        .padding()
    }

    // MARK: - Timer View

    @ViewBuilder
    private func timerView(context: ActivityViewContext<RunningActivityAttributes>) -> some View {
        if context.state.isPaused {
            Text(formatTime(context.state.pausedElapsedSeconds))
        } else {
            Text(context.state.timerDate, style: .timer)
        }
    }

    // MARK: - Formatting Helpers

    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters)) m"
        }
        return String(format: "%.2f km", meters / 1000)
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
