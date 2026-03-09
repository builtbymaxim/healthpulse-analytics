//
//  StrengthWorkoutAttributes.swift
//  HealthPulse
//
//  Shared ActivityAttributes for the strength workout Live Activity.
//  Compiled by both the main app and the widget extension.
//

import ActivityKit
import Foundation

struct StrengthWorkoutAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Set to workout startTime — Text(timerDate, style: .timer) auto-counts up
        var timerDate: Date
        var currentExerciseName: String
        var currentSetNumber: Int
        var totalSets: Int
    }

    var workoutName: String
}
