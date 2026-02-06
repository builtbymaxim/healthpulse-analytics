//
//  ActiveWorkoutManager.swift
//  HealthPulse
//
//  Persists active workout state to UserDefaults so running workouts
//  survive backgrounding and (as a safety net) app termination.
//

import Foundation

class ActiveWorkoutManager {
    static let shared = ActiveWorkoutManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let isActive = "activeWorkout.isActive"
        static let runStartDate = "activeWorkout.runStartDate"
        static let totalPausedInterval = "activeWorkout.totalPausedInterval"
        static let pauseStartDate = "activeWorkout.pauseStartDate"
        static let totalDistance = "activeWorkout.totalDistance"
        static let isPaused = "activeWorkout.isPaused"
    }

    // MARK: - Read State

    var isWorkoutActive: Bool {
        defaults.bool(forKey: Keys.isActive)
    }

    var runStartDate: Date? {
        defaults.object(forKey: Keys.runStartDate) as? Date
    }

    var totalPausedInterval: TimeInterval {
        defaults.double(forKey: Keys.totalPausedInterval)
    }

    var pauseStartDate: Date? {
        defaults.object(forKey: Keys.pauseStartDate) as? Date
    }

    var totalDistance: Double {
        defaults.double(forKey: Keys.totalDistance)
    }

    var isPaused: Bool {
        defaults.bool(forKey: Keys.isPaused)
    }

    // MARK: - Actions

    func startWorkout(startDate: Date) {
        defaults.set(true, forKey: Keys.isActive)
        defaults.set(startDate, forKey: Keys.runStartDate)
        defaults.set(0.0, forKey: Keys.totalPausedInterval)
        defaults.removeObject(forKey: Keys.pauseStartDate)
        defaults.set(0.0, forKey: Keys.totalDistance)
        defaults.set(false, forKey: Keys.isPaused)
    }

    func saveState(
        totalPausedInterval: TimeInterval,
        pauseStartDate: Date?,
        totalDistance: Double,
        isPaused: Bool
    ) {
        defaults.set(totalPausedInterval, forKey: Keys.totalPausedInterval)
        if let pauseStart = pauseStartDate {
            defaults.set(pauseStart, forKey: Keys.pauseStartDate)
        } else {
            defaults.removeObject(forKey: Keys.pauseStartDate)
        }
        defaults.set(totalDistance, forKey: Keys.totalDistance)
        defaults.set(isPaused, forKey: Keys.isPaused)
    }

    func clearWorkout() {
        for key in [Keys.isActive, Keys.runStartDate, Keys.totalPausedInterval,
                    Keys.pauseStartDate, Keys.totalDistance, Keys.isPaused] {
            defaults.removeObject(forKey: key)
        }
    }
}
