//
//  UnifiedWorkoutDetailView.swift
//  HealthPulse
//
//  Detail view for both freeform and plan workout entries from the unified list.
//

import SwiftUI

struct UnifiedWorkoutDetailView: View {
    let entry: UnifiedWorkoutEntry
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var workoutSets: [WorkoutSet] = []
    @State private var sessionExercises: [ExerciseLog] = []
    @State private var isLoading = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false

    private var workoutTypeEnum: WorkoutType? {
        WorkoutType(rawValue: entry.workoutType)
    }

    var body: some View {
        List {
            // MARK: Overview header
            Section {
                HStack(spacing: 16) {
                    Image(systemName: workoutTypeEnum?.icon ?? "figure.strengthtraining.traditional")
                        .font(.largeTitle)
                        .foregroundStyle(workoutTypeEnum?.color ?? AppTheme.primary)
                        .frame(width: 60, height: 60)
                        .background((workoutTypeEnum?.color ?? AppTheme.primary).opacity(0.15))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.displayName)
                            .font(.title2.bold())
                        if entry.isPlanWorkout {
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

            // MARK: Details
            Section("Details") {
                LabeledContent("Date") {
                    Text(entry.startTime.formatted(date: .long, time: .shortened))
                }

                if let duration = entry.durationMinutes {
                    LabeledContent("Duration") {
                        Text("\(duration) min")
                    }
                }

                if let intensity = entry.intensity {
                    LabeledContent("Intensity") {
                        Text(intensity.capitalized)
                            .foregroundStyle(intensityColor(intensity))
                    }
                }

                if let calories = entry.caloriesBurned {
                    LabeledContent("Calories") {
                        Text("\(calories) kcal")
                    }
                }

                if let rating = entry.overallRating {
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

            // MARK: Exercises
            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else if entry.isPlanWorkout && !sessionExercises.isEmpty {
                Section("Exercises") {
                    ForEach(sessionExercises) { exercise in
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
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(Array(exercise.sets.enumerated()), id: \.1.id) { i, s in
                                        HStack {
                                            Text("Set \(i + 1)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .frame(width: 50, alignment: .leading)
                                            Text("\(formatted(s.weight)) kg × \(s.reps)")
                                                .font(.subheadline)
                                            if s.isPR {
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
            } else if !entry.isPlanWorkout && !workoutSets.isEmpty {
                let grouped = groupedSets(workoutSets)
                Section("Exercises") {
                    ForEach(grouped, id: \.name) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.name)
                                .font(.headline)
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(group.sets.enumerated()), id: \.1.id) { i, s in
                                    HStack {
                                        Text("Set \(i + 1)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 50, alignment: .leading)
                                        Text("\(formatted(s.weightKg)) kg × \(s.reps)")
                                            .font(.subheadline)
                                        if s.isPR {
                                            Text("PR")
                                                .font(.caption.bold())
                                                .foregroundStyle(.yellow)
                                        }
                                    }
                                }
                            }
                            .padding(.leading, 8)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            // MARK: Notes
            if let notes = entry.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                }
            }

            // MARK: Delete (freeform only)
            if !entry.isPlanWorkout {
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
        }
        .navigationTitle("Workout Details")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete Workout?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteWorkout() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .task { await loadDetails() }
    }

    // MARK: - Data

    private func loadDetails() async {
        isLoading = true
        defer { isLoading = false }
        if entry.isPlanWorkout {
            if let session = try? await APIService.shared.getWorkoutSession(id: entry.id) {
                sessionExercises = session.exercises ?? []
            }
        } else if entry.workoutType == "strength" {
            workoutSets = (try? await APIService.shared.getWorkoutSets(workoutId: entry.id)) ?? []
        }
    }

    private func deleteWorkout() {
        isDeleting = true
        Task {
            do {
                try await APIService.shared.deleteWorkout(id: entry.id)
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

    // MARK: - Helpers

    private struct ExerciseGroup {
        let name: String
        let sets: [WorkoutSet]
    }

    private func groupedSets(_ sets: [WorkoutSet]) -> [ExerciseGroup] {
        var order: [String] = []
        var map: [String: [WorkoutSet]] = [:]
        for s in sets.sorted(by: { $0.setNumber < $1.setNumber }) {
            let name = s.exerciseName ?? "Unknown"
            if map[name] == nil { order.append(name) }
            map[name, default: []].append(s)
        }
        return order.map { ExerciseGroup(name: $0, sets: map[$0] ?? []) }
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }

    private func intensityColor(_ intensity: String) -> Color {
        switch intensity.lowercased() {
        case "light": return .green
        case "moderate": return .orange
        case "hard": return .red
        default: return .secondary
        }
    }
}
