//
//  WorkoutExecutionViewModel.swift
//  HealthPulse
//
//  Extracted from WorkoutExecutionView — manages workout execution state,
//  live activity updates, and offline persistence.
//

import Foundation
import SwiftUI
import Combine
import ActivityKit
import UserNotifications

// MARK: - Offline State (private to this file)

private struct SavedSetLog: Codable {
    var weight: Double?
    var reps: Int?
    var duration: Int?
    var distance: Double?
    var rpe: Int?
}

private struct SavedExerciseLog: Codable {
    let name: String
    let isKeyLift: Bool
    let inputType: ExerciseInputType
    let targetSetsReps: String?
    var sets: [SavedSetLog]
    var isCompleted: Bool
}

private struct ActiveWorkoutState: Codable {
    let workoutName: String
    let exercises: [SavedExerciseLog]
    let startedAt: Date
    let planId: UUID?
}

// MARK: - View Model

@MainActor
class WorkoutExecutionViewModel: ObservableObject {
    @Published var exerciseLogs: [ExerciseLogEntry] = []
    @Published var elapsedTime: TimeInterval = 0
    @Published var isTimerRunning = false
    @Published var isSaving = false
    @Published var wasInterrupted = false
    @Published var isResting = false

    private let workout: TodayWorkoutResponse
    private let planId: UUID?
    private var timer: Timer?
    private let startTime = Date()
    private var strengthActivity: Activity<StrengthWorkoutAttributes>?
    @Published private(set) var restEndDate: Date?

    init(workout: TodayWorkoutResponse, planId: UUID?) {
        self.workout = workout
        self.planId = planId
        exerciseLogs = Self.buildExercises(from: workout)
        checkForInterruption()
    }

    // MARK: - Exercise Building

    static func buildExercises(from workout: TodayWorkoutResponse) -> [ExerciseLogEntry] {
        guard let exercises = workout.exercises else { return [] }
        return exercises.enumerated().map { index, exercise in
            ExerciseLogEntry(from: exercise, isKeyLift: index < 2)
        }
    }

    // MARK: - Workout Info (exposed for views that don't hold a TodayWorkoutResponse)

    var workoutName: String { workout.workoutName ?? "Workout" }
    var workoutFocus: String? { workout.workoutFocus }

    // MARK: - Computed Properties

    var canComplete: Bool {
        exerciseLogs.contains { log in
            if log.isCompleted { return true }
            return log.sets.contains { set in
                switch log.inputType {
                case .weightAndReps:
                    return (set.weight ?? 0) > 0 && (set.reps ?? 0) > 0
                case .repsOnly:
                    return (set.reps ?? 0) > 0
                case .timeOnly:
                    return (set.duration ?? 0) > 0
                case .distanceAndTime:
                    return (set.distance ?? 0) > 0 || (set.duration ?? 0) > 0
                }
            }
        }
    }

    // MARK: - Timer

    func startTimer() {
        isTimerRunning = true
        startLiveActivity()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [self] in
                self.elapsedTime = Date().timeIntervalSince(self.startTime)
            }
        }
        updateLiveActivity()
    }

    func stopTimer() {
        isTimerRunning = false
        timer?.invalidate()
        timer = nil
        endLiveActivity()
    }

    // MARK: - Exercise & Set Mutation

    func addSet(to exerciseIndex: Int) {
        guard exerciseIndex < exerciseLogs.count else { return }
        exerciseLogs[exerciseIndex].sets.append(SetLogEntry())
        updateLiveActivity()
        autoSave()
    }

    func deleteSet(from exerciseIndex: Int, setIndex: Int) {
        guard exerciseIndex < exerciseLogs.count,
              setIndex < exerciseLogs[exerciseIndex].sets.count else { return }
        exerciseLogs[exerciseIndex].sets.remove(at: setIndex)
        autoSave()
    }

    func markSetCompleted(exerciseIndex: Int, setIndex: Int) {
        guard exerciseIndex < exerciseLogs.count,
              setIndex < exerciseLogs[exerciseIndex].sets.count else { return }
        exerciseLogs[exerciseIndex].sets[setIndex].completedAt = Date()
        updateLiveActivity()
        autoSave()
    }

    func toggleExerciseCompleted(_ index: Int) {
        guard index < exerciseLogs.count else { return }
        exerciseLogs[index].isCompleted.toggle()
        autoSave()
    }

    func addExercise(name: String) {
        let detectedInputType = inferInputType(from: nil, exerciseName: name)
        let newExercise = ExerciseLogEntry(
            name: name,
            isKeyLift: false,
            inputType: detectedInputType,
            targetSetsReps: nil,
            sets: [SetLogEntry()],
            isCompleted: false
        )
        exerciseLogs.append(newExercise)
        updateLiveActivity()
        autoSave()
    }

    // MARK: - Weight Suggestions

    func fetchSuggestions() async {
        let names = exerciseLogs
            .filter { $0.inputType == .weightAndReps }
            .map(\.name)

        guard !names.isEmpty else { return }

        do {
            let suggestions = try await APIService.shared.getExerciseSuggestions(exerciseNames: names)

            for i in exerciseLogs.indices {
                guard let suggestion = suggestions[exerciseLogs[i].name] else { continue }
                exerciseLogs[i].suggestion = suggestion

                if let weight = suggestion.suggestedWeightKg, weight > 0 {
                    for j in exerciseLogs[i].sets.indices {
                        if exerciseLogs[i].sets[j].weight == nil {
                            exerciseLogs[i].sets[j].weight = weight
                        }
                    }
                }
            }
        } catch {
            print("Failed to fetch suggestions: \(error)")
        }
    }

    // MARK: - Workout Completion

    func completeWorkout(onError: ((String) -> Void)? = nil, completion: @escaping ([PRInfo]) -> Void) {
        isSaving = true
        stopTimer()

        Task {
            do {
                let exercises = exerciseLogs.compactMap { log -> ExerciseLog? in
                    let validSets = log.sets.filter { set in
                        switch log.inputType {
                        case .weightAndReps:
                            return (set.weight ?? 0) > 0 && (set.reps ?? 0) > 0
                        case .repsOnly:
                            return (set.reps ?? 0) > 0
                        case .timeOnly:
                            return (set.duration ?? 0) > 0
                        case .distanceAndTime:
                            return (set.distance ?? 0) > 0 || (set.duration ?? 0) > 0
                        }
                    }

                    guard log.isCompleted || !validSets.isEmpty else { return nil }

                    let setLogs = validSets.map { entry in
                        SetLog(
                            weight: entry.weight ?? 0,
                            reps: entry.reps ?? 0,
                            rpe: entry.rpe,
                            completedAt: entry.completedAt ?? Date()
                        )
                    }

                    return ExerciseLog(
                        name: log.name,
                        isKeyLift: log.isKeyLift,
                        sets: setLogs,
                        isCompleted: log.isCompleted
                    )
                }

                let sessionRequest = WorkoutSessionRequest(
                    planId: planId,
                    plannedWorkoutName: workout.workoutName,
                    startedAt: startTime,
                    completedAt: Date(),
                    durationMinutes: Int(elapsedTime / 60),
                    exercises: exercises,
                    overallRating: nil,
                    notes: nil
                )

                let response = try await APIService.shared.logWorkoutSession(sessionRequest)

                await MainActor.run {
                    isSaving = false
                    clearSavedState()
                    HapticsManager.shared.success()
                    completion(response.prsAchieved)
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    HapticsManager.shared.error()
                    startTimer()
                    let message = (error as? APIError)?.message ?? "Could not save your workout. Please check your connection and try again."
                    print("Failed to save workout: \(error)")
                    onError?(message)
                }
            }
        }
    }

    // MARK: - Live Activity

    private var activeExerciseIndex: Int {
        exerciseLogs.firstIndex { !$0.isCompleted } ?? 0
    }

    private var liveActivityState: StrengthWorkoutAttributes.ContentState {
        let activeExercise = exerciseLogs.first { !$0.isCompleted } ?? exerciseLogs.first
        let name = activeExercise?.name ?? (workout.workoutName ?? "Workout")
        let completedSets = activeExercise?.sets.filter { $0.completedAt != nil }.count ?? 0
        let totalSets = max(activeExercise?.sets.count ?? 1, 1)
        return StrengthWorkoutAttributes.ContentState(
            timerDate: startTime,
            currentExerciseName: name,
            currentSetNumber: min(completedSets + 1, totalSets),
            totalSets: totalSets,
            isResting: isResting,
            restEndDate: restEndDate
        )
    }

    func startResting(duration: Int) {
        isResting = true
        restEndDate = Date().addingTimeInterval(TimeInterval(duration))
        updateLiveActivity()
        scheduleRestEndNotification(in: duration)
    }

    func stopResting() {
        guard isResting else { return }
        isResting = false
        restEndDate = nil
        updateLiveActivity()
        cancelRestEndNotification()
    }

    private func scheduleRestEndNotification(in seconds: Int) {
        let nextExercise = exerciseLogs.first(where: { !$0.isCompleted })?.name ?? "next set"
        let content = UNMutableNotificationContent()
        content.title = "Time to go!"
        content.body = "Rest complete — \(nextExercise) is ready."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: "restTimer", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelRestEndNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["restTimer"])
    }

    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = StrengthWorkoutAttributes(workoutName: workout.workoutName ?? "Workout")
        do {
            strengthActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: liveActivityState, staleDate: nil),
                pushType: nil
            )
        } catch {
            // Live Activities unavailable (simulator or not supported)
        }
    }

    private func updateLiveActivity() {
        let state = liveActivityState
        if let activity = strengthActivity {
            Task { [activity] in
                await activity.update(.init(state: state, staleDate: nil))
            }
        }
        WatchConnectivityService.shared.sendWorkoutState(
            exerciseName: state.currentExerciseName,
            exerciseIndex: activeExerciseIndex,
            setNumber: state.currentSetNumber,
            totalSets: state.totalSets,
            isResting: state.isResting,
            restEndDate: state.restEndDate,
            isActive: true
        )
    }

    private func endLiveActivity() {
        WatchConnectivityService.shared.sendWorkoutEnded()
        guard let activity = strengthActivity else { return }
        strengthActivity = nil
        let finalState = liveActivityState
        Task { [activity] in
            await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(10)))
        }
    }

    // MARK: - Offline Persistence

    private var saveURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("active_workout.json")
    }

    private func checkForInterruption() {
        guard let data = try? Data(contentsOf: saveURL),
              let state = try? JSONDecoder().decode(ActiveWorkoutState.self, from: data)
        else { return }

        exerciseLogs = state.exercises.map { saved in
            let sets = saved.sets.map { s in
                SetLogEntry(weight: s.weight, reps: s.reps, duration: s.duration,
                            distance: s.distance, rpe: s.rpe)
            }
            return ExerciseLogEntry(
                name: saved.name,
                isKeyLift: saved.isKeyLift,
                inputType: saved.inputType,
                targetSetsReps: saved.targetSetsReps,
                sets: sets,
                isCompleted: saved.isCompleted
            )
        }
        wasInterrupted = true
    }

    private func autoSave() {
        let savedExercises = exerciseLogs.map { ex in
            SavedExerciseLog(
                name: ex.name,
                isKeyLift: ex.isKeyLift,
                inputType: ex.inputType,
                targetSetsReps: ex.targetSetsReps,
                sets: ex.sets.map { s in
                    SavedSetLog(weight: s.weight, reps: s.reps, duration: s.duration,
                                distance: s.distance, rpe: s.rpe)
                },
                isCompleted: ex.isCompleted
            )
        }
        let state = ActiveWorkoutState(
            workoutName: workout.workoutName ?? "Workout",
            exercises: savedExercises,
            startedAt: startTime,
            planId: planId
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: saveURL, options: .atomic)
    }

    func clearSavedState() {
        try? FileManager.default.removeItem(at: saveURL)
        wasInterrupted = false
    }

    func discardSavedWorkout() {
        clearSavedState()
        exerciseLogs = Self.buildExercises(from: workout)
    }
}
