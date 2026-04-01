//
//  WatchHealthKitManager.swift
//  HealthPulseWatch
//
//  Manages an HKWorkoutSession + HKLiveWorkoutBuilder on the Watch for native
//  calorie/HR tracking during strength workouts.
//
//  SETUP (Xcode required):
//    - Add HealthKit capability to the Watch target (Signing & Capabilities)
//    - Add NSHealthShareUsageDescription + NSHealthUpdateUsageDescription to Watch Info.plist
//    - Add HealthPulseWatch.entitlements with com.apple.developer.healthkit = true
//

import Foundation
import HealthKit
import Combine

@MainActor
class WatchHealthKitManager: NSObject, ObservableObject {
    static let shared = WatchHealthKitManager()

    @Published var currentHeartRate: Double? = nil
    @Published var activeCalories: Double = 0
    @Published var isAuthorized = false

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    private override init() {
        super.init()
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let share: Set<HKSampleType> = [
            HKQuantityType(.activeEnergyBurned),
            HKObjectType.workoutType()
        ]
        let read: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned)
        ]
        do {
            try await store.requestAuthorization(toShare: share, read: read)
            isAuthorized = true
        } catch {
            print("[WatchHK] Authorization failed: \(error)")
        }
    }

    // MARK: - Session Lifecycle

    func startSession() {
        guard isAuthorized, session == nil else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor
        do {
            let newSession = try HKWorkoutSession(healthStore: store, configuration: config)
            let newBuilder = newSession.associatedWorkoutBuilder()
            newBuilder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)
            newSession.delegate = self
            newBuilder.delegate = self
            session = newSession
            builder = newBuilder
            newSession.startActivity(with: Date())
            newBuilder.beginCollection(withStart: Date()) { _, _ in }
        } catch {
            print("[WatchHK] Session start failed: \(error)")
        }
    }

    func endSession() {
        guard let session else { return }
        session.end()
        builder?.endCollection(withEnd: Date()) { [weak self] _, _ in
            self?.builder?.finishWorkout { _, _ in }
        }
        self.session = nil
        self.builder = nil
        currentHeartRate = nil
        activeCalories = 0
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WatchHealthKitManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {}

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        print("[WatchHK] Session error: \(error)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchHealthKitManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate),
               collectedTypes.contains(hrType) {
                let stat = workoutBuilder.statistics(for: hrType)
                let bpm = stat?.mostRecentQuantity()?.doubleValue(for: .count().unitDivided(by: .minute()))
                self.currentHeartRate = bpm
            }
            if let calType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
               collectedTypes.contains(calType) {
                let stat = workoutBuilder.statistics(for: calType)
                let kcal = stat?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                self.activeCalories = kcal
            }
        }
    }
}
