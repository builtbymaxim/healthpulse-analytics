//
//  RunningWorkoutView.swift
//  HealthPulse
//
//  GPS-based running workout tracker
//

import SwiftUI
import CoreLocation
import Combine

struct RunningWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (Workout) -> Void

    @StateObject private var locationManager = RunLocationManager()
    @State private var isRunning = false
    @State private var isPaused = false
    @State private var elapsedCentiseconds: Int = 0  // Track centiseconds for precision
    @State private var timer: Timer?
    @State private var showStopConfirmation = false
    @State private var isSaving = false

    // For backward compatibility
    var elapsedSeconds: Int { elapsedCentiseconds / 100 }

    // Computed properties
    var formattedTime: String {
        let totalSeconds = elapsedCentiseconds / 100
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let centis = elapsedCentiseconds % 100

        return String(format: "%02d:%02d:%02d", minutes, seconds, centis)
    }

    var formattedDistance: String {
        let km = locationManager.totalDistance / 1000
        return String(format: "%.2f", km)
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

                                    Text("km")
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
                    resumeRun()  // Resume timer after canceling
                }
            } message: {
                Text("Do you want to save this run?")
            }
            .onAppear {
                locationManager.requestPermission()
            }
            .onDisappear {
                stopTimer()
                locationManager.stopTracking()
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

    // MARK: - Actions

    private func startRun() {
        isRunning = true
        isPaused = false
        elapsedCentiseconds = 0
        locationManager.startTracking()
        startTimer()
        HapticsManager.shared.heavy()
    }

    private func pauseRun() {
        isPaused = true
        stopTimer()
        locationManager.pauseTracking()
        HapticsManager.shared.medium()
    }

    private func resumeRun() {
        isPaused = false
        startTimer()
        locationManager.resumeTracking()
        HapticsManager.shared.medium()
    }

    private func finishRun() {
        // Stop tracking immediately
        stopTimer()
        locationManager.stopTracking()
        isRunning = false
        isSaving = true

        // Estimate calories: ~60 cal per km for running
        let distanceKm = locationManager.totalDistance / 1000
        let estimatedCalories = distanceKm * 60

        // Create workout
        let workout = Workout(
            id: UUID(),
            userId: UUID(),
            workoutType: .running,
            startedAt: Date().addingTimeInterval(-Double(elapsedSeconds)),
            durationMinutes: max(elapsedSeconds / 60, 1),
            intensity: .moderate,
            caloriesBurned: estimatedCalories > 0 ? estimatedCalories : nil,
            notes: distanceKm > 0 ? String(format: "%.2f km", distanceKm) : nil,
            createdAt: Date()
        )

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
        stopTimer()
        locationManager.stopTracking()
        HapticsManager.shared.warning()
        dismiss()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            // Only increment if actively running and not paused
            if isRunning && !isPaused {
                elapsedCentiseconds += 1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Location Manager for Running

class RunLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()

    @Published var totalDistance: Double = 0 // in meters
    @Published var hasLocation = false

    private var lastLocation: CLLocation?
    private var isTracking = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5 // Update every 5 meters
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.activityType = .fitness
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

        hasLocation = true

        // Filter out inaccurate readings
        guard newLocation.horizontalAccuracy < 20 else { return }

        if let last = lastLocation {
            let distance = newLocation.distance(from: last)
            // Only add if reasonable (prevents GPS jumps)
            if distance < 100 {
                totalDistance += distance
            }
        }

        lastLocation = newLocation
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            hasLocation = false
            locationManager.startUpdatingLocation()
        default:
            break
        }
    }
}

#Preview {
    RunningWorkoutView { _ in }
}
