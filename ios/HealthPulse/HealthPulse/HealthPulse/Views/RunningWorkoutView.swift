//
//  RunningWorkoutView.swift
//  HealthPulse
//
//  GPS-based running workout tracker with background execution support.
//  Uses wall-clock timing so elapsed time stays accurate across backgrounding.
//

import ActivityKit
import SwiftUI
import CoreLocation
import Combine

struct RunningWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let onSave: (Workout) -> Void

    @StateObject private var locationManager = RunLocationManager()
    @State private var isRunning = false
    @State private var isPaused = false
    @State private var showStopConfirmation = false
    @State private var isSaving = false

    // Wall-clock based timing
    @State private var runStartDate: Date?
    @State private var totalPausedInterval: TimeInterval = 0
    @State private var pauseStartDate: Date?
    @State private var displayCentiseconds: Int = 0
    @State private var displayTimer: Timer?

    // Live Activity
    @State private var liveActivity: Activity<RunningActivityAttributes>?

    private let workoutPersistence = ActiveWorkoutManager.shared

    var elapsedSeconds: Int { displayCentiseconds / 100 }

    // MARK: - Formatted Display Values

    var formattedTime: String {
        let totalSeconds = displayCentiseconds / 100
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        let centis = displayCentiseconds % 100
        return String(format: "%02d:%02d.%02d", minutes, seconds, centis)
    }

    var formattedDistance: String {
        if locationManager.totalDistance < 1000 {
            return String(format: "%.0f", locationManager.totalDistance)
        }
        return String(format: "%.2f", locationManager.totalDistance / 1000)
    }

    var distanceUnit: String {
        locationManager.totalDistance < 1000 ? "m" : "km"
    }

    var formattedPace: String {
        guard locationManager.totalDistance > 0, elapsedSeconds > 0 else {
            return "--:--"
        }
        let km = locationManager.totalDistance / 1000
        let paceSeconds = Double(elapsedSeconds) / km
        let paceMinutes = Int(paceSeconds) / 60
        let paceSecs = Int(paceSeconds) % 60
        return String(format: "%d:%02d", paceMinutes, paceSecs)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Stats display
                    VStack(spacing: 32) {
                        // Timer - largest element
                        VStack(spacing: 4) {
                            Text("TIME")
                                .font(.caption)
                                .foregroundStyle(.gray)

                            Text(formattedTime)
                                .font(.system(size: 72, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                        }

                        // Distance and Pace
                        HStack(spacing: 48) {
                            VStack(spacing: 4) {
                                Text("DISTANCE")
                                    .font(.caption)
                                    .foregroundStyle(.gray)

                                HStack(alignment: .lastTextBaseline, spacing: 4) {
                                    Text(formattedDistance)
                                        .font(.system(size: 48, weight: .bold, design: .rounded))
                                        .foregroundStyle(.green)

                                    Text(distanceUnit)
                                        .font(.title3)
                                        .foregroundStyle(.gray)
                                }
                            }

                            VStack(spacing: 4) {
                                Text("PACE")
                                    .font(.caption)
                                    .foregroundStyle(.gray)

                                HStack(alignment: .lastTextBaseline, spacing: 4) {
                                    Text(formattedPace)
                                        .font(.system(size: 48, weight: .bold, design: .rounded))
                                        .foregroundStyle(.orange)

                                    Text("/km")
                                        .font(.title3)
                                        .foregroundStyle(.gray)
                                }
                            }
                        }

                        // GPS Status
                        if !isRunning {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(locationManager.hasLocation ? Color.green : Color.orange)
                                    .frame(width: 8, height: 8)

                                Text(locationManager.hasLocation ? "GPS Ready" : "Acquiring GPS...")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                    .padding(.top, 60)

                    Spacer()

                    // Control buttons
                    HStack(spacing: 32) {
                        if !isRunning {
                            // Start button
                            Button {
                                startRun()
                            } label: {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 40))
                                            .foregroundStyle(.white)
                                    )
                            }
                        } else {
                            // Pause/Resume button
                            Button {
                                if isPaused {
                                    resumeRun()
                                } else {
                                    pauseRun()
                                }
                            } label: {
                                Circle()
                                    .fill(isPaused ? Color.green : Color.orange)
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                                            .font(.system(size: 32))
                                            .foregroundStyle(.white)
                                    )
                            }

                            // Stop button
                            Button {
                                pauseRun()  // Pause timer while showing dialog
                                showStopConfirmation = true
                            } label: {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Image(systemName: "stop.fill")
                                            .font(.system(size: 32))
                                            .foregroundStyle(.white)
                                    )
                            }
                        }
                    }
                    .padding(.bottom, 60)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if isRunning {
                            pauseRun()  // Pause timer while showing dialog
                            showStopConfirmation = true
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                    }
                }
            }
            .confirmationDialog("End Run?", isPresented: $showStopConfirmation) {
                Button("Save Run", role: .none) {
                    finishRun()
                }
                Button("Discard", role: .destructive) {
                    discardRun()
                }
                Button("Continue Running", role: .cancel) {
                    resumeRun()
                }
            } message: {
                Text("Do you want to save this run?")
            }
            .onAppear {
                locationManager.requestPermission()
                restoreWorkoutIfNeeded()
            }
            .onDisappear {
                stopDisplayTimer()
                locationManager.stopTracking()
            }
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhaseChange(to: newPhase)
            }
            .onChange(of: locationManager.totalDistance) { _, _ in
                updateLiveActivity()
            }
            .overlay {
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.6)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)

                            Text("Saving run...")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Wall-Clock Elapsed Time

    private func computeElapsedCentiseconds() -> Int {
        guard let start = runStartDate else { return 0 }
        var elapsed = Date().timeIntervalSince(start) - totalPausedInterval
        if isPaused, let pauseStart = pauseStartDate {
            elapsed -= Date().timeIntervalSince(pauseStart)
        }
        return max(0, Int(elapsed * 100))
    }

    // MARK: - Scene Phase Handling

    private func handleScenePhaseChange(to phase: ScenePhase) {
        guard isRunning else { return }

        switch phase {
        case .background:
            stopDisplayTimer()
            persistState()

        case .active:
            displayCentiseconds = computeElapsedCentiseconds()
            if !isPaused {
                startDisplayTimer()
            }

        default:
            break
        }
    }

    // MARK: - Persistence

    private func persistState() {
        workoutPersistence.saveState(
            totalPausedInterval: totalPausedInterval,
            pauseStartDate: pauseStartDate,
            totalDistance: locationManager.totalDistance,
            isPaused: isPaused
        )
    }

    private func restoreWorkoutIfNeeded() {
        guard workoutPersistence.isWorkoutActive,
              let startDate = workoutPersistence.runStartDate else { return }

        runStartDate = startDate
        totalPausedInterval = workoutPersistence.totalPausedInterval
        isPaused = workoutPersistence.isPaused
        pauseStartDate = workoutPersistence.pauseStartDate
        locationManager.totalDistance = workoutPersistence.totalDistance
        isRunning = true

        displayCentiseconds = computeElapsedCentiseconds()

        if !isPaused {
            startDisplayTimer()
            locationManager.startTracking()
        }
    }

    // MARK: - Actions

    private func startRun() {
        let now = Date()
        isRunning = true
        isPaused = false
        runStartDate = now
        totalPausedInterval = 0
        pauseStartDate = nil
        displayCentiseconds = 0
        locationManager.startTracking()
        startDisplayTimer()

        workoutPersistence.startWorkout(startDate: now)
        startLiveActivity()
        HapticsManager.shared.heavy()
    }

    private func pauseRun() {
        isPaused = true
        pauseStartDate = Date()
        stopDisplayTimer()
        displayCentiseconds = computeElapsedCentiseconds()
        locationManager.pauseTracking()
        persistState()
        updateLiveActivity()
        HapticsManager.shared.medium()
    }

    private func resumeRun() {
        if let pauseStart = pauseStartDate {
            totalPausedInterval += Date().timeIntervalSince(pauseStart)
        }
        isPaused = false
        pauseStartDate = nil
        startDisplayTimer()
        locationManager.resumeTracking()
        persistState()
        updateLiveActivity()
        HapticsManager.shared.medium()
    }

    private func finishRun() {
        stopDisplayTimer()
        locationManager.stopTracking()
        isRunning = false
        isSaving = true
        endLiveActivity()

        let finalCentiseconds = computeElapsedCentiseconds()
        let finalSeconds = finalCentiseconds / 100

        // Estimate calories: ~60 cal per km for running
        let distanceKm = locationManager.totalDistance / 1000
        let estimatedCalories = distanceKm * 60

        // Create workout
        let workout = Workout(
            id: UUID(),
            userId: UUID(),
            workoutType: .running,
            startedAt: runStartDate ?? Date().addingTimeInterval(-Double(finalSeconds)),
            durationMinutes: max(finalSeconds / 60, 1),
            intensity: .moderate,
            caloriesBurned: estimatedCalories > 0 ? estimatedCalories : nil,
            notes: distanceKm > 0 ? String(format: "%.2f km", distanceKm) : nil,
            createdAt: Date()
        )

        workoutPersistence.clearWorkout()

        // Save to API
        Task {
            do {
                _ = try await APIService.shared.logWorkout(workout)
                await MainActor.run {
                    isSaving = false
                    HapticsManager.shared.success()
                    onSave(workout)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    HapticsManager.shared.error()
                    ToastManager.shared.error("Failed to save run: \(error.localizedDescription)")
                    // Still call onSave with local data and dismiss
                    onSave(workout)
                    dismiss()
                }
            }
        }
    }

    private func discardRun() {
        stopDisplayTimer()
        locationManager.stopTracking()
        isRunning = false
        workoutPersistence.clearWorkout()
        endLiveActivity()
        HapticsManager.shared.warning()
        dismiss()
    }

    // MARK: - Live Activity

    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = RunningActivityAttributes.ContentState(
            distanceMeters: 0,
            paceFormatted: "--:--",
            isPaused: false,
            timerDate: Date(),
            pausedElapsedSeconds: 0
        )
        let content = ActivityContent(state: state, staleDate: nil)

        do {
            liveActivity = try Activity.request(
                attributes: RunningActivityAttributes(),
                content: content,
                pushType: nil
            )
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    private func updateLiveActivity() {
        guard let activity = liveActivity else { return }

        let elapsedInterval = Double(computeElapsedCentiseconds()) / 100.0

        let state = RunningActivityAttributes.ContentState(
            distanceMeters: locationManager.totalDistance,
            paceFormatted: formattedPace,
            isPaused: isPaused,
            timerDate: Date().addingTimeInterval(-elapsedInterval),
            pausedElapsedSeconds: isPaused ? Int(elapsedInterval) : 0
        )
        let content = ActivityContent(state: state, staleDate: nil)

        Task {
            await activity.update(content)
        }
    }

    private func endLiveActivity() {
        guard let activity = liveActivity else { return }

        let elapsedInterval = Double(computeElapsedCentiseconds()) / 100.0

        let state = RunningActivityAttributes.ContentState(
            distanceMeters: locationManager.totalDistance,
            paceFormatted: formattedPace,
            isPaused: true,
            timerDate: Date(),
            pausedElapsedSeconds: Int(elapsedInterval)
        )
        let content = ActivityContent(state: state, staleDate: nil)

        Task {
            await activity.end(content, dismissalPolicy: .immediate)
        }
        liveActivity = nil
    }

    // MARK: - Display Timer

    private func startDisplayTimer() {
        stopDisplayTimer()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let start = runStartDate else { return }
            var elapsed = Date().timeIntervalSince(start) - totalPausedInterval
            if isPaused, let pauseStart = pauseStartDate {
                elapsed -= Date().timeIntervalSince(pauseStart)
            }
            displayCentiseconds = max(0, Int(elapsed * 100))
        }
    }

    private func stopDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }
}

// MARK: - Location Manager for Running

class RunLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var locationManager: CLLocationManager!

    @Published var totalDistance: Double = 0 // in meters
    @Published var hasLocation = false

    private var lastLocation: CLLocation?
    private var isTracking = false

    override init() {
        super.init()
        let setup = {
            self.locationManager = CLLocationManager()
            self.locationManager.delegate = self
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
            self.locationManager.distanceFilter = 5 // Update every 5 meters
            self.locationManager.allowsBackgroundLocationUpdates = true
            self.locationManager.showsBackgroundLocationIndicator = true
            self.locationManager.pausesLocationUpdatesAutomatically = false
            self.locationManager.activityType = .fitness
        }
        if Thread.isMainThread {
            setup()
        } else {
            DispatchQueue.main.sync { setup() }
        }
    }

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func startTracking() {
        totalDistance = 0
        lastLocation = nil
        isTracking = true
        locationManager.startUpdatingLocation()
    }

    func pauseTracking() {
        isTracking = false
    }

    func resumeTracking() {
        isTracking = true
        lastLocation = nil // Don't count distance while paused
    }

    func stopTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isTracking, let newLocation = locations.last else { return }

        // Filter out inaccurate readings
        guard newLocation.horizontalAccuracy < 20 else {
            // Still mark that we have a location (even if inaccurate)
            DispatchQueue.main.async { self.hasLocation = true }
            return
        }

        let last = lastLocation

        DispatchQueue.main.async {
            self.lastLocation = newLocation
            self.hasLocation = true

            if let last = last {
                let distance = newLocation.distance(from: last)
                // Only add if reasonable (prevents GPS jumps)
                if distance < 100 {
                    self.totalDistance += distance
                    // Persist distance on each GPS update (critical for background)
                    let persistence = ActiveWorkoutManager.shared
                    persistence.saveState(
                        totalPausedInterval: persistence.totalPausedInterval,
                        pauseStartDate: persistence.pauseStartDate,
                        totalDistance: self.totalDistance,
                        isPaused: persistence.isPaused
                    )
                }
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            DispatchQueue.main.async { self.hasLocation = false }
            locationManager.startUpdatingLocation()
        default:
            break
        }
    }
}

#Preview {
    RunningWorkoutView { _ in }
}
