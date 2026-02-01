//
//  RestTimer.swift
//  HealthPulse
//
//  Rest timer between sets with haptic feedback
//

import SwiftUI
import AudioToolbox

struct RestTimer: View {
    @Binding var isPresented: Bool
    let onComplete: () -> Void

    @State private var selectedDuration: Int = 90
    @State private var remainingSeconds: Int = 90
    @State private var isRunning = false
    @State private var timer: Timer?

    let durations = [60, 90, 120, 180]

    var progress: Double {
        guard selectedDuration > 0 else { return 0 }
        return Double(remainingSeconds) / Double(selectedDuration)
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("Rest Timer")
                    .font(.headline)
                Spacer()
                Button {
                    stopTimer()
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            // Duration presets (only show when not running)
            if !isRunning {
                HStack(spacing: 12) {
                    ForEach(durations, id: \.self) { duration in
                        Button {
                            selectedDuration = duration
                            remainingSeconds = duration
                            HapticsManager.shared.selection()
                        } label: {
                            Text(formatTime(duration))
                                .font(.subheadline.bold())
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedDuration == duration ? Color.green : Color(.secondarySystemBackground))
                                .foregroundStyle(selectedDuration == duration ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // Circular timer
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 12)
                    .frame(width: 200, height: 200)

                // Progress circle
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        remainingSeconds <= 10 ? Color.red : Color.green,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: remainingSeconds)

                // Time display
                VStack(spacing: 4) {
                    Text(formatTime(remainingSeconds))
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    if isRunning {
                        Text("remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 20)

            // Control buttons
            HStack(spacing: 24) {
                if isRunning {
                    // Skip button
                    Button {
                        skipTimer()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "forward.fill")
                                .font(.title2)
                            Text("Skip")
                                .font(.caption)
                        }
                        .foregroundStyle(.orange)
                        .frame(width: 80, height: 60)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Stop button
                    Button {
                        stopTimer()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "stop.fill")
                                .font(.title2)
                            Text("Stop")
                                .font(.caption)
                        }
                        .foregroundStyle(.red)
                        .frame(width: 80, height: 60)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                } else {
                    // Start button
                    Button {
                        startTimer()
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Rest")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 20)
        .onDisappear {
            stopTimer()
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 {
            return String(format: "%d:%02d", mins, secs)
        }
        return String(format: "0:%02d", secs)
    }

    private func startTimer() {
        isRunning = true
        remainingSeconds = selectedDuration
        HapticsManager.shared.medium()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remainingSeconds > 0 {
                remainingSeconds -= 1

                // Haptic feedback at 10, 5, 3, 2, 1 seconds
                if [10, 5, 3, 2, 1].contains(remainingSeconds) {
                    HapticsManager.shared.light()
                }
            } else {
                timerComplete()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        remainingSeconds = selectedDuration
    }

    private func skipTimer() {
        stopTimer()
        HapticsManager.shared.medium()
        onComplete()
        isPresented = false
    }

    private func timerComplete() {
        timer?.invalidate()
        timer = nil
        isRunning = false

        // Strong haptic feedback when timer ends
        HapticsManager.shared.success()

        // Play system sound
        AudioServicesPlaySystemSound(1007) // Standard notification sound

        // Additional haptic after a brief delay for emphasis
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            HapticsManager.shared.heavy()
        }

        onComplete()

        // Auto-dismiss after a moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isPresented = false
        }
    }
}

// MARK: - Rest Timer Sheet Modifier

extension View {
    func restTimerSheet(isPresented: Binding<Bool>, onComplete: @escaping () -> Void) -> some View {
        self.sheet(isPresented: isPresented) {
            RestTimer(isPresented: isPresented, onComplete: onComplete)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    RestTimer(isPresented: .constant(true), onComplete: {})
}
