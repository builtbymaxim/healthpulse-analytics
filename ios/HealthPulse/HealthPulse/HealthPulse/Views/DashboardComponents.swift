//
//  DashboardComponents.swift
//  HealthPulse
//
//  Smart Dashboard UI components for TodayView
//

import SwiftUI

// MARK: - Enhanced Recovery Card

struct EnhancedRecoveryCard: View {
    let recovery: EnhancedRecoveryResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with score
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recovery")
                        .font(.headline)
                    Text(recovery.status.capitalized)
                        .font(.subheadline)
                        .foregroundStyle(recovery.statusColor)
                }

                Spacer()

                // Score ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: recovery.score / 100)
                        .stroke(recovery.statusColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(recovery.score))")
                        .font(.system(size: 18, weight: .bold))
                }
            }

            Divider()

            // Contributing factors
            VStack(spacing: 12) {
                ForEach(recovery.factors) { factor in
                    RecoveryFactorRow(factor: factor)
                }
            }

            // Sleep deficit warning
            if let deficit = recovery.sleepDeficitHours, deficit > 0.5 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Sleep deficit: \(String(format: "%.1f", deficit))h")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }

            // Primary recommendation
            Text(recovery.primaryRecommendation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct RecoveryFactorRow: View {
    let factor: RecoveryFactor

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: factor.icon)
                .font(.system(size: 16))
                .foregroundStyle(factor.impactColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(factor.displayName)
                    .font(.subheadline)
                Text(formattedValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Mini progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(factor.impactColor)
                        .frame(width: geometry.size.width * (factor.score / 100))
                }
            }
            .frame(width: 60, height: 8)
        }
    }

    var formattedValue: String {
        switch factor.name {
        case "sleep_hours":
            return "\(String(format: "%.1f", factor.value))h"
        case "training_load":
            return "\(Int(factor.value)) load"
        case "hrv":
            return "\(Int(factor.value)) ms"
        default:
            return "\(Int(factor.value))"
        }
    }
}

// MARK: - Progress Dashboard Section

struct ProgressDashboardSection: View {
    let progress: ProgressSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Text("Progress")
                    .font(.headline)
                Spacer()
                Text(volumeTrendText)
                    .font(.caption)
                    .foregroundStyle(progress.volumeTrendColor)
            }

            // Key lifts horizontal scroll
            if !progress.keyLifts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(progress.keyLifts) { lift in
                            KeyLiftCard(lift: lift)
                        }
                    }
                }
            }

            // Volume summary
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly Volume")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formattedVolume)
                        .font(.title3.bold())
                }

                Spacer()

                // Recent PRs badge
                if !progress.recentPrs.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(.yellow)
                        Text("\(progress.recentPrs.count) PR\(progress.recentPrs.count == 1 ? "" : "s")")
                            .font(.subheadline.bold())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.yellow.opacity(0.2))
                    .clipShape(Capsule())
                }
            }

            // Muscle balance grid
            if !progress.muscleBalance.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Muscle Recovery")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(progress.muscleBalance.prefix(6)) { muscle in
                            MuscleBalanceChip(muscle: muscle)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    var volumeTrendText: String {
        let pct = progress.volumeTrendPct
        if pct > 0 {
            return "↑ \(Int(pct))% vs last week"
        } else if pct < 0 {
            return "↓ \(Int(abs(pct)))% vs last week"
        }
        return "Same as last week"
    }

    var formattedVolume: String {
        let vol = progress.totalVolumeWeek
        if vol >= 1000 {
            return String(format: "%.1fk kg", vol / 1000)
        }
        return "\(Int(vol)) kg"
    }
}

struct KeyLiftCard: View {
    let lift: LiftProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(shortName)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(Int(lift.currentValue)) kg")
                .font(.headline)

            HStack(spacing: 2) {
                Text("\(lift.changeSymbol)\(String(format: "%.1f", lift.changeValue))")
                    .font(.caption.bold())
                    .foregroundStyle(lift.changeColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    var shortName: String {
        // Shorten common exercise names
        let name = lift.exerciseName
        if name.contains("Bench Press") { return "Bench" }
        if name.contains("Squat") { return "Squat" }
        if name.contains("Deadlift") { return "Deadlift" }
        if name.contains("Overhead") { return "OHP" }
        if name.contains("Row") { return "Row" }
        return String(name.prefix(8))
    }
}

struct MuscleBalanceChip: View {
    let muscle: MuscleBalance

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(muscle.statusColor)
                .frame(width: 6, height: 6)

            Text(muscle.category.capitalized)
                .font(.caption2)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.tertiarySystemBackground))
        .clipShape(Capsule())
    }
}

// MARK: - Smart Recommendations Section

struct SmartRecommendationsSection: View {
    let recommendations: [SmartRecommendation]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("For You")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recommendations) { rec in
                        RecommendationCard(recommendation: rec)
                    }
                }
            }
        }
    }
}

struct RecommendationCard: View {
    let recommendation: SmartRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: recommendation.categoryIcon)
                    .font(.caption)
                    .foregroundStyle(recommendation.categoryColor)

                Text(recommendation.category.capitalized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(recommendation.title)
                .font(.subheadline.bold())
                .lineLimit(1)

            Text(recommendation.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 180, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Weekly Summary Card

struct WeeklySummaryCard: View {
    let summary: WeeklySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This Week")
                .font(.headline)

            // 2x2 Grid of stats
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                WeeklyStatItem(
                    icon: "dumbbell.fill",
                    value: "\(summary.workoutsCompleted)/\(summary.workoutsPlanned)",
                    label: "Workouts",
                    color: workoutCompletionColor
                )

                WeeklyStatItem(
                    icon: "bed.double.fill",
                    value: "\(Int(summary.avgSleepScore))",
                    label: "Sleep Score",
                    color: sleepScoreColor
                )

                WeeklyStatItem(
                    icon: "fork.knife",
                    value: "\(Int(summary.nutritionAdherencePct))%",
                    label: "Nutrition",
                    color: nutritionColor
                )

                if let bestDay = summary.bestDay {
                    WeeklyStatItem(
                        icon: "star.fill",
                        value: bestDay,
                        label: "Best Day",
                        color: .yellow
                    )
                } else {
                    WeeklyStatItem(
                        icon: "calendar",
                        value: "-",
                        label: "Best Day",
                        color: .gray
                    )
                }
            }

            // Highlights
            if !summary.highlights.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(summary.highlights, id: \.self) { highlight in
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                            Text(highlight)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    var workoutCompletionColor: Color {
        guard summary.workoutsPlanned > 0 else { return .gray }
        let pct = Double(summary.workoutsCompleted) / Double(summary.workoutsPlanned)
        if pct >= 1 { return .green }
        if pct >= 0.5 { return .orange }
        return .red
    }

    var sleepScoreColor: Color {
        if summary.avgSleepScore >= 80 { return .green }
        if summary.avgSleepScore >= 60 { return .orange }
        return .red
    }

    var nutritionColor: Color {
        if summary.nutritionAdherencePct >= 80 { return .green }
        if summary.nutritionAdherencePct >= 50 { return .orange }
        return .red
    }
}

struct WeeklyStatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(value)
                    .font(.headline)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Previews

#Preview("Enhanced Recovery Card") {
    EnhancedRecoveryCard(recovery: EnhancedRecoveryResponse(
        score: 72,
        status: "moderate",
        factors: [
            RecoveryFactor(name: "sleep_hours", value: 6.5, score: 65, impact: "negative", recommendation: "Aim for 7-9 hours"),
            RecoveryFactor(name: "training_load", value: 320, score: 85, impact: "positive", recommendation: nil),
            RecoveryFactor(name: "hrv", value: 45, score: 70, impact: "neutral", recommendation: nil)
        ],
        primaryRecommendation: "Prioritize sleep tonight - aim for 8+ hours.",
        sleepDeficitHours: 1.5,
        estimatedFullRecoveryHours: 12
    ))
    .padding()
}

#Preview("Weekly Summary Card") {
    WeeklySummaryCard(summary: WeeklySummary(
        workoutsCompleted: 3,
        workoutsPlanned: 4,
        avgSleepScore: 75,
        nutritionAdherencePct: 85,
        bestDay: "Tuesday",
        highlights: ["Completed 3 workouts!", "Great sleep quality"]
    ))
    .padding()
}
