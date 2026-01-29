//
//  LogView.swift
//  HealthPulse
//
//  Quick logging view for metrics and workouts
//

import SwiftUI

struct LogView: View {
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack {
                Picker("Log Type", selection: $selectedTab) {
                    Text("Check-in").tag(0)
                    Text("Workout").tag(1)
                    Text("Metric").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                TabView(selection: $selectedTab) {
                    DailyCheckinView()
                        .tag(0)

                    WorkoutLogView()
                        .tag(1)

                    MetricLogView()
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Log")
        }
    }
}

// MARK: - Daily Check-in

struct DailyCheckinView: View {
    @State private var energy: Double = 7
    @State private var mood: Double = 7
    @State private var stress: Double = 4
    @State private var sleepHours: Double = 7.5
    @State private var sleepQuality: Double = 7
    @State private var soreness: Double = 3
    @State private var isSubmitting = false
    @State private var showSuccess = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("How are you feeling today?")
                    .font(.headline)

                VStack(spacing: 20) {
                    SliderRow(title: "Energy", value: $energy, icon: "bolt.fill", color: .yellow)
                    SliderRow(title: "Mood", value: $mood, icon: "face.smiling.fill", color: .green)
                    SliderRow(title: "Stress", value: $stress, icon: "brain.head.profile", color: .red)
                }

                Divider()

                VStack(spacing: 20) {
                    HStack {
                        Text("Sleep")
                            .font(.headline)
                        Spacer()
                        Text("\(sleepHours, specifier: "%.1f") hours")
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $sleepHours, in: 0...12, step: 0.5)
                        .tint(.purple)

                    SliderRow(title: "Sleep Quality", value: $sleepQuality, icon: "bed.double.fill", color: .purple)
                }

                Divider()

                SliderRow(title: "Muscle Soreness", value: $soreness, icon: "figure.run", color: .orange)

                Button {
                    submitCheckin()
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Submit Check-in")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(isSubmitting)

                Spacer(minLength: 40)
            }
            .padding()
        }
        .alert("Check-in Saved", isPresented: $showSuccess) {
            Button("OK") { }
        }
    }

    private func submitCheckin() {
        isSubmitting = true
        // TODO: Submit to API
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isSubmitting = false
            showSuccess = true
        }
    }
}

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                Spacer()
                Text("\(Int(value))")
                    .fontWeight(.semibold)
            }

            Slider(value: $value, in: 1...10, step: 1)
                .tint(color)
        }
    }
}

// MARK: - Workout Log

struct WorkoutLogView: View {
    @State private var workoutType: WorkoutType = .running
    @State private var duration: Double = 45
    @State private var intensity: Intensity = .moderate
    @State private var notes = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Workout Type
                VStack(alignment: .leading, spacing: 12) {
                    Text("Workout Type")
                        .font(.headline)

                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 70))
                    ], spacing: 12) {
                        ForEach(WorkoutType.allCases, id: \.self) { type in
                            WorkoutTypeButton(
                                type: type,
                                isSelected: workoutType == type
                            ) {
                                workoutType = type
                            }
                        }
                    }
                }

                Divider()

                // Duration
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Duration")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(duration)) min")
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $duration, in: 5...180, step: 5)
                        .tint(.green)
                }

                Divider()

                // Intensity
                VStack(alignment: .leading, spacing: 12) {
                    Text("Intensity")
                        .font(.headline)

                    Picker("Intensity", selection: $intensity) {
                        ForEach(Intensity.allCases, id: \.self) { level in
                            Text(level.rawValue.capitalized).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Divider()

                // Notes
                VStack(alignment: .leading, spacing: 12) {
                    Text("Notes")
                        .font(.headline)

                    TextField("How did it feel?", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    submitWorkout()
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Log Workout")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(isSubmitting)

                Spacer(minLength: 40)
            }
            .padding()
        }
        .alert("Workout Logged", isPresented: $showSuccess) {
            Button("OK") { }
        }
    }

    private func submitWorkout() {
        isSubmitting = true
        // TODO: Submit to API
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isSubmitting = false
            showSuccess = true
        }
    }
}

struct WorkoutTypeButton: View {
    let type: WorkoutType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.title2)
                Text(type.displayName)
                    .font(.caption2)
            }
            .frame(width: 70, height: 60)
            .background(isSelected ? Color.green.opacity(0.2) : Color(.secondarySystemBackground))
            .foregroundStyle(isSelected ? .green : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Metric Log

struct MetricLogView: View {
    @State private var metricType: MetricType = .weight
    @State private var value: String = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false

    let manualMetrics: [MetricType] = [.weight, .bodyFat, .water, .caffeine, .stress, .mood, .energy]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Metric Type")
                        .font(.headline)

                    Picker("Metric", selection: $metricType) {
                        ForEach(manualMetrics, id: \.self) { type in
                            Text(type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Value")
                        .font(.headline)

                    HStack {
                        TextField("Enter value", text: $value)
                            .keyboardType(.decimalPad)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Text(unitForMetric)
                            .foregroundStyle(.secondary)
                            .frame(width: 50)
                    }
                }

                Button {
                    submitMetric()
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Log Metric")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(value.isEmpty ? Color.gray : Color.green)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(value.isEmpty || isSubmitting)

                Spacer()
            }
            .padding()
        }
        .alert("Metric Logged", isPresented: $showSuccess) {
            Button("OK") {
                value = ""
            }
        }
    }

    private var unitForMetric: String {
        switch metricType {
        case .weight: return "kg"
        case .bodyFat: return "%"
        case .water: return "ml"
        case .caffeine: return "mg"
        default: return ""
        }
    }

    private func submitMetric() {
        isSubmitting = true
        // TODO: Submit to API
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isSubmitting = false
            showSuccess = true
        }
    }
}

#Preview {
    LogView()
}
