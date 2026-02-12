//
//  SocialModels.swift
//  HealthPulse
//
//  Models for social features: training partners & leaderboards
//

import Foundation
import SwiftUI

// MARK: - Partner

struct Partner: Codable, Identifiable {
    let id: UUID
    let partnerId: UUID
    let partnerName: String?
    let partnerAvatar: String?
    let status: String
    let challengeType: String
    let durationWeeks: Int?
    let startedAt: Date?
    let expiresAt: Date?
    let daysRemaining: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case partnerId = "partner_id"
        case partnerName = "partner_name"
        case partnerAvatar = "partner_avatar"
        case status
        case challengeType = "challenge_type"
        case durationWeeks = "duration_weeks"
        case startedAt = "started_at"
        case expiresAt = "expires_at"
        case daysRemaining = "days_remaining"
    }

    var isPending: Bool { status == "pending" }
    var isActive: Bool { status == "active" }

    var displayName: String {
        partnerName ?? "Training Partner"
    }

    var challenge: ChallengeType {
        ChallengeType(rawValue: challengeType) ?? .general
    }

    var duration: PartnershipDuration {
        PartnershipDuration.from(weeks: durationWeeks)
    }
}

// MARK: - Invite Code

struct InviteCode: Codable, Identifiable {
    var id: String { code }
    let code: String
    let createdAt: Date
    let expiresAt: Date?
    let usesRemaining: Int?

    enum CodingKeys: String, CodingKey {
        case code
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case usesRemaining = "uses_remaining"
    }
}

// MARK: - Use Invite Request

struct UseInviteRequest: Encodable {
    let challengeType: String
    let durationWeeks: Int?

    enum CodingKeys: String, CodingKey {
        case challengeType = "challenge_type"
        case durationWeeks = "duration_weeks"
    }
}

// MARK: - Leaderboard

struct LeaderboardEntry: Codable, Identifiable {
    var id: String { "\(userId)" }
    let rank: Int
    let userId: UUID
    let displayName: String?
    let avatarUrl: String?
    let value: Double
    let isCurrentUser: Bool

    enum CodingKeys: String, CodingKey {
        case rank
        case userId = "user_id"
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case value
        case isCurrentUser = "is_current_user"
    }
}

// MARK: - Challenge Type

enum ChallengeType: String, CaseIterable, Identifiable {
    case general
    case strength
    case consistency
    case weightLoss = "weight_loss"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .general: return "General Fitness"
        case .strength: return "Strength"
        case .consistency: return "Consistency"
        case .weightLoss: return "Weight Loss"
        }
    }

    var icon: String {
        switch self {
        case .general: return "figure.run"
        case .strength: return "dumbbell.fill"
        case .consistency: return "calendar.badge.checkmark"
        case .weightLoss: return "scalemass.fill"
        }
    }

    var color: Color {
        switch self {
        case .general: return .green
        case .strength: return .orange
        case .consistency: return .blue
        case .weightLoss: return .purple
        }
    }

    var description: String {
        switch self {
        case .general: return "All-around fitness tracking and motivation"
        case .strength: return "Compare PRs and push each other to lift heavier"
        case .consistency: return "Stay accountable with workout and nutrition streaks"
        case .weightLoss: return "Support each other on the weight loss journey"
        }
    }
}

// MARK: - Partnership Duration

enum PartnershipDuration: CaseIterable, Identifiable {
    case fourWeeks
    case eightWeeks
    case threeMonths
    case sixMonths
    case ongoing

    var id: String { displayName }

    var weeks: Int? {
        switch self {
        case .fourWeeks: return 4
        case .eightWeeks: return 8
        case .threeMonths: return 12
        case .sixMonths: return 24
        case .ongoing: return nil
        }
    }

    var displayName: String {
        switch self {
        case .fourWeeks: return "4 Weeks"
        case .eightWeeks: return "8 Weeks"
        case .threeMonths: return "3 Months"
        case .sixMonths: return "6 Months"
        case .ongoing: return "Ongoing"
        }
    }

    static func from(weeks: Int?) -> PartnershipDuration {
        guard let weeks = weeks else { return .ongoing }
        switch weeks {
        case 4: return .fourWeeks
        case 8: return .eightWeeks
        case 12: return .threeMonths
        case 24: return .sixMonths
        default: return .ongoing
        }
    }
}

// MARK: - Leaderboard Category

enum LeaderboardCategory: String, CaseIterable, Identifiable {
    case exercisePrs = "exercise_prs"
    case workoutStreaks = "workout_streaks"
    case nutritionConsistency = "nutrition_consistency"
    case trainingConsistency = "training_consistency"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .exercisePrs: return "Exercise PRs"
        case .workoutStreaks: return "Workout Streaks"
        case .nutritionConsistency: return "Nutrition"
        case .trainingConsistency: return "Training"
        }
    }

    var icon: String {
        switch self {
        case .exercisePrs: return "trophy.fill"
        case .workoutStreaks: return "flame.fill"
        case .nutritionConsistency: return "fork.knife"
        case .trainingConsistency: return "calendar.badge.checkmark"
        }
    }

    var color: Color {
        switch self {
        case .exercisePrs: return .yellow
        case .workoutStreaks: return .orange
        case .nutritionConsistency: return .green
        case .trainingConsistency: return .blue
        }
    }

    var unit: String {
        switch self {
        case .exercisePrs: return "kg"
        case .workoutStreaks: return "days"
        case .nutritionConsistency: return "%"
        case .trainingConsistency: return "%"
        }
    }
}
