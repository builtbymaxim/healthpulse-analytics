//
//  WorkoutSessionStore.swift
//  HealthPulse
//
//  Singleton that owns the active WorkoutExecutionViewModel so the timer
//  keeps running while the execution view is minimized (Spotify-style).
//

import Foundation
import Combine

@MainActor
final class WorkoutSessionStore: ObservableObject {
    static let shared = WorkoutSessionStore()
    private init() {}

    @Published private(set) var activeViewModel: WorkoutExecutionViewModel?
    @Published var isPresenting = false

    private var completionHandler: (([PRInfo]) -> Void)?

    var isActive: Bool { activeViewModel != nil }

    // MARK: - Lifecycle

    func startWorkout(workout: TodayWorkoutResponse, planId: UUID?, onComplete: @escaping ([PRInfo]) -> Void) {
        completionHandler = onComplete
        let vm = WorkoutExecutionViewModel(workout: workout, planId: planId)
        activeViewModel = vm
        vm.startTimer()
        isPresenting = true
    }

    func minimize() {
        isPresenting = false
    }

    func restore() {
        guard isActive else { return }
        isPresenting = true
    }

    /// Called when the user successfully saves the workout. Fires the completion
    /// handler (reloads WorkoutTabView) and tears down the session.
    func endWorkout(prs: [PRInfo]) {
        completionHandler?(prs)
        completionHandler = nil
        activeViewModel?.stopTimer()
        activeViewModel = nil
        isPresenting = false
    }

    /// Called when the user discards the workout without saving.
    func cancelWorkout() {
        activeViewModel?.stopTimer()
        activeViewModel?.clearSavedState()
        completionHandler = nil
        activeViewModel = nil
        isPresenting = false
    }
}
