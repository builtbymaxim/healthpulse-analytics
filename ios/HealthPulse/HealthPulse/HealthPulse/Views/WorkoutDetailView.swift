//
//  WorkoutDetailView.swift
//  HealthPulse
//
//  View/Edit/Delete workout details
//

import SwiftUI

struct WorkoutDetailView: View {
    let workout: Workout
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false

    var body: some View {
        List {
            // Overview Section
            Section {
                HStack(spacing: 16) {
                    Image(systemName: workout.workoutType.icon)
                        .font(.largeTitle)
                        .foregroundStyle(colorForWorkoutType(workout.workoutType))
                        .frame(width: 60, height: 60)
                        .background(colorForWorkoutType(workout.workoutType).opacity(0.15))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(workout.plannedWorkoutName ?? workout.workoutType.displayName)
                            .font(.title2.bold())

                        if let planId = workout.planId {
                            Label("From Training Plan", systemImage: "calendar.badge.checkmark")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 8)
            }

            // Details Section
            Section("Details") {
                LabeledContent("Date") {
                    Text(workout.startedAt.formatted(date: .long, time: .shortened))
                }

                if let duration = workout.durationMinutes {
                    LabeledContent("Duration") {
                        Text("\(duration) min")
                    }
                }

                if let intensity = workout.intensity {
                    LabeledContent("Intensity") {
                        Text(intensity.rawValue.capitalized)
                            .foregroundStyle(colorForIntensity(intensity))
                    }
                }

                if let calories = workout.caloriesBurned {
                    LabeledContent("Calories Burned") {
                        Text("\(Int(calories)) kcal")
                    }
                }

                if let heartRate = workout.averageHeartRate {
                    LabeledContent("Avg Heart Rate") {
                        Text("\(Int(heartRate)) bpm")
                    }
                }

                if let rating = workout.overallRating {
                    LabeledContent("Rating") {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.caption)
                                    .foregroundStyle(star <= rating ? .yellow : .gray.opacity(0.3))
                            }
                        }
                    }
                }
            }

            // Exercises Section (if from training plan)
            if let exercises = workout.exercises, !exercises.isEmpty {
                Section("Exercises") {
                    ForEach(exercises) { exercise in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(exercise.name)
                                    .font(.headline)
                                if exercise.isKeyLift {
                                    Text("KEY")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.2))
                                        .foregroundStyle(.orange)
                                        .clipShape(Capsule())
                                }
                                Spacer()
                                if exercise.isCompleted {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }

                            if !exercise.sets.isEmpty {
                                VStack(spacing: 4) {
                                    ForEach(Array(exercise.sets.enumerated()), id: \.1.id) { index, set in
                                        HStack {
                                            Text("Set \(index + 1)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .frame(width: 50, alignment: .leading)
                                            Text("\(Int(set.weight)) kg × \(set.reps)")
                                                .font(.subheadline)
                                            if let rpe = set.rpe {
                                                Spacer()
                                                Text("RPE \(rpe)")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            if set.isPR {
                                                Text("PR")
                                                    .font(.caption.bold())
                                                    .foregroundStyle(.yellow)
                                            }
                                        }
                                    }
                                }
                                .padding(.leading, 8)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            // Notes Section
            if let notes = workout.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                        .font(.body)
                }
            }

            // Delete Section
            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    HStack {
                        Spacer()
                        if isDeleting {
                            ProgressView()
                        } else {
                            Label("Delete Workout", systemImage: "trash")
                        }
                        Spacer()
                    }
                }
                .disabled(isDeleting)
            }
        }
        .navigationTitle("Workout Details")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete Workout?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteWorkout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private func colorForWorkoutType(_ type: WorkoutType) -> Color {
        type.color
    }

    private func colorForIntensity(_ intensity: Intensity) -> Color {
        switch intensity {
        case .light: return .green
        case .moderate: return .orange
        case .hard: return .red
        }
    }

    private func deleteWorkout() {
        isDeleting = true

        Task {
            do {
                try await APIService.shared.deleteWorkout(id: workout.id)
                await MainActor.run {
                    HapticsManager.shared.success()
                    onDelete()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    HapticsManager.shared.error()
                    ToastManager.shared.error("Failed to delete workout")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailView(
            workout: Workout(
                id: UUID(),
                userId: UUID(),
                workoutType: .strength,
                startedAt: Date(),
                durationMinutes: 45,
                intensity: .moderate,
                notes: "Good workout!",
                createdAt: Date()
            ),
            onDelete: {}
        )
    }
}
