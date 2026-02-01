//
//  SleepModels.swift
//  HealthPulse
//
//  Models for sleep tracking
//

import Foundation
import SwiftUI

// MARK: - Sleep Entry

struct SleepEntry: Codable, Identifiable {
    var id: String { date }
    let date: String
    let durationHours: Double
    var quality: Double?
    var deepSleepHours: Double?
    var remSleepHours: Double?
    var lightSleepHours: Double?
    var awakeTimeMinutes: Double?
    var sleepScore: Double?

    enum CodingKeys: String, CodingKey {
        case date
        case durationHours = "duration_hours"
        case quality
        case deepSleepHours = "deep_sleep_hours"
        case remSleepHours = "rem_sleep_hours"
        case lightSleepHours = "light_sleep_hours"
        case awakeTimeMinutes = "awake_time_minutes"
        case sleepScore = "sleep_score"
    }

    var formattedDuration: String {
        let hours = Int(durationHours)
        let minutes = Int((durationHours - Double(hours)) * 60)
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Sleep Summary

struct SleepSummary: Codable {
    let date: String
    let durationHours: Double
    let quality: Double
    let deepSleepHours: Double
    let remSleepHours: Double
    let lightSleepHours: Double
    let sleepScore: Double
    let targetHours: Double
    let durationVsTargetPct: Double
    let qualityTrend: String

    enum CodingKeys: String, CodingKey {
        case date
        case durationHours = "duration_hours"
        case quality
        case deepSleepHours = "deep_sleep_hours"
        case remSleepHours = "rem_sleep_hours"
        case lightSleepHours = "light_sleep_hours"
        case sleepScore = "sleep_score"
        case targetHours = "target_hours"
        case durationVsTargetPct = "duration_vs_target_pct"
        case qualityTrend = "quality_trend"
    }

    var formattedDuration: String {
        let hours = Int(durationHours)
        let minutes = Int((durationHours - Double(hours)) * 60)
        return "\(hours)h \(minutes)m"
    }

    var scoreColor: Color {
        if sleepScore >= 80 { return .green }
        if sleepScore >= 60 { return .orange }
        return .red
    }

    var trendIcon: String {
        switch qualityTrend {
        case "up": return "arrow.up.right"
        case "down": return "arrow.down.right"
        default: return "arrow.right"
        }
    }

    var trendColor: Color {
        switch qualityTrend {
        case "up": return .green
        case "down": return .red
        default: return .secondary
        }
    }
}

// MARK: - Sleep Analytics

struct SleepAnalytics: Codable {
    let periodDays: Int
    let avgDurationHours: Double
    let avgQuality: Double
    let avgDeepSleepHours: Double
    let avgRemSleepHours: Double
    let avgSleepScore: Double
    let totalSleepDebtHours: Double
    var bestNight: SleepEntry?
    var worstNight: SleepEntry?
    let consistencyScore: Double
    let trend: String

    enum CodingKeys: String, CodingKey {
        case periodDays = "period_days"
        case avgDurationHours = "avg_duration_hours"
        case avgQuality = "avg_quality"
        case avgDeepSleepHours = "avg_deep_sleep_hours"
        case avgRemSleepHours = "avg_rem_sleep_hours"
        case avgSleepScore = "avg_sleep_score"
        case totalSleepDebtHours = "total_sleep_debt_hours"
        case bestNight = "best_night"
        case worstNight = "worst_night"
        case consistencyScore = "consistency_score"
        case trend
    }

    var formattedAvgDuration: String {
        let hours = Int(avgDurationHours)
        let minutes = Int((avgDurationHours - Double(hours)) * 60)
        return "\(hours)h \(minutes)m"
    }

    var trendDescription: String {
        switch trend {
        case "improving": return "Sleep is improving"
        case "declining": return "Sleep needs attention"
        default: return "Sleep is stable"
        }
    }

    var trendColor: Color {
        switch trend {
        case "improving": return .green
        case "declining": return .red
        default: return .secondary
        }
    }
}

// MARK: - Sleep Log Request

struct SleepLogRequest: Codable {
    let durationHours: Double
    var quality: Double?
    var deepSleepHours: Double?
    var remSleepHours: Double?
    var bedTime: Date?
    var wakeTime: Date?
    var loggedFor: String?

    enum CodingKeys: String, CodingKey {
        case durationHours = "duration_hours"
        case quality
        case deepSleepHours = "deep_sleep_hours"
        case remSleepHours = "rem_sleep_hours"
        case bedTime = "bed_time"
        case wakeTime = "wake_time"
        case loggedFor = "logged_for"
    }

    /// Initialize with all parameters
    init(
        durationHours: Double,
        quality: Double? = nil,
        bedTime: Date? = nil,
        wakeTime: Date? = nil,
        deepSleepMinutes: Int? = nil,
        remSleepMinutes: Int? = nil,
        loggedFor: String? = nil
    ) {
        self.durationHours = durationHours
        self.quality = quality
        self.bedTime = bedTime
        self.wakeTime = wakeTime
        self.deepSleepHours = deepSleepMinutes.map { Double($0) / 60.0 }
        self.remSleepHours = remSleepMinutes.map { Double($0) / 60.0 }
        self.loggedFor = loggedFor
    }
}

// MARK: - Sleep Stage

enum SleepStage: String, CaseIterable {
    case deep
    case rem
    case light
    case awake

    var displayName: String {
        switch self {
        case .deep: return "Deep"
        case .rem: return "REM"
        case .light: return "Light"
        case .awake: return "Awake"
        }
    }

    var icon: String {
        switch self {
        case .deep: return "moon.zzz.fill"
        case .rem: return "brain.head.profile"
        case .light: return "moon.fill"
        case .awake: return "sun.max.fill"
        }
    }

    var color: Color {
        switch self {
        case .deep: return .indigo
        case .rem: return .purple
        case .light: return .blue
        case .awake: return .orange
        }
    }
}
