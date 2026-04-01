//
//  WorkoutView.swift
//  HealthPulseWatch
//
//  Main workout screen on the Watch — mirrors the active exercise card
//  from FocusModeView with a "Hit it!" button to complete the current set.
//

import SwiftUI

struct WorkoutView: View {
    @EnvironmentObject var workoutStore: WatchWorkoutStore
    @StateObject private var hkManager = WatchHealthKitManager.shared

    var body: some View {
        VStack(spacing: 0) {
            if workoutStore.isResting {
                restingContent
            } else {
                activeContent
            }
        }
        .containerBackground(.black, for: .navigation)
    }

    // MARK: - Active Set

    private var activeContent: some View {
        VStack(spacing: 8) {
            Text(workoutStore.exerciseName)
                .font(.headline)
                .foregroundStyle(.green)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text("Set \(workoutStore.setNumber) of \(workoutStore.totalSets)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let hr = hkManager.currentHeartRate {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                        .font(.caption2)
                    Text("\(Int(hr)) bpm")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                workoutStore.hitIt(exerciseIndex: workoutStore.exerciseIndex, setIndex: workoutStore.setNumber - 1)
                WatchHapticsManager.shared.setCompleted()
            } label: {
                Label("Hit it!", systemImage: "bolt.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding()
    }

    // MARK: - Resting

    private var restingContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.system(size: 28))
                .foregroundStyle(.orange)

            Text("RESTING")
                .font(.caption.bold())
                .foregroundStyle(.orange)

            if let end = workoutStore.restEndDate {
                Text(end, style: .timer)
                    .font(.system(.title2, design: .rounded).monospacedDigit().bold())
                    .foregroundStyle(.orange)
            }

            Text("Next: \(workoutStore.exerciseName)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if hkManager.activeCalories > 0 {
                Text("\(Int(hkManager.activeCalories)) kcal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
