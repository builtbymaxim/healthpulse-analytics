//
//  WatchMessage.swift
//  HealthPulse (Shared)
//
//  Typed WatchConnectivity message protocol shared between the iOS app and
//  the Watch app. Replaces the fragile dictionary-based protocol used in V1.1.
//  Compiled by both the main app target and HealthPulseWatch Watch App target.
//

import Foundation

// MARK: - Message Envelope

/// All WCSession messages between iPhone and Watch are encoded as Data payloads
/// containing a JSON-encoded WatchMessage. Use encode()/decode() for serialization.
enum WatchMessage: Codable {

    // iPhone -> Watch (real-time via sendMessage)
    case workoutState(WatchWorkoutState)
    case workoutEnded

    // iPhone -> Watch (background via transferUserInfo)
    case readinessUpdate(WatchReadinessData)
    case commitmentsUpdate([WatchCommitment])
    case dailySnapshotUpdate(WatchDailySnapshot)

    // Watch -> iPhone (real-time via sendMessage)
    case hitIt(exerciseIndex: Int, setIndex: Int)
    case requestRefresh

    // MARK: - Serialization

    func encode() -> [String: Any] {
        guard let data = try? JSONEncoder().encode(self),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return dict
    }

    static func decode(from dict: [String: Any]) -> WatchMessage? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
        return try? JSONDecoder().decode(WatchMessage.self, from: data)
    }
}

// MARK: - Payload Types

struct WatchWorkoutState: Codable {
    let exerciseName: String
    /// Index into exerciseLogs — fixes the hardcoded 0 bug in V1.1.
    let exerciseIndex: Int
    let setNumber: Int
    let totalSets: Int
    let isResting: Bool
    let restEndDate: Date?
    let isActive: Bool
}

struct WatchReadinessData: Codable {
    let score: Double
    let recommendedIntensity: String
    let narrative: String
    let topFactor: String
    let updatedAt: Date
}

struct WatchCommitment: Codable, Identifiable {
    var id: String { slot }
    let slot: String
    let title: String
    let subtitle: String
    let icon: String
    let loadModifier: String?
}

struct WatchDailySnapshot: Codable {
    let calories: Double
    let calorieGoal: Double
    let protein: Double
    let proteinGoal: Double
    let carbs: Double
    let carbsGoal: Double
    let fat: Double
    let fatGoal: Double
    let sleepHours: Double?
    let sleepDeep: Double?
    let sleepREM: Double?
    let sleepCore: Double?
    let steps: Int
    let stepGoal: Int
    let restingHR: Double?
    let hrv: Double?
    let hrvTrend: Double?
    let isTrainingDay: Bool
    let workoutName: String?
    let workoutStreak: Int
    let recoveryScore: Double
    let vo2Max: Double?
    let respiratoryRate: Double?
}
