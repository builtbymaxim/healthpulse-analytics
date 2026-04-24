//
//  NutritionGlanceView.swift
//  HealthPulseWatch
//
//  Shows daily calorie and macro progress rings.
//

import SwiftUI

struct NutritionGlanceView: View {
    @EnvironmentObject var store: WatchWorkoutStore

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let snap = store.snapshot {
                    calorieRing(current: snap.calories, goal: snap.calorieGoal)
                    macroRow(protein: snap.protein, carbs: snap.carbs, fat: snap.fat)
                } else {
                    Text("No nutrition data")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
        .containerBackground(.black, for: .navigation)
    }

    private func calorieRing(current: Double, goal: Double) -> some View {
        let progress = min(current / goal, 1.0)
        let color: Color = progress >= 0.9 ? .green : (progress >= 0.7 ? .orange : .blue)

        return VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color(.darkGray), lineWidth: 6)
                    .frame(width: 70, height: 70)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(Int(current))")
                        .font(.system(size: 18, weight: .bold))
                    Text("/ \(Int(goal))")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            Text("Calories")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func macroRow(protein: Double, carbs: Double, fat: Double) -> some View {
        HStack(spacing: 12) {
            macroBar(value: protein, max: 200, label: "P", color: .red)
            macroBar(value: carbs, max: 300, label: "C", color: .yellow)
            macroBar(value: fat, max: 70, label: "F", color: .orange)
        }
        .padding(.horizontal, 4)
    }

    private func macroBar(value: Double, max: Double, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(.darkGray))

                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(height: 20 * CGFloat(min(value / max, 1.0)))
            }
            .frame(height: 20)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
