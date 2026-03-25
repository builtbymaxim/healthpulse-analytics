//
//  FreeformFocusCard.swift
//  HealthPulse
//
//  Full-screen card focus mode for freeform strength workouts.
//  One card per set, TabView paging, with "Hit it!" + rest timer.
//

import SwiftUI

// MARK: - Freeform Focus Mode View

struct FreeformFocusModeView: View {
    @Binding var sets: [SetInputState]
    let exercises: [Exercise]
    let suggestions: [String: WeightSuggestion]
    let onSelectExercise: (Int) -> Void
    let onAddSet: () -> Void
    let onFetchSuggestion: (String) -> Void
    let onFinish: () -> Void

    @State private var currentPage = 0
    @State private var showRestTimer = false
    private let startDate = Date()

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $currentPage) {
                ForEach(sets.indices, id: \.self) { index in
                    FreeformSetCard(
                        log: $sets[index],
                        setNumber: index + 1,
                        suggestion: sets[index].exercise.flatMap { suggestions[$0.name] },
                        onSelectExercise: { onSelectExercise(index) },
                        onSuggestionAccept: { weight in
                            sets[index].weightKg = weight
                        },
                        onHitIt: {
                            sets[index].isCompleted = true
                            HapticsManager.shared.success()
                            showRestTimer = true
                        }
                    )
                    .tag(index)
                }

                // End card
                FreeformEndCard(
                    completedCount: sets.filter { $0.isCompleted }.count,
                    totalCount: sets.count,
                    onAddSet: {
                        onAddSet()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            currentPage = sets.count - 1
                        }
                    },
                    onFinish: onFinish
                )
                .tag(sets.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .ignoresSafeArea(edges: .bottom)

            // Elapsed timer
            TimelineView(.periodic(from: startDate, by: 1)) { ctx in
                let elapsed = Int(ctx.date.timeIntervalSince(startDate))
                Text(formatElapsed(elapsed))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }
        }
        .restTimerSheet(isPresented: $showRestTimer, autoStart: true, onComplete: {})
    }

    private func formatElapsed(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Freeform Set Card

private struct FreeformSetCard: View {
    @Binding var log: SetInputState
    let setNumber: Int
    var suggestion: WeightSuggestion?
    let onSelectExercise: () -> Void
    let onSuggestionAccept: (Double?) -> Void
    let onHitIt: () -> Void

    @State private var showWeightPicker = false

    private var isReady: Bool {
        log.weightKg != nil && !log.reps.isEmpty && Int(log.reps) != nil && log.exercise != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Set \(setNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        onSelectExercise()
                    } label: {
                        HStack {
                            if let exercise = log.exercise {
                                Image(systemName: exercise.category.icon)
                                    .foregroundStyle(exercise.category.color)
                                Text(exercise.name)
                                    .font(.title2.bold())
                                    .foregroundStyle(.primary)
                            } else {
                                Image(systemName: "dumbbell")
                                    .foregroundStyle(.secondary)
                                Text("Select Exercise")
                                    .font(.title2.bold())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                // Suggestion
                if let suggestion = suggestion, suggestion.status != "new" {
                    SuggestionHint(suggestion: suggestion) {
                        onSuggestionAccept(suggestion.suggestedWeightKg)
                        HapticsManager.shared.light()
                    }
                }

                // Weight + Reps inputs
                HStack(spacing: 24) {
                    // Weight picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Weight")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button { showWeightPicker = true } label: {
                            HStack(spacing: 6) {
                                Text(log.weightKg.map { w in
                                    w.truncatingRemainder(dividingBy: 1) == 0
                                        ? String(format: "%.0f", w)
                                        : String(format: "%.1f", w)
                                } ?? "—")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundStyle(log.weightKg == nil ? .tertiary : .primary)
                                Text("kg")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                    .alignmentGuide(.bottom) { d in d[.bottom] }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .sheet(isPresented: $showWeightPicker) {
                            WeightInputSelector(weight: $log.weightKg)
                        }
                    }

                    // Reps
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Reps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("0", text: $log.reps)
                            .keyboardType(.numberPad)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .padding(12)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                            .frame(maxWidth: .infinity)
                    }
                }

                // Hit it / Done indicator
                if log.isCompleted {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Set logged")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                } else {
                    Button {
                        onHitIt()
                    } label: {
                        Text(isReady ? "Hit it!" : "Fill in weight & reps")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isReady ? Color.green : Color.secondary.opacity(0.2))
                            .foregroundStyle(isReady ? .white : .secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!isReady)
                }
            }
            .padding(20)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 12)
        .padding(.vertical, 48)
    }
}

// MARK: - End Card

private struct FreeformEndCard: View {
    let completedCount: Int
    let totalCount: Int
    let onAddSet: () -> Void
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("All done?")
                    .font(.title.bold())
                Text("\(completedCount) of \(totalCount) sets logged")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                Button(action: onAddSet) {
                    Label("Add Another Set", systemImage: "plus.circle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.primary.opacity(0.12))
                        .foregroundStyle(AppTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button(action: onFinish) {
                    Text("Save Workout")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.primary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 48)
    }
}
