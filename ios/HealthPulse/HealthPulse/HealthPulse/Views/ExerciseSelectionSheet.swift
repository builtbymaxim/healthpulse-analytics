//
//  ExerciseSelectionSheet.swift
//  HealthPulse
//
//  Exercise picker for the custom plan builder — search + category filter + add.
//

import SwiftUI

struct ExerciseSelectionSheet: View {
    let dayOfWeek: Int
    @ObservedObject var viewModel: CustomPlanBuilderViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedCategory: ExerciseCategory? = nil
    @State private var exercises: [Exercise] = []
    @State private var isLoading = false
    @State private var addedId: UUID? = nil       // triggers the check animation

    // Picker-visible categories (no cardio/other for strength plans)
    private let filterCategories: [ExerciseCategory] = [.chest, .back, .legs, .arms, .shoulders, .core]

    private var filtered: [Exercise] {
        exercises.filter { ex in
            let matchesSearch = searchText.isEmpty || ex.name.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == nil || ex.category == selectedCategory
            return matchesSearch && matchesCategory
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground(showGlow: false)

                VStack(spacing: 0) {
                    categoryFilter
                        .padding(.vertical, 12)

                    if isLoading {
                        Spacer()
                        ProgressView("Loading exercises…")
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                    } else if filtered.isEmpty {
                        emptyState
                    } else {
                        exerciseList
                    }
                }
            }
            .navigationTitle("Add to \(DraftDay.fullName(dayOfWeek))")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search exercises…")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .bold()
                        .foregroundStyle(AppTheme.primary)
                }
            }
            .task { await loadExercises() }
            .onChange(of: searchText) { _, _ in /* filtered is computed */ }
        }
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All",
                    icon: "square.grid.2x2",
                    isSelected: selectedCategory == nil
                ) {
                    withAnimation(MotionTokens.snappy) { selectedCategory = nil }
                }

                ForEach(filterCategories, id: \.self) { cat in
                    FilterChip(
                        title: cat.displayName,
                        icon: cat.icon,
                        isSelected: selectedCategory == cat
                    ) {
                        withAnimation(MotionTokens.snappy) {
                            selectedCategory = selectedCategory == cat ? nil : cat
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 8) {
                ForEach(filtered) { exercise in
                    ExercisePickerRow(
                        exercise: exercise,
                        isAdded: viewModel.days[dayOfWeek]?.exercises.contains { $0.exercise.id == exercise.id } ?? false,
                        justAdded: addedId == exercise.id
                    ) {
                        addExercise(exercise)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.textTertiary)
            Text("No exercises found")
                .font(.headline)
                .foregroundStyle(AppTheme.textSecondary)
            if !searchText.isEmpty {
                Text("Try a different search term or clear the filter.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Spacer()
        }
    }

    // MARK: - Actions

    private func addExercise(_ exercise: Exercise) {
        HapticsManager.shared.success()
        withAnimation(MotionTokens.snappy) {
            viewModel.addExercise(exercise, to: dayOfWeek)
            addedId = exercise.id
        }
        // Clear the visual confirmation after a moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(MotionTokens.micro) { addedId = nil }
        }
    }

    private func loadExercises() async {
        isLoading = true
        do {
            exercises = try await APIService.shared.getExercises()
        } catch {
            print("Failed to load exercises: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Exercise Picker Row

private struct ExercisePickerRow: View {
    let exercise: Exercise
    let isAdded: Bool
    let justAdded: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Category icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(exercise.category.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: exercise.category.icon)
                    .font(.callout)
                    .foregroundStyle(exercise.category.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(exercise.category.displayName)
                    if let equip = exercise.equipment {
                        Text("·")
                        Text(equip.displayName)
                    }
                    if exercise.isCompound {
                        Text("·")
                        Text("Compound")
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                .font(.caption)
                .foregroundStyle(AppTheme.textTertiary)
            }

            Spacer()

            // Add / Added state button
            Button {
                if !isAdded { onAdd() }
            } label: {
                ZStack {
                    if justAdded {
                        Image(systemName: "checkmark")
                            .font(.callout.bold())
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    } else if isAdded {
                        Image(systemName: "checkmark")
                            .font(.callout.bold())
                            .foregroundStyle(AppTheme.primary)
                    } else {
                        Image(systemName: "plus")
                            .font(.callout.bold())
                            .foregroundStyle(AppTheme.primary)
                    }
                }
                .frame(width: 34, height: 34)
                .background(
                    justAdded ? AppTheme.primary :
                    isAdded   ? AppTheme.primary.opacity(0.12) :
                                AppTheme.primary.opacity(0.12)
                )
                .clipShape(Circle())
                .animation(MotionTokens.snappy, value: justAdded)
                .animation(MotionTokens.snappy, value: isAdded)
            }
            .disabled(isAdded)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(justAdded ? AppTheme.primary.opacity(0.4) : AppTheme.border, lineWidth: 1)
        )
        .cardShadow()
        .animation(MotionTokens.form, value: justAdded)
    }
}
