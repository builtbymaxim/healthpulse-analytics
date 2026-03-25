//
//  FocusModeView.swift
//  HealthPulse
//
//  Swipeable card-based exercise view shown inside WorkoutExecutionView
//  when Focus Mode is active. Uses TabView(.page) for swipe gestures without
//  conflicting with inner ScrollViews.
//

import SwiftUI

struct FocusModeView: View {
    @ObservedObject var viewModel: WorkoutExecutionViewModel
    let onFinish: () -> Void
    @State private var currentIndex = 0
    @State private var showOverview = false
    @State private var showAddExercise = false
    @State private var undoName: String?
    @State private var undoTarget: Int?

    // MARK: - Progress

    private var progress: Double {
        let completed = viewModel.exerciseLogs.reduce(0) { acc, log in
            if log.isCompleted { return acc + log.sets.count }
            return acc + log.sets.filter { $0.completedAt != nil }.count
        }
        let total = viewModel.exerciseLogs.reduce(0) { $0 + $1.sets.count }
        return total > 0 ? Double(completed) / Double(total) : 0
    }

    private var formattedElapsed: String {
        let t = Int(viewModel.elapsedTime)
        let h = t / 3600, m = (t % 3600) / 60, s = t % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            progressBar

            TabView(selection: $currentIndex) {
                ForEach(viewModel.exerciseLogs.indices, id: \.self) { index in
                    FocusModeExerciseCard(
                        log: $viewModel.exerciseLogs[index],
                        viewModel: viewModel,
                        exerciseIndex: index
                    )
                    .tag(index)
                }
                FocusModeEndCard(
                    canFinish: viewModel.canComplete,
                    onFinish: onFinish,
                    onAddExercise: { showAddExercise = true }
                )
                .tag(viewModel.exerciseLogs.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: currentIndex) { old, new in
                if new > old, old < viewModel.exerciseLogs.count {
                    undoName = viewModel.exerciseLogs[old].name
                    undoTarget = old
                    let capturedOld = old
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        if undoTarget == capturedOld {
                            undoName = nil
                            undoTarget = nil
                        }
                    }
                } else {
                    undoName = nil
                    undoTarget = nil
                }
            }
        }
        .overlay(alignment: .topLeading) {
            // Minimize button — always visible since NavigationBar is shared with list mode
            Button {
                WorkoutSessionStore.shared.minimize()
            } label: {
                Image(systemName: "chevron.down")
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.top, 8)
            .padding(.leading, 12)
        }
        .overlay(alignment: .top) {
            Text(formattedElapsed)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.top, 16)
        }
        .overlay(alignment: .topTrailing) {
            Button { showOverview = true } label: {
                Image(systemName: "list.bullet")
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.top, 8)
            .padding(.trailing, 12)
        }
        .overlay(alignment: .bottom) {
            if let name = undoName, let target = undoTarget {
                undoToast(name: name, target: target)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 16)
            }
        }
        .animation(MotionTokens.micro, value: undoName != nil)
        .sheet(isPresented: $showOverview) {
            FocusModeOverviewSheet(exerciseLogs: viewModel.exerciseLogs) { index in
                withAnimation(MotionTokens.primary) { currentIndex = index }
                showOverview = false
            }
        }
        .sheet(isPresented: $showAddExercise) {
            AddExerciseSheet { name in
                let newIndex = viewModel.exerciseLogs.count
                viewModel.addExercise(name: name)
                withAnimation(MotionTokens.primary) { currentIndex = newIndex }
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.primary.opacity(0.08))
                Rectangle()
                    .fill(AppTheme.primary)
                    .frame(width: geo.size.width * progress)
                    .animation(MotionTokens.ring, value: progress)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Undo Toast

    private func undoToast(name: String, target: Int) -> some View {
        HStack(spacing: 12) {
            Text("Swiped past \(name)")
                .font(.subheadline)
            Button("Undo") {
                withAnimation(MotionTokens.snappy) { currentIndex = target }
                undoName = nil
                undoTarget = nil
            }
            .font(.subheadline.bold())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - End Card

private struct FocusModeEndCard: View {
    let canFinish: Bool
    let onFinish: () -> Void
    let onAddExercise: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 56))
                    .foregroundStyle(AppTheme.primary)

                VStack(spacing: 8) {
                    Text("All done?")
                        .font(.title2.bold())
                    Text("Finish your workout or keep going with more exercises.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button(action: onFinish) {
                    Text("Finish Workout")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canFinish ? AppTheme.primary : Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!canFinish)

                Button(action: onAddExercise) {
                    Label("Add Exercise", systemImage: "plus.circle")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                }
                .foregroundStyle(.primary)
            }
            .padding(24)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Overview Sheet

private struct FocusModeOverviewSheet: View {
    let exerciseLogs: [ExerciseLogEntry]
    let onSelect: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(exerciseLogs.indices, id: \.self) { i in
                    let log = exerciseLogs[i]
                    let doneSets = log.isCompleted
                        ? log.sets.count
                        : log.sets.filter { $0.completedAt != nil }.count
                    Button {
                        onSelect(i)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(log.name)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Text("\(doneSets)/\(log.sets.count) sets")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if log.isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
