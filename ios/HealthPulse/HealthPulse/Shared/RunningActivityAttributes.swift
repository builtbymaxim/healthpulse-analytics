//
//  RunningActivityAttributes.swift
//  HealthPulse
//
//  Shared ActivityAttributes for the running workout Live Activity.
//  This file is compiled by both the main app and the widget extension.
//

import ActivityKit
import Foundation

struct RunningActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var distanceMeters: Double
        var paceFormatted: String
        var isPaused: Bool
        /// When running: set to (Date.now - elapsedActiveTime) so Text(date, style: .timer) auto-counts
        var timerDate: Date
        /// When paused: frozen elapsed seconds for static display
        var pausedElapsedSeconds: Int
    }
}
