//
//  SleepGlanceView.swift
//  HealthPulseWatch
//
//  Shows last night's sleep duration and stage breakdown.
//

import SwiftUI

struct SleepGlanceView: View {
    @EnvironmentObject var store: WatchWorkoutStore

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let snap = store.snapshot, let hours = snap.sleepHours {
                    sleepSummary(hours: hours)
                    if let deep = snap.sleepDeep, let rem = snap.sleepREM, let core = snap.sleepCore {
                        stageBreakdown(deep: deep, rem: rem, core: core)
                    }
                } else {
                    Text("No sleep data")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
        .containerBackground(.black, for: .navigation)
    }

    private func sleepSummary(hours: Double) -> some View {
        VStack(spacing: 8) {
            Text("\(String(format: "%.1f", hours))h")
                .font(.system(size: 32, weight: .bold))
            Text("Sleep last night")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.darkGray).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func stageBreakdown(deep: Double, rem: Double, core: Double) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                stageBar(value: deep, label: "Deep", color: .blue)
                stageBar(value: rem, label: "REM", color: .cyan)
                stageBar(value: core, label: "Core", color: .green)
            }
        }
        .padding(.horizontal, 4)
    }

    private func stageBar(value: Double, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(.darkGray))

                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(height: 20 * CGFloat(min(value / 4, 1.0)))
            }
            .frame(height: 20)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
