//
//  HealthMetricsView.swift
//  HealthPulseWatch
//
//  Shows daily steps, resting HR, HRV, and optional VO2 Max.
//

import SwiftUI

struct HealthMetricsView: View {
    @EnvironmentObject var store: WatchWorkoutStore

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let snap = store.snapshot {
                    stepsRing(current: snap.steps, goal: snap.stepGoal)
                    metricsGrid(rhr: snap.restingHR, hrv: snap.hrv, vo2: snap.vo2Max)
                } else {
                    Text("No health data")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
        .containerBackground(.black, for: .navigation)
    }

    private func stepsRing(current: Int, goal: Int) -> some View {
        let progress = min(Double(current) / Double(goal), 1.0)
        let color: Color = progress >= 1.0 ? .green : (progress >= 0.7 ? .blue : .gray)

        return VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color(.darkGray), lineWidth: 6)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(current)")
                        .font(.system(size: 20, weight: .bold))
                    Text("/ \(goal)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            Text("Steps")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func metricsGrid(rhr: Double?, hrv: Double?, vo2: Double?) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                metricCard(label: "RHR", value: rhr.map { Int($0) }, unit: "bpm", color: .red)
                metricCard(label: "HRV", value: hrv.map { Int($0) }, unit: "ms", color: .purple)
            }
            if let vo2val = vo2 {
                metricCard(label: "VO2 Max", value: Int(vo2val), unit: "ml/kg/min", color: .orange)
            }
        }
        .padding(.horizontal, 4)
    }

    private func metricCard(label: String, value: Int?, unit: String, color: Color) -> some View {
        VStack(spacing: 2) {
            if let v = value {
                Text("\(v)")
                    .font(.system(size: 16, weight: .bold))
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("--")
                    .font(.system(size: 16, weight: .bold))
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func metricCard(label: String, value: Int, unit: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 16, weight: .bold))
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
