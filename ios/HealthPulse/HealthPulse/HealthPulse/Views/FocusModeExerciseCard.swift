//
//  FocusModeExerciseCard.swift
//  HealthPulse
//
//  Full-screen card for a single exercise in Focus Mode.
//  Reuses SetLogRow for input consistency with list mode.
//

import SwiftUI

struct FocusModeExerciseCard: View {
    @Binding var log: ExerciseLogEntry
    let viewModel: WorkoutExecutionViewModel
    let exerciseIndex: Int

    @State private var showRestTimer = false
    @State private var showRPEInfo = false
    @State private var completedSetIndex: Int?

    // Key lifts rest 3 min, accessories rest 90 s
    private var defaultRestDuration: Int { log.isKeyLift ? 180 : 90 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                cardHeader
                if let suggestion = log.suggestion {
                    SuggestionHint(suggestion: suggestion, onTap: {})
                }
                columnHeaders
                setList
                addSetButton
                markDoneButton
            }
            .padding(20)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .restTimerSheet(
            isPresented: $showRestTimer,
            defaultDuration: defaultRestDuration,
            autoStart: true,
            onComplete: { viewModel.stopResting() }
        )
        .onChange(of: showRestTimer) { _, isShowing in
            if isShowing {
                viewModel.startResting(duration: defaultRestDuration)
            }
            // stopResting() is called via onComplete (skip or timer end), not on sheet dismiss,
            // so that minimizing the workout preserves rest state in the mini-player.
        }
        .sheet(isPresented: $showRPEInfo) {
            RPEInfoSheet()
        }
    }

    // MARK: - Subviews

    private var formattedElapsed: String {
        let t = Int(viewModel.elapsedTime)
        let h = t / 3600, m = (t % 3600) / 60, s = t % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    private var cardHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(log.name)
                    .font(.title2.bold())
                if log.isKeyLift {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
                Spacer()
                Text(formattedElapsed)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            if let target = log.targetSetsReps {
                Text(target)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // Dynamic column headers (mirrors ExerciseLogCard pattern)
    private var columnHeaders: some View {
        HStack {
            Text("Set")
                .frame(width: 35, alignment: .leading)

            switch log.inputType {
            case .weightAndReps:
                Text("Weight")
                    .frame(width: 80)
                Text("Reps")
                    .frame(width: 60)
                rpeHeaderWithInfo

            case .repsOnly:
                Text("Reps")
                    .frame(width: 60)
                rpeHeaderWithInfo

            case .timeOnly:
                Text("Duration")
                    .frame(width: 80)

            case .distanceAndTime:
                Text("Distance")
                    .frame(width: 80)
                Text("Time")
                    .frame(width: 80)
            }

            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var rpeHeaderWithInfo: some View {
        HStack(spacing: 2) {
            Text("RPE")
            Button {
                showRPEInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.caption2)
            }
        }
        .frame(width: 50)
    }

    private var setList: some View {
        VStack(spacing: 4) {
            ForEach(log.sets.indices, id: \.self) { setIndex in
                let isCompleted = log.sets[setIndex].completedAt != nil
                HStack(spacing: 0) {
                    // Green left border for completed sets
                    if isCompleted {
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: 3)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }

                    HStack(spacing: 8) {
                        SetLogRow(
                            setNumber: setIndex + 1,
                            setLog: $log.sets[setIndex],
                            inputType: log.inputType,
                            onDelete: { viewModel.deleteSet(from: exerciseIndex, setIndex: setIndex) }
                        )
                        setActionButton(setIndex: setIndex)
                    }
                    .padding(10)
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                .scaleEffect(completedSetIndex == setIndex ? 0.92 : 1.0)
                .animation(MotionTokens.snappy, value: completedSetIndex)
            }
        }
    }

    @ViewBuilder
    private func setActionButton(setIndex: Int) -> some View {
        let set = log.sets[setIndex]
        let isCompleted = set.completedAt != nil
        let isReady = setIsReady(set)

        if isCompleted {
            Button {
                viewModel.markSetCompleted(exerciseIndex: exerciseIndex, setIndex: setIndex)
                HapticsManager.shared.selection()
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            }
        } else if isReady {
            Button {
                viewModel.markSetCompleted(exerciseIndex: exerciseIndex, setIndex: setIndex)
                HapticsManager.shared.success()
                // Bounce animation then delayed rest timer
                completedSetIndex = setIndex
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    completedSetIndex = nil
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showRestTimer = true
                }
            } label: {
                Text("Hit it!")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.green, in: Capsule())
            }
        } else {
            Button {
                viewModel.markSetCompleted(exerciseIndex: exerciseIndex, setIndex: setIndex)
                HapticsManager.shared.selection()
            } label: {
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            }
        }
    }

    private func setIsReady(_ set: SetLogEntry) -> Bool {
        switch log.inputType {
        case .weightAndReps:  return (set.weight ?? 0) > 0 && (set.reps ?? 0) > 0
        case .repsOnly:       return (set.reps ?? 0) > 0
        case .timeOnly:       return (set.duration ?? 0) > 0
        case .distanceAndTime: return (set.distance ?? 0) > 0 || (set.duration ?? 0) > 0
        }
    }

    private var addSetButton: some View {
        Button {
            viewModel.addSet(to: exerciseIndex)
        } label: {
            Label("Add Set", systemImage: "plus.circle")
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        }
        .foregroundStyle(.primary)
    }

    private var markDoneButton: some View {
        Button {
            viewModel.toggleExerciseCompleted(exerciseIndex)
            HapticsManager.shared.medium()
        } label: {
            Text(log.isCompleted ? "Mark Incomplete" : "Mark Exercise Done")
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(
                    log.isCompleted
                        ? Color.secondary.opacity(0.15)
                        : AppTheme.primary.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 10)
                )
        }
        .foregroundStyle(log.isCompleted ? .secondary : AppTheme.primary)
    }
}
