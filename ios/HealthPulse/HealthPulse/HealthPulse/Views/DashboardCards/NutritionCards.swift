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

    private var sortedData: [DayAdherence] {
        weeklyData.sorted { $0.day < $1.day }  // oldest left → today rightmost
    }

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
                ForEach(sortedData) { day in
                    let isToday = Calendar.current.isDateInToday(day.day)
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(day.isOnTarget ? AppTheme.primary : Color.gray.opacity(0.3))
                            .frame(width: 32, height: 40 * (day.progress > 0 ? min(day.progress, 1.2) : 0.1))

                        Text(day.dayLabel)
                            .font(.system(size: 10, weight: isToday ? .bold : .regular))
                            .foregroundStyle(isToday ? AppTheme.primary : Color.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        isToday ? AppTheme.primary.opacity(0.08) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                }
            }
            .frame(height: 70)

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
    let progress: Double       // 0-1+ representing % of goal
    let isOnTarget: Bool       // 80-120% of goal
    let caloriesActual: Double
    let caloriesTarget: Double

    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: day).prefix(2))  // "Mo","Tu","We","Th","Fr","Sa","Su"
    }
}

// MARK: - Nutrition Adherence Detail Sheet

struct NutritionAdherenceDetailSheet: View {
    let weeklyData: [DayAdherence]
    let adherenceScore: Int
    @Environment(\.dismiss) private var dismiss

    private var sortedData: [DayAdherence] {
        weeklyData.sorted { $0.day < $1.day }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Score header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Eating Habits")
                                .font(.title2.bold())
                            Text("Last 7 days")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(adherenceScore)%")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(adherenceScore >= 80 ? .green : adherenceScore >= 60 ? .orange : .red)
                    }
                    .padding(.horizontal)

                    Divider()

                    // Explanation
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How is this calculated?")
                            .font(.headline)
                        Text("You're on target for a day when your calorie intake is between 80% and 120% of your daily goal. Your score is the percentage of days you hit that range.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    // Day-by-day rows
                    VStack(spacing: 12) {
                        ForEach(sortedData) { day in
                            dayRow(day)
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(.top)
            }
            .background(ThemedBackground())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func dayRow(_ day: DayAdherence) -> some View {
        let isToday = Calendar.current.isDateInToday(day.day)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isToday ? "Today" : day.day.formatted(.dateTime.weekday(.wide)))
                        .font(.subheadline.bold())
                        .foregroundStyle(isToday ? AppTheme.primary : .primary)
                    Text(day.day.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 6) {
                    if day.caloriesActual > 0 {
                        Text("\(Int(day.caloriesActual)) / \(Int(day.caloriesTarget)) kcal")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No data")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: day.isOnTarget ? "checkmark.circle.fill"
                          : (day.caloriesActual > 0 ? "xmark.circle.fill" : "circle.dashed"))
                        .foregroundStyle(day.isOnTarget ? .green
                                         : (day.caloriesActual > 0 ? .orange : .secondary))
                }
            }

            if day.caloriesActual > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.15))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(day.isOnTarget ? AppTheme.primary : Color.orange)
                            .frame(width: geo.size.width * min(day.progress, 1.0))
                    }
                }
                .frame(height: 6)
            }
        }
        .padding()
        .background(isToday ? AppTheme.primary.opacity(0.06) : AppTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isToday ? AppTheme.primary.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .padding(.horizontal)
    }
}
