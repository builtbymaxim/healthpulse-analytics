//
//  CustomPlanBuilderViewModel.swift
//  HealthPulse
//
//  State management for the custom training plan builder flow.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Draft Types (UI-only, not persisted directly)

struct DraftExercise: Identifiable {
    let id = UUID()
    let exercise: Exercise
    var sets: Int = 3
    var reps: String = "8-10"
    var notes: String = ""
}

struct DraftDay: Identifiable {
    let id = UUID()
    let dayOfWeek: Int      // ISO 1=Mon … 7=Sun
    var workoutName: String
    var focus: String = ""
    var exercises: [DraftExercise] = []

    var isConfigured: Bool { !exercises.isEmpty }

    static func shortName(_ dayOfWeek: Int) -> String {
        ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][dayOfWeek - 1]
    }

    static func fullName(_ dayOfWeek: Int) -> String {
        ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][dayOfWeek - 1]
    }
}

// MARK: - ViewModel

@MainActor
class CustomPlanBuilderViewModel: ObservableObject {
    @Published var planName: String = ""
    @Published var days: [Int: DraftDay] = [:]      // dayOfWeek -> DraftDay
    @Published var isLoading = false
    @Published var error: String?

    var canSave: Bool {
        !planName.trimmingCharacters(in: .whitespaces).isEmpty && !activeDays.isEmpty
    }

    var activeDays: [DraftDay] {
        days.values.filter { $0.isConfigured }.sorted { $0.dayOfWeek < $1.dayOfWeek }
    }

    // MARK: - Day Management

    func toggleDay(_ dayOfWeek: Int) {
        if days[dayOfWeek] != nil {
            days.removeValue(forKey: dayOfWeek)
        } else {
            days[dayOfWeek] = DraftDay(
                dayOfWeek: dayOfWeek,
                workoutName: "\(DraftDay.fullName(dayOfWeek)) Workout"
            )
        }
    }

    func isDaySelected(_ dayOfWeek: Int) -> Bool {
        days[dayOfWeek] != nil
    }

    // MARK: - Exercise Management

    func addExercise(_ exercise: Exercise, to dayOfWeek: Int) {
        guard days[dayOfWeek] != nil else { return }
        // Avoid duplicate
        guard !(days[dayOfWeek]?.exercises.contains(where: { $0.exercise.id == exercise.id }) ?? false) else { return }
        days[dayOfWeek]?.exercises.append(DraftExercise(exercise: exercise))
    }

    func removeExercise(id: UUID, from dayOfWeek: Int) {
        days[dayOfWeek]?.exercises.removeAll { $0.id == id }
    }

    func updateExercise(_ updated: DraftExercise, in dayOfWeek: Int) {
        guard let idx = days[dayOfWeek]?.exercises.firstIndex(where: { $0.id == updated.id }) else { return }
        days[dayOfWeek]?.exercises[idx] = updated
    }

    func exerciseCount(for dayOfWeek: Int) -> Int {
        days[dayOfWeek]?.exercises.count ?? 0
    }

    /// Fetch full plan detail + exercise library in parallel, then pre-fill the builder.
    /// Exercises are matched by name against the library; unrecognised names are skipped.
    func loadAndPrefill(planId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let planTask    = APIService.shared.getTrainingPlanDetail(planId)
            async let libraryTask = APIService.shared.getExercises()
            let (plan, library) = try await (planTask, libraryTask)

            let exerciseMap = Dictionary(
                library.map { ($0.name.lowercased(), $0) },
                uniquingKeysWith: { first, _ in first }
            )

            planName = plan.name
            days = [:]

            for workout in plan.workouts ?? [] {
                let draftExercises: [DraftExercise] = (workout.exercises ?? []).compactMap { planned in
                    guard let ex = exerciseMap[planned.name.lowercased()] else { return nil }
                    return DraftExercise(
                        exercise: ex,
                        sets: planned.sets ?? 3,
                        reps: planned.reps ?? "8-10",
                        notes: planned.notes ?? ""
                    )
                }
                days[workout.day] = DraftDay(
                    dayOfWeek: workout.day,
                    workoutName: workout.name,
                    focus: workout.focus ?? "",
                    exercises: draftExercises
                )
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Save

    func saveCustomPlan(onSuccess: @escaping () -> Void) {
        guard canSave else { return }
        isLoading = true
        error = nil

        let request = buildRequest()

        Task {
            do {
                _ = try await APIService.shared.createCustomPlan(request)
                isLoading = false
                onSuccess()
            } catch {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }

    // MARK: - Private

    private func buildRequest() -> CreateCustomPlanRequest {
        let payloadDays = activeDays.map { day -> CustomPlanDayPayload in
            let exercises = day.exercises.map { draft in
                CustomPlanExercisePayload(
                    id: draft.exercise.id.uuidString,
                    name: draft.exercise.name,
                    sets: draft.sets,
                    reps: draft.reps.isEmpty ? nil : draft.reps,
                    notes: draft.notes.isEmpty ? nil : draft.notes
                )
            }
            return CustomPlanDayPayload(
                dayOfWeek: day.dayOfWeek,
                workoutName: day.workoutName,
                focus: day.focus.isEmpty ? nil : day.focus,
                exercises: exercises
            )
        }
        return CreateCustomPlanRequest(
            planName: planName.trimmingCharacters(in: .whitespaces),
            days: payloadDays
        )
    }
}
