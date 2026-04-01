//
//  LiveWorkoutBar.swift
//  HealthPulse
//
//  Spotify-style mini bar shown above the tab bar while a workout is minimized.
//  Tapping it restores the full WorkoutExecutionView.
//

import SwiftUI
import Combine

struct LiveWorkoutBar: View {
    @ObservedObject private var store = WorkoutSessionStore.shared
    @State private var isBlinking = false

    var body: some View {
        if store.isActive && !store.isPresenting {
            content
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var isResting: Bool { store.activeViewModel?.isResting ?? false }
    private var restEndDate: Date? { store.activeViewModel?.restEndDate }

    private var content: some View {
        HStack(spacing: 12) {
            // Blinking dot — orange during rest, red during active set
            Circle()
                .fill(isResting ? Color.orange : Color.red)
                .frame(width: 10, height: 10)
                .opacity(isBlinking ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isBlinking)
                .animation(MotionTokens.entrance, value: isResting)
                .onAppear { isBlinking = true }

            // "RESTING" during rest, exercise name otherwise
            Text(isResting ? "RESTING" : currentExerciseName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isResting ? .orange : .primary)
                .lineLimit(1)
                .animation(MotionTokens.entrance, value: isResting)

            Spacer()

            // Rest countdown during rest, elapsed time otherwise
            if isResting, let end = restEndDate {
                Text(end, style: .timer)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.orange)
            } else {
                Text(formattedTime)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.up")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(MotionTokens.entrance) {
                store.restore()
            }
        }
        .onChange(of: isResting) { _, nowResting in
            if !nowResting { HapticsManager.shared.success() }
        }
    }

    private var currentExerciseName: String {
        guard let vm = store.activeViewModel else { return "Workout" }
        return vm.exerciseLogs.first(where: { !$0.isCompleted })?.name
            ?? vm.exerciseLogs.first?.name
            ?? vm.workoutName
    }

    private var formattedTime: String {
        guard let vm = store.activeViewModel else { return "0:00" }
        let t = Int(vm.elapsedTime)
        let m = t / 60, s = t % 60
        return String(format: "%d:%02d", m, s)
    }
}
