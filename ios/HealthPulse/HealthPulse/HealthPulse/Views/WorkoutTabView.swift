//
//  WorkoutTabView.swift
//  HealthPulse
//
//  Dedicated workout tracking tab
//

import SwiftUI

struct WorkoutTabView: View {
    @State private var showStrengthSheet = false
    @State private var showRunningSheet = false
    @State private var showGeneralWorkout = false
    @State private var showTrainingPlanView = false
    @State private var showWorkoutExecution = false
    @State private var showPRCelebration = false
    @State private var achievedPRs: [PRInfo] = []
    @State private var recentWorkouts: [Workout] = []
    @State private var todaysWorkout: TodayWorkoutResponse?
    @State private var hasActivePlan = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Today's Planned Workout (if user has an active plan)
                    if let workout = todaysWorkout, hasActivePlan {
                        TodayPlanWorkoutCard(
                            workout: workout,
                            onStartWorkout: {
                                if !workout.isRestDay {
                                    showWorkoutExecution = true
                                    HapticsManager.shared.medium()
                                }
                            },
                            onManagePlan: {
                                showTrainingPlanView = true
                            }
                        )
                        .padding(.horizontal)
                    }

                    // Quick Start Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(hasActivePlan ? "Or Start Free Workout" : "Start Workout")
                                .font(.headline)
                            Spacer()
                        }

                        // Primary workout types - big buttons
                        HStack(spacing: 16) {
                            // Strength Training
                            WorkoutStartButton(
                                icon: "dumbbell.fill",
                                title: "Strength",
                                subtitle: "Log sets & reps",
                                color: .green
                            ) {
                                showStrengthSheet = true
                                HapticsManager.shared.medium()
                            }

                            // Running
                            WorkoutStartButton(
                                icon: "figure.run",
                                title: "Running",
                                subtitle: "Track distance",
                                color: .orange
                            ) {
                                showRunningSheet = true
                                HapticsManager.shared.medium()
                            }
                        }

                        // Secondary workout types
                        HStack(spacing: 12) {
                            ForEach([
                                ("figure.outdoor.cycle", "Cycling", Color.blue),
                                ("figure.yoga", "Yoga", Color.purple),
                                ("figure.pool.swim", "Swimming", Color.cyan),
                                ("figure.highintensity.intervaltraining", "HIIT", Color.red)
                            ], id: \.0) { icon, title, color in
                                SmallWorkoutButton(icon: icon, title: title, color: color) {
                                    showGeneralWorkout = true
                                    HapticsManager.shared.light()
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)

                    // Recent Workouts
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recent Workouts")
                                .font(.headline)
                            Spacer()
                        }

                        if recentWorkouts.isEmpty {
                            // Empty state
                            VStack(spacing: 12) {
                                Image(systemName: "figure.run.circle")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary)

                                Text("No workouts yet")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Text("Start your first workout above!")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            ForEach(recentWorkouts.prefix(5)) { workout in
                                NavigationLink {
                                    WorkoutDetailView(workout: workout) {
                                        // Remove from local list immediately
                                        recentWorkouts.removeAll { $0.id == workout.id }
                                    }
                                } label: {
                                    RecentWorkoutRow(workout: workout)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
                .padding(.top)
            }
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showTrainingPlanView = true
                    } label: {
                        Image(systemName: hasActivePlan ? "calendar.badge.checkmark" : "calendar.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showTrainingPlanView) {
                TrainingPlanView()
            }
            .fullScreenCover(isPresented: $showWorkoutExecution) {
                if let workout = todaysWorkout {
                    WorkoutExecutionView(workout: workout, planId: nil) { prs in
                        if !prs.isEmpty {
                            achievedPRs = prs
                            showPRCelebration = true
                        }
                        Task {
                            await loadTodaysWorkout()
                            loadRecentWorkouts()
                        }
                    }
                }
            }
            .sheet(isPresented: $showPRCelebration) {
                PRCelebrationView(prs: achievedPRs) {
                    showPRCelebration = false
                    achievedPRs = []
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showStrengthSheet) {
                StrengthWorkoutLogView(workoutId: nil) { savedSets in
                    ToastManager.shared.success("Workout saved with \(savedSets.count) sets!")
                    // Small delay to let API process the workout
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds
                        await MainActor.run {
                            loadRecentWorkouts()
                        }
                    }
                }
            }
            .sheet(isPresented: $showRunningSheet) {
                RunningWorkoutView { workout in
                    ToastManager.shared.success("Run logged!")
                    // Optimistically add to local state immediately
                    recentWorkouts.insert(workout, at: 0)
                    // Then sync with API in background
                    loadRecentWorkouts()
                }
            }
            .sheet(isPresented: $showGeneralWorkout) {
                GeneralWorkoutSheet { workout in
                    ToastManager.shared.success("Workout logged!")
                    // Optimistically add to local state immediately
                    recentWorkouts.insert(workout, at: 0)
                    // Then sync with API in background
                    loadRecentWorkouts()
                }
            }
            .task {
                await loadTodaysWorkout()
                loadRecentWorkouts()
            }
            .refreshable {
                await loadTodaysWorkout()
                loadRecentWorkouts()
            }
        }
    }

    private func loadTodaysWorkout() async {
        do {
            let workout = try await APIService.shared.getTodaysWorkout()
            await MainActor.run {
                hasActivePlan = workout.hasPlan
                if workout.hasPlan {
                    todaysWorkout = workout
                } else {
                    todaysWorkout = nil
                }
            }
        } catch {
            print("Failed to load today's workout: \(error)")
            await MainActor.run {
                hasActivePlan = false
                todaysWorkout = nil
            }
        }
    }

    private func loadRecentWorkouts() {
        Task {
            do {
                recentWorkouts = try await APIService.shared.getWorkouts(days: 7)
            } catch {
                // Silently fail - empty state will show
                print("Failed to load workouts: \(error)")
            }
        }
    }
}

// MARK: - Today's Plan Workout Card

struct TodayPlanWorkoutCard: View {
    let workout: TodayWorkoutResponse
    let onStartWorkout: () -> Void
    let onManagePlan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Plan")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let planName = workout.planName {
                        Text(planName)
                            .font(.headline)
                    }
                }
                Spacer()
                Button {
                    onManagePlan()
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            if workout.isRestDay {
                // Rest day
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.15))
                            .frame(width: 60, height: 60)
                        Image(systemName: "bed.double.fill")
                            .font(.title2)
                            .foregroundStyle(.purple)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rest Day")
                            .font(.title3.bold())
                        Text("Recovery is part of the plan")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            } else {
                // Workout day
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.15))
                                .frame(width: 60, height: 60)
                            Image(systemName: "dumbbell.fill")
                                .font(.title2)
                                .foregroundStyle(.green)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(workout.workoutName ?? "Workout")
                                .font(.title3.bold())
                            HStack(spacing: 12) {
                                if let focus = workout.workoutFocus {
                                    Label(focus, systemImage: "target")
                                }
                                if let minutes = workout.estimatedMinutes {
                                    Label("\(minutes) min", systemImage: "clock")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    // Exercise preview
                    if let exercises = workout.exercises, !exercises.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(exercises.prefix(3)) { exercise in
                                HStack {
                                    Circle()
                                        .fill(Color.green.opacity(0.5))
                                        .frame(width: 6, height: 6)
                                    Text(exercise.name)
                                        .font(.caption)
                                    Spacer()
                                    if let sets = exercise.sets, let reps = exercise.reps {
                                        Text("\(sets)×\(reps)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            if exercises.count > 3 {
                                Text("+\(exercises.count - 3) more exercises")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .padding(.leading, 14)
                            }
                        }
                    }

                    // Start button
                    Button {
                        onStartWorkout()
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Workout")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }
}

// MARK: - Workout Start Button

struct WorkoutStartButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundStyle(color)

                VStack(spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct SmallWorkoutButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Recent Workout Row

struct RecentWorkoutRow: View {
    let workout: Workout

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: workout.workoutType.icon)
                .font(.title2)
                .foregroundStyle(workout.workoutType.color)
                .frame(width: 44, height: 44)
                .background(workout.workoutType.color.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                // Show planned workout name if from training plan, otherwise type
                Text(workout.plannedWorkoutName ?? workout.workoutType.displayName)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    if let duration = workout.durationMinutes {
                        Text("\(duration) min")
                    }
                    if workout.planId != nil {
                        Text("Plan")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(workout.startedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - General Workout Sheet

struct GeneralWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (Workout) -> Void

    @State private var workoutType: WorkoutType = .cycling
    @State private var duration: Double = 45
    @State private var intensity: Intensity = .moderate
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Workout Type
                VStack(alignment: .leading, spacing: 12) {
                    Text("Workout Type")
                        .font(.headline)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                        ForEach(WorkoutType.allCases.filter { $0 != .strength }, id: \.self) { type in
                            WorkoutTypeButton(
                                type: type,
                                isSelected: workoutType == type
                            ) {
                                workoutType = type
                                HapticsManager.shared.selection()
                            }
                        }
                    }
                }

                // Duration
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Duration")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(duration)) min")
                            .font(.title2.bold())
                            .foregroundStyle(.green)
                    }

                    Slider(value: $duration, in: 5...180, step: 5)
                        .tint(.green)
                }

                // Intensity
                VStack(alignment: .leading, spacing: 12) {
                    Text("Intensity")
                        .font(.headline)

                    Picker("Intensity", selection: $intensity) {
                        ForEach(Intensity.allCases, id: \.self) { level in
                            Text(level.rawValue.capitalized).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Spacer()

                // Save Button
                Button {
                    saveWorkout()
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Save Workout")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(isSubmitting)
            }
            .padding()
            .navigationTitle("Log Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func saveWorkout() {
        isSubmitting = true
        HapticsManager.shared.medium()

        Task {
            do {
                let workout = Workout(
                    id: UUID(),
                    userId: UUID(),
                    workoutType: workoutType,
                    startedAt: Date(),
                    durationMinutes: Int(duration),
                    intensity: intensity,
                    notes: nil,
                    createdAt: Date()
                )

                _ = try await APIService.shared.logWorkout(workout)

                await MainActor.run {
                    isSubmitting = false
                    HapticsManager.shared.success()
                    onSave(workout)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    HapticsManager.shared.error()
                    ToastManager.shared.error(error.localizedDescription)
                }
            }
        }
    }
}

#Preview {
    WorkoutTabView()
}
