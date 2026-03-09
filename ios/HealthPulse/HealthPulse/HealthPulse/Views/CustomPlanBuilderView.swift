//
//  CustomPlanBuilderView.swift
//  HealthPulse
//
//  Custom training plan builder — step-by-step day/exercise configuration.
//

import SwiftUI

// Identifiable wrapper so we can use sheet(item:) with a day-of-week Int
private struct DaySheetItem: Identifiable {
    let id: Int  // dayOfWeek 1–7
}

struct CustomPlanBuilderView: View {
    let onSave: () -> Void
    var prefillPlanId: UUID? = nil

    @StateObject private var viewModel = CustomPlanBuilderViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var editingDayItem: DaySheetItem? = nil
    @State private var errorVisible = false

    private let dayNumbers = Array(1...7)

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ThemedBackground(showGlow: true)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        planNameField
                        daysSection
                        Spacer().frame(height: 90)  // breathing room above sticky CTA
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                saveCTA

                // Pre-fill loading overlay
                if viewModel.isLoading {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    ProgressView("Loading plan…")
                        .foregroundStyle(.white)
                        .tint(.white)
                }
            }
            .navigationTitle("Build Custom Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .sheet(item: $editingDayItem) { item in
                ExerciseSelectionSheet(dayOfWeek: item.id, viewModel: viewModel)
            }
            .alert("Save Failed", isPresented: $errorVisible) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.error ?? "Unknown error.")
            }
            .onChange(of: viewModel.error) { _, err in
                errorVisible = err != nil
            }
            .task(id: prefillPlanId) {
                guard let id = prefillPlanId else { return }
                await viewModel.loadAndPrefill(planId: id)
            }
        }
    }

    // MARK: - Plan Name

    private var planNameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plan Name")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            TextField("e.g. Summer Shred, PPL Split…", text: $viewModel.planName)
                .font(.title3.bold())
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AppTheme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            viewModel.planName.isEmpty ? AppTheme.border : AppTheme.primary.opacity(0.5),
                            lineWidth: 1
                        )
                )
        }
    }

    // MARK: - Days

    private var daysSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Schedule")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Text("Activate a day, then add exercises. Empty days are rest days.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            VStack(spacing: 10) {
                ForEach(dayNumbers, id: \.self) { day in
                    DayCard(
                        dayOfWeek: day,
                        draftDay: viewModel.days[day],
                        onAddExercises: { editingDayItem = DaySheetItem(id: day) },
                        onRemoveExercise: { id in
                            withAnimation(MotionTokens.snappy) {
                                viewModel.removeExercise(id: id, from: day)
                            }
                        },
                        onUpdateExercise: { updated in
                            viewModel.updateExercise(updated, in: day)
                        },
                        onToggleRest: {
                            withAnimation(MotionTokens.form) {
                                viewModel.toggleDay(day)
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Save CTA

    private var saveCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [AppTheme.backgroundDark.opacity(0), AppTheme.backgroundDark],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 24)
            .allowsHitTesting(false)

            Button {
                HapticsManager.shared.medium()
                viewModel.saveCustomPlan {
                    HapticsManager.shared.success()
                    onSave()
                    dismiss()
                }
            } label: {
                ZStack {
                    if viewModel.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Save Plan").font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(viewModel.canSave ? AppTheme.primary : AppTheme.primary.opacity(0.35))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .primaryGlow()
            }
            .disabled(!viewModel.canSave || viewModel.isLoading)
            .buttonStyle(PressEffect())
            .padding(.horizontal)
            .padding(.bottom, 12)
            .background(AppTheme.backgroundDark)
        }
    }
}

// MARK: - Day Card

private struct DayCard: View {
    let dayOfWeek: Int
    let draftDay: DraftDay?
    let onAddExercises: () -> Void
    let onRemoveExercise: (UUID) -> Void
    let onUpdateExercise: (DraftExercise) -> Void
    let onToggleRest: () -> Void

    private var isActive: Bool { draftDay != nil }

    var body: some View {
        VStack(spacing: 0) {
            // Day header row
            HStack(spacing: 12) {
                // Day label with colour indicator
                Text(DraftDay.shortName(dayOfWeek))
                    .font(.subheadline.bold())
                    .foregroundStyle(isActive ? AppTheme.primary : AppTheme.textSecondary)
                    .frame(width: 36, alignment: .leading)

                if isActive, let day = draftDay {
                    Text(day.workoutName)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)

                    if !day.exercises.isEmpty {
                        Text("\(day.exercises.count) ex")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.primary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                } else {
                    Text("Rest")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textTertiary)
                }

                Spacer()

                // Add exercise button (only when day is active)
                if isActive {
                    Button {
                        onAddExercises()
                        HapticsManager.shared.light()
                    } label: {
                        Image(systemName: "plus")
                            .font(.callout.bold())
                            .foregroundStyle(AppTheme.primary)
                            .padding(8)
                            .background(AppTheme.primary.opacity(0.12))
                            .clipShape(Circle())
                    }
                }

                // Toggle active / rest
                Button {
                    onToggleRest()
                    HapticsManager.shared.selection()
                } label: {
                    Image(systemName: isActive ? "minus.circle.fill" : "plus.circle")
                        .font(.title3)
                        .foregroundStyle(isActive ? AppTheme.textTertiary : AppTheme.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // Exercise list
            if let day = draftDay, !day.exercises.isEmpty {
                Divider()
                    .background(AppTheme.border)
                    .padding(.horizontal, 16)

                VStack(spacing: 0) {
                    ForEach(day.exercises) { draft in
                        ExerciseRow(
                            draft: draft,
                            onRemove: { onRemoveExercise(draft.id) },
                            onUpdate: { onUpdateExercise($0) }
                        )

                        if draft.id != day.exercises.last?.id {
                            Divider()
                                .background(AppTheme.border.opacity(0.5))
                                .padding(.leading, 52)
                        }
                    }
                }
            }

            // Empty-state nudge when day is active but has no exercises
            if let day = draftDay, day.exercises.isEmpty {
                Button {
                    onAddExercises()
                    HapticsManager.shared.light()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "dumbbell.fill")
                        Text("Add exercises")
                    }
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(AppTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isActive ? AppTheme.primary.opacity(0.25) : AppTheme.border, lineWidth: 1)
        )
        .cardShadow()
        .animation(MotionTokens.form, value: isActive)
        .animation(MotionTokens.form, value: draftDay?.exercises.count)
    }
}

// MARK: - Exercise Row

private struct ExerciseRow: View {
    let draft: DraftExercise
    let onRemove: () -> Void
    let onUpdate: (DraftExercise) -> Void

    @State private var sets: Int
    @State private var reps: String

    init(draft: DraftExercise, onRemove: @escaping () -> Void, onUpdate: @escaping (DraftExercise) -> Void) {
        self.draft = draft
        self.onRemove = onRemove
        self.onUpdate = onUpdate
        _sets = State(initialValue: draft.sets)
        _reps = State(initialValue: draft.reps)
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(draft.exercise.category.color)
                .frame(width: 8, height: 8)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(draft.exercise.name)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(draft.exercise.category.displayName)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
            }

            Spacer()

            // Sets stepper
            HStack(spacing: 2) {
                Button {
                    if sets > 1 { sets -= 1; push() }
                } label: {
                    Image(systemName: "minus")
                        .font(.caption2.bold())
                        .frame(width: 24, height: 24)
                        .background(AppTheme.surface3)
                        .clipShape(Circle())
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Text("\(sets) sets")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 50)
                    .multilineTextAlignment(.center)

                Button {
                    if sets < 10 { sets += 1; push() }
                } label: {
                    Image(systemName: "plus")
                        .font(.caption2.bold())
                        .frame(width: 24, height: 24)
                        .background(AppTheme.surface3)
                        .clipShape(Circle())
                        .foregroundStyle(AppTheme.primary)
                }
            }

            // Reps field
            TextField("reps", text: $reps)
                .font(.caption.monospacedDigit())
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
                .frame(width: 44)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(AppTheme.surface3)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .keyboardType(.numbersAndPunctuation)
                .onChange(of: reps) { _, _ in push() }

            Button { onRemove() } label: {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func push() {
        var updated = draft
        updated.sets = sets
        updated.reps = reps
        onUpdate(updated)
    }
}
