//
//  WatchHapticsManager.swift
//  HealthPulseWatch
//
//  Haptic feedback for workout events on the Watch.
//  Monitors restEndDate to fire a notification haptic when rest ends.
//

import WatchKit
import SwiftUI
import Combine

@MainActor
class WatchHapticsManager: ObservableObject {
    static let shared = WatchHapticsManager()
    private var restCheckTimer: Timer?
    private var monitoredEndDate: Date?

    private init() {}

    // MARK: - Direct feedback

    func restEnded()     { WKInterfaceDevice.current().play(.notification) }
    func setCompleted()  { WKInterfaceDevice.current().play(.success) }
    func workoutStarted(){ WKInterfaceDevice.current().play(.start) }
    func workoutEnded()  { WKInterfaceDevice.current().play(.stop) }

    // MARK: - Rest end monitoring

    /// Start monitoring a rest end date — fires a haptic when the date passes.
    func startMonitoring(restEndDate: Date) {
        stopMonitoring()
        monitoredEndDate = restEndDate
        let remaining = max(restEndDate.timeIntervalSinceNow, 0)
        restCheckTimer = Timer.scheduledTimer(withTimeInterval: remaining + 0.1, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.restEnded()
                self?.monitoredEndDate = nil
            }
        }
    }

    func stopMonitoring() {
        restCheckTimer?.invalidate()
        restCheckTimer = nil
        monitoredEndDate = nil
    }
}
