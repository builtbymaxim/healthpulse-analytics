//
//  HealthKitService.swift
//  HealthPulse
//
//  HealthKit integration for reading health data
//

import Foundation
import HealthKit
import Combine

@MainActor
class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    @Published var isAuthorized = false
    @Published var todaySteps: Int = 0
    @Published var todayCalories: Double = 0
    @Published var restingHeartRate: Double?
    @Published var hrv: Double?
    @Published var lastSleepHours: Double?

    private let healthStore = HKHealthStore()

    private let readTypes: Set<HKObjectType> = {
        var types: Set<HKObjectType> = []

        // Quantity types
        let quantityTypes: [HKQuantityTypeIdentifier] = [
            .stepCount,
            .activeEnergyBurned,
            .heartRate,
            .restingHeartRate,
            .heartRateVariabilitySDNN,
            .bodyMass,
            .bodyFatPercentage,
            .distanceWalkingRunning,
            .distanceCycling
        ]

        for type in quantityTypes {
            if let quantityType = HKQuantityType.quantityType(forIdentifier: type) {
                types.insert(quantityType)
            }
        }

        // Category types
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }

        // Workout type
        types.insert(HKObjectType.workoutType())

        return types
    }()

    private init() {
        checkAuthorization()
    }

    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async -> Bool {
        guard isHealthKitAvailable else { return false }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            await MainActor.run {
                isAuthorized = true
            }
            await refreshTodayData()
            return true
        } catch {
            print("HealthKit authorization failed: \(error)")
            return false
        }
    }

    private func checkAuthorization() {
        guard isHealthKitAvailable else { return }

        // Check if we have at least step count authorization
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            let status = healthStore.authorizationStatus(for: stepType)
            isAuthorized = (status == .sharingAuthorized)
        }
    }

    // MARK: - Data Fetching

    func refreshTodayData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchTodaySteps() }
            group.addTask { await self.fetchTodayCalories() }
            group.addTask { await self.fetchRestingHeartRate() }
            group.addTask { await self.fetchHRV() }
            group.addTask { await self.fetchLastSleep() }
        }
    }

    private func fetchTodaySteps() async {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        let steps = await fetchTodaySum(for: stepType, unit: .count())
        await MainActor.run {
            todaySteps = Int(steps)
        }
    }

    private func fetchTodayCalories() async {
        guard let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }

        let calories = await fetchTodaySum(for: calorieType, unit: .kilocalorie())
        await MainActor.run {
            todayCalories = calories
        }
    }

    private func fetchRestingHeartRate() async {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return }

        let hr = await fetchLatestSample(for: hrType, unit: HKUnit.count().unitDivided(by: .minute()))
        await MainActor.run {
            restingHeartRate = hr
        }
    }

    private func fetchHRV() async {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }

        let value = await fetchLatestSample(for: hrvType, unit: .secondUnit(with: .milli))
        await MainActor.run {
            hrv = value
        }
    }

    private func fetchLastSleep() async {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfYesterday,
            end: now,
            options: .strictEndDate
        )

        do {
            let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKCategorySample], Error>) in
                let query = HKSampleQuery(
                    sampleType: sleepType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                ) { _, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: samples as? [HKCategorySample] ?? [])
                    }
                }
                healthStore.execute(query)
            }

            // Calculate total sleep (asleep stages only)
            var totalSleep: TimeInterval = 0
            for sample in samples {
                if sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                   sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                   sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                    totalSleep += sample.endDate.timeIntervalSince(sample.startDate)
                }
            }

            let hours = totalSleep / 3600
            await MainActor.run {
                lastSleepHours = hours > 0 ? hours : nil
            }
        } catch {
            print("Failed to fetch sleep: \(error)")
        }
    }

    // MARK: - Helpers

    private func fetchTodaySum(for type: HKQuantityType, unit: HKUnit) async -> Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )

        do {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double, Error>) in
                let query = HKStatisticsQuery(
                    quantityType: type,
                    quantitySamplePredicate: predicate,
                    options: .cumulativeSum
                ) { _, statistics, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        let sum = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                        continuation.resume(returning: sum)
                    }
                }
                healthStore.execute(query)
            }
            return result
        } catch {
            print("Failed to fetch sum for \(type): \(error)")
            return 0
        }
    }

    private func fetchLatestSample(for type: HKQuantityType, unit: HKUnit) async -> Double? {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        do {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double?, Error>) in
                let query = HKSampleQuery(
                    sampleType: type,
                    predicate: nil,
                    limit: 1,
                    sortDescriptors: [sortDescriptor]
                ) { _, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let sample = samples?.first as? HKQuantitySample {
                        continuation.resume(returning: sample.quantity.doubleValue(for: unit))
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
                healthStore.execute(query)
            }
            return result
        } catch {
            print("Failed to fetch latest sample for \(type): \(error)")
            return nil
        }
    }
}
