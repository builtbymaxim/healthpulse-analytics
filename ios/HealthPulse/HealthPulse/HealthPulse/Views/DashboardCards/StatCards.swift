//
//  StatCards.swift
//  HealthPulse
//
//  Small dashboard stat cards: social rank, last workout, sleep, quick stats, compact scores.
//

import SwiftUI

// MARK: - Social Rank Card

struct SocialRankCard: View {
    let rank: Int
    let streakValue: Int
    let activePartners: Int

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.15))
                    .frame(width: 56, height: 56)

                Text("#\(rank)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Social")
                    .font(.headline)

                HStack(spacing: 8) {
                    Label("\(streakValue)d streak", systemImage: "flame.fill")
                    if activePartners > 0 {
                        Label("\(activePartners) partner\(activePartners == 1 ? "" : "s")", systemImage: "person.2.fill")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .cardShadow()
    }
}

// MARK: - Social Prompt Card (no leaderboard rank yet)

struct SocialPromptCard: View {
    let activePartners: Int

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: "person.2.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.primary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Social")
                    .font(.headline)
                Group {
                    if activePartners > 0 {
                        Label("\(activePartners) partner\(activePartners == 1 ? "" : "s") active", systemImage: "person.2.fill")
                    } else {
                        Text("View leaderboard")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .cardShadow()
    }
}

// MARK: - Last Workout Card

struct LastWorkoutCard: View {
    let workout: WorkoutSummary
    let improvement: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeaderLabel(text: "Last Workout")
                Spacer()
                Text(workout.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                // Workout icon
                Image(systemName: workout.icon)
                    .font(.title)
                    .foregroundStyle(AppTheme.primary)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.primary.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.subheadline.bold())

                    HStack(spacing: 12) {
                        Label("\(workout.duration) min", systemImage: "clock")
                        if let calories = workout.calories {
                            Label("\(Int(calories)) kcal", systemImage: "flame")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // Improvement badge
                if let improvement = improvement {
                    Text(improvement)
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.primary.opacity(0.15))
                        .foregroundStyle(AppTheme.primary)
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .cardShadow()
    }
}

// MARK: - Quick Stat Card

struct QuickStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.headline)
                .contentTransition(.numericText())

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .cardShadow()
    }
}

// MARK: - Compact Score Card

struct CompactScoreCard: View {
    let title: String
    let score: Double
    let status: String?
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            // Mini ring
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 4)

                Circle()
                    .trim(from: 0, to: score / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(Int(score))")
                    .font(.system(size: 14, weight: .bold))
                    .contentTransition(.numericText())
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let status = status {
                    Text(status.capitalized)
                        .font(.subheadline.bold())
                }
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .cardShadow()
    }
}

// MARK: - Sleep Pattern Card

struct SleepPatternCard: View {
    let avgHours: Double
    let consistencyScore: Int
    let trend: TrendDirection

    var body: some View {
        HStack(spacing: 16) {
            // Sleep icon with background
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: "moon.zzz.fill")
                    .font(.title2)
                    .foregroundStyle(.purple)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "%.1fh avg sleep", avgHours))
                    .font(.headline)

                HStack(spacing: 4) {
                    Image(systemName: trend.icon)
                        .font(.caption)
                    Text("\(consistencyScore)% consistent")
                        .font(.caption)
                        .contentTransition(.numericText())
                }
                .foregroundStyle(trend.color)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .cardShadow()
    }
}

// MARK: - Supporting Types

enum TrendDirection {
    case up, down, stable

    var icon: String {
        switch self {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }

    var color: Color {
        switch self {
        case .up: return .green
        case .down: return .red
        case .stable: return .secondary
        }
    }
}

struct WorkoutSummary {
    let name: String
    let icon: String
    let date: Date
    let duration: Int
    let calories: Double?
}
