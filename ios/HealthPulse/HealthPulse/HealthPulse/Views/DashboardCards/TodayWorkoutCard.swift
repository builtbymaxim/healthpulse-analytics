//
//  TodayWorkoutCard.swift
//  HealthPulse
//
//  Dashboard card showing today's planned workout from the training plan.
//

import SwiftUI

struct TodayWorkoutCard: View {
    let workout: TodayWorkoutResponse
    let onTap: () -> Void

    private var dayName: String {
        let days = ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return workout.dayOfWeek >= 1 && workout.dayOfWeek <= 7 ? days[workout.dayOfWeek] : ""
    }

    var body: some View {
        Button(action: {
            guard workout.isCompleted != true else { return }
            HapticsManager.shared.light()
            onTap()
        }) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            SectionHeaderLabel(text: "Today's Workout")
                            if let planName = workout.planName {
                                Text(planName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(dayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }

                    if workout.isRestDay {
                        // Rest day view
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.purple.opacity(0.15))
                                    .frame(width: 56, height: 56)

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
                        // Workout day view
                        let completed = workout.isCompleted == true
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(completed ? Color.green.opacity(0.15) : AppTheme.primary.opacity(0.15))
                                    .frame(width: 56, height: 56)

                                Image(systemName: completed ? "checkmark" : "dumbbell.fill")
                                    .font(.title2)
                                    .foregroundStyle(completed ? .green : AppTheme.primary)
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

                            if completed {
                                Text("Done")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.15))
                                    .foregroundStyle(.green)
                                    .clipShape(Capsule())
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        // Exercise preview (show first 3)
                        if let exercises = workout.exercises, !exercises.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(exercises.prefix(3)) { exercise in
                                    HStack {
                                        Circle()
                                            .fill(AppTheme.primary.opacity(0.5))
                                            .frame(width: 6, height: 6)
                                        Text(exercise.name)
                                            .font(.caption)
                                        if let sets = exercise.sets, let reps = exercise.reps {
                                            Spacer()
                                            Text("\(sets)×\(reps)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                if exercises.count > 3 {
                                    Text("+\(exercises.count - 3) more exercises")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.leading, 14)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
            }
            .elevatedShadow()
            .opacity(workout.isCompleted == true ? 0.8 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
