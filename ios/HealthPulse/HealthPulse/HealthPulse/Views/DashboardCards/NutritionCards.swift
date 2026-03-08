//
//  NutritionCards.swift
//  HealthPulse
//
//  Dashboard cards for nutrition progress and weekly adherence.
//

import SwiftUI

// MARK: - Nutrition Progress Card

struct NutritionProgressCard: View {
    let calories: Double
    let calorieGoal: Double
    let protein: Double
    let proteinGoal: Double
    let carbs: Double
    let carbsGoal: Double
    let fat: Double
    let fatGoal: Double

    private var calorieProgress: Double {
        guard calorieGoal > 0 else { return 0 }
        return min(calories / calorieGoal, 1.0)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                SectionHeaderLabel(text: "Today's Nutrition")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Main calorie ring
            HStack(spacing: 24) {
                // Calorie ring
                ZStack {
                    Circle()
                        .stroke(AppTheme.primary.opacity(0.2), lineWidth: 12)

                    Circle()
                        .trim(from: 0, to: calorieProgress)
                        .stroke(AppTheme.primary, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.5), value: calorieProgress)

                    VStack(spacing: 2) {
                        Text("\(Int(calories))")
                            .font(.system(size: 28, weight: .bold))
                            .contentTransition(.numericText())

                        Text("/ \(Int(calorieGoal))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("kcal")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(width: 120, height: 120)

                // Macro bars
                VStack(spacing: 12) {
                    MacroBar(name: "Protein", current: protein, goal: proteinGoal, color: .blue)
                    MacroBar(name: "Carbs", current: carbs, goal: carbsGoal, color: .orange)
                    MacroBar(name: "Fat", current: fat, goal: fatGoal, color: .purple)
                }
            }
        }
        .padding()
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .cardShadow()
    }
}

struct MacroBar: View {
    let name: String
    let current: Double
    let goal: Double
    let color: Color

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(current / goal, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(current))g / \(Int(goal))g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * progress)
                        .animation(.easeOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Nutrition Adherence Card

struct NutritionAdherenceCard: View {
    let weeklyData: [DayAdherence]
    let adherenceScore: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeaderLabel(text: "Eating Habits")
                Spacer()
                Text("\(adherenceScore)% this week")
                    .font(.caption)
                    .contentTransition(.numericText())
                    .foregroundStyle(adherenceScore >= 80 ? .green : (adherenceScore >= 60 ? .orange : .secondary))
            }

            // 7-day mini chart
            HStack(spacing: 4) {
                ForEach(weeklyData.suffix(7), id: \.day) { day in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(day.isOnTarget ? AppTheme.primary : Color.gray.opacity(0.3))
                            .frame(width: 32, height: 40 * (day.progress > 0 ? min(day.progress, 1.2) : 0.1))

                        Text(day.dayLabel)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 60)

            // Legend
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(AppTheme.primary)
                        .frame(width: 8, height: 8)
                    Text("On target")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                    Text("Off target")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .cardShadow()
    }
}

struct DayAdherence: Identifiable {
    let id = UUID()
    let day: Date
    let progress: Double  // 0-1+ representing % of goal
    let isOnTarget: Bool  // 80-120% of goal

    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: day).prefix(1))
    }
}
