//
//  ExerciseModels.swift
//  HealthPulse
//
//  Models for exercise library and strength tracking
//

import Foundation
import SwiftUI

// MARK: - Exercise Library

struct Exercise: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let category: ExerciseCategory
    let muscleGroups: [String]
    var equipment: EquipmentType?
    var isCompound: Bool
    var instructions: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, category
        case muscleGroups = "muscle_groups"
        case equipment
        case isCompound = "is_compound"
        case instructions
        case createdAt = "created_at"
    }
}

enum ExerciseCategory: String, Codable, CaseIterable {
    case chest, back, shoulders, arms, legs, core, cardio, other

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .chest: return "figure.strengthtraining.traditional"
        case .back: return "figure.cross.training"
        case .shoulders: return "figure.arms.open"
        case .arms: return "figure.strengthtraining.functional"
        case .legs: return "figure.run"
        case .core: return "figure.core.training"
        case .cardio: return "heart.fill"
        case .other: return "figure.mixed.cardio"
        }
    }

    var color: Color {
        switch self {
        case .chest: return .red
        case .back: return .blue
        case .shoulders: return .orange
        case .arms: return .purple
        case .legs: return .green
        case .core: return .yellow
        case .cardio: return .pink
        case .other: return .gray
        }
    }
}

enum EquipmentType: String, Codable, CaseIterable {
    case barbell, dumbbell, cable, machine, bodyweight, kettlebell, bands, other

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .barbell: return "dumbbell.fill"
        case .dumbbell: return "dumbbell"
        case .cable: return "cable.coaxial"
        case .machine: return "gearshape.fill"
        case .bodyweight: return "figure.stand"
        case .kettlebell: return "scalemass.fill"
        case .bands: return "circle.dotted"
        case .other: return "questionmark.circle"
        }
    }
}

// MARK: - Workout Sets

struct WorkoutSet: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    var workoutId: UUID?
    let exerciseId: UUID
    let setNumber: Int
    let weightKg: Double
    let reps: Int
    var rpe: Double?
    var isWarmup: Bool
    var isPR: Bool
    var notes: String?
    let performedAt: Date
    let createdAt: Date

    // Joined exercise info
    var exerciseName: String?
    var exerciseCategory: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case workoutId = "workout_id"
        case exerciseId = "exercise_id"
        case setNumber = "set_number"
        case weightKg = "weight_kg"
        case reps, rpe
        case isWarmup = "is_warmup"
        case isPR = "is_pr"
        case notes
        case performedAt = "performed_at"
        case createdAt = "created_at"
        case exerciseName = "exercise_name"
        case exerciseCategory = "exercise_category"
    }

    var volume: Double {
        weightKg * Double(reps)
    }

    var formattedWeight: String {
        String(format: "%.1f kg", weightKg)
    }
}

struct WorkoutSetCreate: Codable {
    let exerciseId: UUID
    let setNumber: Int
    let weightKg: Double
    let reps: Int
    var rpe: Double?
    var isWarmup: Bool = false
    var notes: String?
    var performedAt: Date?

    enum CodingKeys: String, CodingKey {
        case exerciseId = "exercise_id"
        case setNumber = "set_number"
        case weightKg = "weight_kg"
        case reps, rpe
        case isWarmup = "is_warmup"
        case notes
        case performedAt = "performed_at"
    }
}

struct WorkoutSetsRequest: Codable {
    var workoutId: UUID?
    let sets: [WorkoutSetCreate]

    enum CodingKeys: String, CodingKey {
        case workoutId = "workout_id"
        case sets
    }
}

// MARK: - Personal Records

enum PRType: String, Codable, CaseIterable {
    case oneRM = "1rm"
    case threeRM = "3rm"
    case fiveRM = "5rm"
    case tenRM = "10rm"
    case maxReps = "max_reps"
    case maxVolume = "max_volume"

    var displayName: String {
        switch self {
        case .oneRM: return "1RM"
        case .threeRM: return "3RM"
        case .fiveRM: return "5RM"
        case .tenRM: return "10RM"
        case .maxReps: return "Max Reps"
        case .maxVolume: return "Max Volume"
        }
    }
}

struct PersonalRecord: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let exerciseId: UUID
    let recordType: String
    let value: Double
    var previousValue: Double?
    let achievedAt: Date
    let createdAt: Date

    // Joined exercise info
    var exerciseName: String?
    var exerciseCategory: String?

    // Calculated
    var improvementPct: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case exerciseId = "exercise_id"
        case recordType = "record_type"
        case value
        case previousValue = "previous_value"
        case achievedAt = "achieved_at"
        case createdAt = "created_at"
        case exerciseName = "exercise_name"
        case exerciseCategory = "exercise_category"
        case improvementPct = "improvement_pct"
    }

    var formattedValue: String {
        if recordType == "max_reps" {
            return "\(Int(value)) reps"
        } else if recordType == "max_volume" {
            return String(format: "%.0f kg", value)
        } else {
            return String(format: "%.1f kg", value)
        }
    }
}

// MARK: - Exercise History

struct ExerciseHistory: Codable {
    let exerciseId: UUID
    let exerciseName: String
    let sets: [WorkoutSet]
    let personalRecords: [PersonalRecord]
    var estimated1RM: Double?
    let totalVolume30d: Double
    let sessionCount30d: Int

    enum CodingKeys: String, CodingKey {
        case exerciseId = "exercise_id"
        case exerciseName = "exercise_name"
        case sets
        case personalRecords = "personal_records"
        case estimated1RM = "estimated_1rm"
        case totalVolume30d = "total_volume_30d"
        case sessionCount30d = "session_count_30d"
    }
}

// MARK: - Analytics

struct VolumeAnalytics: Codable {
    let period: String
    let totalVolume: Double
    let volumeByCategory: [String: Double]
    let volumeByExercise: [String: Double]
    let trendPct: Double

    enum CodingKeys: String, CodingKey {
        case period
        case totalVolume = "total_volume"
        case volumeByCategory = "volume_by_category"
        case volumeByExercise = "volume_by_exercise"
        case trendPct = "trend_pct"
    }

    var formattedVolume: String {
        if totalVolume >= 1000 {
            return String(format: "%.1fk kg", totalVolume / 1000)
        }
        return String(format: "%.0f kg", totalVolume)
    }

    var trendDirection: String {
        if trendPct > 5 { return "up" }
        if trendPct < -5 { return "down" }
        return "stable"
    }
}

struct FrequencyAnalytics: Codable {
    let period: String
    let totalSessions: Int
    let sessionsByCategory: [String: Int]
    let sessionsByDay: [String: Int]
    let avgSetsPerSession: Double

    enum CodingKeys: String, CodingKey {
        case period
        case totalSessions = "total_sessions"
        case sessionsByCategory = "sessions_by_category"
        case sessionsByDay = "sessions_by_day"
        case avgSetsPerSession = "avg_sets_per_session"
    }
}

struct MuscleGroupStats: Codable {
    let category: String
    let totalVolume7d: Double
    let totalSets7d: Int
    var lastTrained: Date?
    var daysSinceTrained: Int?

    enum CodingKeys: String, CodingKey {
        case category
        case totalVolume7d = "total_volume_7d"
        case totalSets7d = "total_sets_7d"
        case lastTrained = "last_trained"
        case daysSinceTrained = "days_since_trained"
    }

    var recoveryStatus: String {
        guard let days = daysSinceTrained else { return "unknown" }
        if days <= 1 { return "recovering" }
        if days <= 3 { return "ready" }
        return "rested"
    }

    var recoveryColor: Color {
        switch recoveryStatus {
        case "recovering": return .orange
        case "ready": return .green
        case "rested": return .blue
        default: return .gray
        }
    }
}

// MARK: - Set Input State (for UI)

struct SetInputState: Identifiable {
    let id = UUID()
    var exerciseId: UUID?
    var exercise: Exercise?
    var weight: String = ""
    var reps: String = ""
    var rpe: Double?
    var isWarmup: Bool = false
    var notes: String = ""

    var isValid: Bool {
        exerciseId != nil && !weight.isEmpty && !reps.isEmpty &&
        Double(weight) != nil && Int(reps) != nil
    }

    func toCreate(setNumber: Int) -> WorkoutSetCreate? {
        guard let exerciseId = exerciseId,
              let weightKg = Double(weight),
              let reps = Int(reps) else {
            return nil
        }

        return WorkoutSetCreate(
            exerciseId: exerciseId,
            setNumber: setNumber,
            weightKg: weightKg,
            reps: reps,
            rpe: rpe,
            isWarmup: isWarmup,
            notes: notes.isEmpty ? nil : notes
        )
    }
}
