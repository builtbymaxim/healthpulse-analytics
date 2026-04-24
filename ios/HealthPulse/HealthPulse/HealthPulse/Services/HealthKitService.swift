//
//  HealthKitService.swift
//  HealthPulse
//
//  HealthKit integration for reading health data
//

import Foundation
import HealthKit
import Combine

struct SleepStageHours {
    let total: Double   // deep + rem + core (excludes awake periods)
    let deep: Double
    let rem: Double
    let core: Double    // light/core sleep
    let awake: Double
}

@MainActor
class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    @Published var isAuthorized = false
    @Published var todaySteps: Int = 0
    @Published var todayCalories: Double = 0
    @Published var restingHeartRate: Double?
    @Published var hrv: Double?
    @Published var lastSleepHours: Double?
    @Published var sleepStageHours: SleepStageHours?

    // Additional health data
    @Published var bodyMass: Double?
    @Published var todayDistance: Double = 0
    @Published var vo2Max: Double?
    @Published var respiratoryRate: Double?
    @Published var oxygenSaturation: Double?
    @Published var basalEnergyBurned: Double?

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
            .distanceCycling,
            .vo2Max,
            .respiratoryRate,
            .oxygenSaturation,
            .basalEnergyBurned
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

    private static let authKey = "healthkit_authorized"

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
                UserDefaults.standard.set(true, forKey: Self.authKey)
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

        // HKHealthStore doesn't expose read-only auth status, so we persist
        // our own flag after a successful requestAuthorization().
        if UserDefaults.standard.bool(forKey: Self.authKey) {
            isAuthorized = true
            // Validate by attempting a lightweight query
            Task {
                await validateAuthorization()
            }
        }
    }

    private func validateAuthorization() async {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, error in
                Task { @MainActor [weak self] in
                    if error != nil && result == nil {
                        // Authorization was revoked
                        self?.isAuthorized = false
                        UserDefaults.standard.set(false, forKey: Self.authKey)
                    }
                }
                cont.resume()
            }
            healthStore.execute(query)
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
            group.addTask { await self.fetchBodyMass() }
            group.addTask { await self.fetchTodayDistance() }
            group.addTask { await self.fetchVO2Max() }
            group.addTask { await self.fetchRespiratoryRate() }
            group.addTask { await self.fetchOxygenSaturation() }
            group.addTask { await self.fetchBasalEnergyBurned() }
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

        let now = Date()
        // 72-hour lookback: 36h captures typical overnight recording, doubled to catch
        // sporadic trackers who skip nights (Oura/Whoop/AutoSleep users).
        let windowStart = now.addingTimeInterval(-72 * 3600)

        let predicate = HKQuery.predicateForSamples(
            withStart: windowStart,
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

            // Accumulate each sleep stage separately.
            var deepSleep: TimeInterval = 0
            var remSleep: TimeInterval = 0
            var coreSleep: TimeInterval = 0
            var awakeDuration: TimeInterval = 0
            // Legacy fallback: older watchOS + third-party apps (Oura, Whoop, AutoSleep)
            // emit .asleep (generic) or .inBed instead of the iOS 16+ stage identifiers.
            var legacyAsleep: TimeInterval = 0
            var inBed: TimeInterval = 0

            for sample in samples {
                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                switch sample.value {
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                    deepSleep += duration
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    remSleep += duration
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                    coreSleep += duration
                case HKCategoryValueSleepAnalysis.awake.rawValue:
                    awakeDuration += duration
                case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                    legacyAsleep += duration
                case HKCategoryValueSleepAnalysis.inBed.rawValue:
                    inBed += duration
                default:
                    break
                }
            }

            let stagedSleep = deepSleep + remSleep + coreSleep
            // If no stage-level data, fall back to legacy generic asleep, then inBed as last resort.
            let totalSleep = stagedSleep > 0 ? stagedSleep : (legacyAsleep > 0 ? legacyAsleep : inBed)
            let totalHours = totalSleep / 3600

            await MainActor.run {
                lastSleepHours = totalHours > 0 ? totalHours : nil
                if totalHours > 0 {
                    if stagedSleep > 0 {
                        sleepStageHours = SleepStageHours(
                            total: totalHours,
                            deep: deepSleep / 3600,
                            rem: remSleep / 3600,
                            core: coreSleep / 3600,
                            awake: awakeDuration / 3600
                        )
                    } else {
                        // Legacy data has no stage breakdown — surface total only.
                        sleepStageHours = SleepStageHours(
                            total: totalHours,
                            deep: 0,
                            rem: 0,
                            core: totalHours,
                            awake: 0
                        )
                    }
                } else {
                    sleepStageHours = nil
                }
            }
        } catch {
            print("Failed to fetch sleep: \(error)")
        }
    }

    private func fetchBodyMass() async {
        guard let massType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }
        let mass = await fetchLatestSample(for: massType, unit: HKUnit.gramUnit(with: .kilo))
        await MainActor.run {
            bodyMass = mass
        }
    }

    private func fetchTodayDistance() async {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return }
        let distance = await fetchTodaySum(for: distanceType, unit: .meter())
        await MainActor.run {
            todayDistance = distance / 1000
        }
    }

    private func fetchVO2Max() async {
        guard let vo2Type = HKQuantityType.quantityType(forIdentifier: .vo2Max) else { return }
        let unit = HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo))
        let value = await fetchLatestSample(for: vo2Type, unit: unit)
        await MainActor.run {
            vo2Max = value
        }
    }

    private func fetchRespiratoryRate() async {
        guard let rrType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else { return }
        let value = await fetchLatestSample(for: rrType, unit: HKUnit.count().unitDivided(by: .minute()))
        await MainActor.run {
            respiratoryRate = value
        }
    }

    private func fetchOxygenSaturation() async {
        guard let spO2Type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else { return }
        let value = await fetchLatestSample(for: spO2Type, unit: HKUnit.percent())
        await MainActor.run {
            oxygenSaturation = value
        }
    }

    private func fetchBasalEnergyBurned() async {
        guard let basalType = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) else { return }
        let energy = await fetchTodaySum(for: basalType, unit: .kilocalorie())
        await MainActor.run {
            basalEnergyBurned = energy
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

    // MARK: - Historical Data (for charts)

    enum ChartPeriod {
        case today
        case sevenDays
        case thirtyDays
    }

    struct ChartDataPoint: Identifiable, Codable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    func fetchStepHistory(period: ChartPeriod) async -> [ChartDataPoint] {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return [] }

        let now = Date()
        let calendar = Calendar.current
        let interval: TimeInterval
        let anchorDate: Date

        switch period {
        case .today:
            interval = 3600
            anchorDate = calendar.startOfDay(for: now)
        case .sevenDays:
            interval = 86400
            let oneWeekAgo = now.addingTimeInterval(-7 * 86400)
            anchorDate = calendar.startOfDay(for: oneWeekAgo)
        case .thirtyDays:
            interval = 86400
            let thirtyDaysAgo = now.addingTimeInterval(-30 * 86400)
            anchorDate = calendar.startOfDay(for: thirtyDaysAgo)
        }

        var comps = DateComponents()
        if interval == 3600 {
            comps.hour = 1
        } else {
            comps.day = 1
        }

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: HKQuery.predicateForSamples(withStart: anchorDate, end: now, options: .strictStartDate),
                options: .cumulativeSum,
                anchorDate: anchorDate,
                intervalComponents: comps
            )
            query.initialResultsHandler = { query, results, error in
                guard error == nil, let results = results else {
                    continuation.resume(returning: [])
                    return
                }

                var dataPoints: [ChartDataPoint] = []
                results.enumerateStatistics(from: anchorDate, to: now) { statistics, _ in
                    let steps = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    dataPoints.append(ChartDataPoint(date: statistics.startDate, value: steps))
                }
                continuation.resume(returning: dataPoints)
            }
            healthStore.execute(query)
        }
    }

    func fetchHRVHistory(days: Int) async -> [ChartDataPoint] {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return [] }

        let now = Date()
        let lookbackStart = now.addingTimeInterval(-TimeInterval(days) * 86400)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: HKQuery.predicateForSamples(withStart: lookbackStart, end: now, options: .strictStartDate),
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard error == nil, let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let dataPoints = samples.map { sample in
                    ChartDataPoint(date: sample.startDate, value: sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli)))
                }
                continuation.resume(returning: dataPoints)
            }
            healthStore.execute(query)
        }
    }

    func fetchDistanceHistory(period: ChartPeriod) async -> [ChartDataPoint] {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return [] }

        let now = Date()
        let calendar = Calendar.current
        let interval: TimeInterval
        let anchorDate: Date

        switch period {
        case .today:
            interval = 3600
            anchorDate = calendar.startOfDay(for: now)
        case .sevenDays:
            interval = 86400
            let oneWeekAgo = now.addingTimeInterval(-7 * 86400)
            anchorDate = calendar.startOfDay(for: oneWeekAgo)
        case .thirtyDays:
            interval = 86400
            let thirtyDaysAgo = now.addingTimeInterval(-30 * 86400)
            anchorDate = calendar.startOfDay(for: thirtyDaysAgo)
        }

        var comps = DateComponents()
        if interval == 3600 {
            comps.hour = 1
        } else {
            comps.day = 1
        }

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: distanceType,
                quantitySamplePredicate: HKQuery.predicateForSamples(withStart: anchorDate, end: now, options: .strictStartDate),
                options: .cumulativeSum,
                anchorDate: anchorDate,
                intervalComponents: comps
            )
            query.initialResultsHandler = { query, results, error in
                guard error == nil, let results = results else {
                    continuation.resume(returning: [])
                    return
                }

                var dataPoints: [ChartDataPoint] = []
                results.enumerateStatistics(from: anchorDate, to: now) { statistics, _ in
                    let meters = statistics.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                    dataPoints.append(ChartDataPoint(date: statistics.startDate, value: meters / 1000))
                }
                continuation.resume(returning: dataPoints)
            }
            healthStore.execute(query)
        }
    }
}
