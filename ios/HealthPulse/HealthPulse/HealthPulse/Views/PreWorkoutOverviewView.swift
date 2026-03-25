//
//  PreWorkoutOverviewView.swift
//  HealthPulse
//
//  Shown between tapping "Start Workout" and entering WorkoutExecutionView.
//  Lets the user reorder planned exercises before starting; persists changes
//  back to the plan schedule via PATCH so the next session reflects the order.
//

import SwiftUI

struct PreWorkoutOverviewView: View {
    let workout: TodayWorkoutResponse
    let planId: UUID?
    let onComplete: ([PRInfo]) -> Void

    @State private var exercises: [PlannedExercise]
    @State private var showAddExercise = false
    @Environment(\.dismiss) private var dismiss

    init(workout: TodayWorkoutResponse, planId: UUID?, onComplete: @escaping ([PRInfo]) -> Void) {
        self.workout = workout
        self.planId = planId
        self.onComplete = onComplete
        _exercises = State(initialValue: workout.exercises ?? [])
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(exercises.indices, id: \.self) { index in
                        let exercise = exercises[index]
                        let isKeyLift = index < 2   // mirrors WorkoutExecutionViewModel.buildExercises
                        exerciseRow(exercise, isKeyLift: isKeyLift)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if !isKeyLift {
                                    Button(role: .destructive) {
                                        exercises.remove(at: index)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                    }
                    .onMove { from, to in
                        exercises.move(fromOffsets: from, toOffset: to)
                    }
                } header: {
                    Text("Drag to reorder")
                        .textCase(.none)
                }

                Section {
                    Button {
                        showAddExercise = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle")
                            .foregroundStyle(AppTheme.primary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, .constant(.active))
            .navigationTitle(workout.workoutName ?? "Today's Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: startWorkout) {
                    Text("Start Workout")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.primary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .sheet(isPresented: $showAddExercise) {
            AddExerciseSheet { name in
                exercises.append(PlannedExercise(
                    name: name, sets: 3, reps: nil, notes: nil,
                    isKeyLift: false, restSeconds: nil
                ))
            }
        }
    }

    @ViewBuilder
    private func exerciseRow(_ exercise: PlannedExercise, isKeyLift: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.body)
                if let sets = exercise.sets, let reps = exercise.reps {
                    Text("\(sets) x \(reps)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let sets = exercise.sets {
                    Text("\(sets) sets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Key Lift / Accessory badge
            if isKeyLift {
                Text("Key Lift")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.yellow.opacity(0.2))
                    .foregroundStyle(Color.orange)
                    .clipShape(Capsule())
            } else {
                Text("Accessory")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.1))
                    .foregroundStyle(.secondary)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    private var reorderedWorkout: TodayWorkoutResponse {
        var w = workout
        w.exercises = exercises
        return w
    }

    private func startWorkout() {
        persistReorderIfNeeded()
        WorkoutSessionStore.shared.startWorkout(
            workout: reorderedWorkout,
            planId: planId
        ) { prs in
            onComplete(prs)
        }
        dismiss()
    }

    private func persistReorderIfNeeded() {
        guard let planId else { return }
        let mapped = exercises.map { ex in
            PatchScheduleExercise(
                name: ex.name,
                sets: ex.sets ?? 3,
                reps: ex.reps,
                notes: ex.notes,
                isKeyLift: ex.isKeyLift ?? false
            )
        }
        Task {
            try? await APIService.shared.patchPlanDaySchedule(
                planId: planId,
                dayOfWeek: workout.dayOfWeek,
                exercises: mapped
            )
        }
    }
}
