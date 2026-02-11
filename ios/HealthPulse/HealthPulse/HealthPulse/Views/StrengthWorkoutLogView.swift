//
//  StrengthWorkoutLogView.swift
//  HealthPulse
//
//  Strength workout logging with set-by-set tracking
//

import SwiftUI

struct StrengthWorkoutLogView: View {
    @Environment(\.dismiss) private var dismiss

    let workoutId: UUID?
    let onSave: ([WorkoutSet]) -> Void

    @State private var exercises: [Exercise] = []
    @State private var sets: [SetInputState] = []
    @State private var isLoadingExercises = true
    @State private var isSaving = false
    @State private var error: String?
    @State private var isOfflineMode = false  // Track if using local defaults (can't save)
    @State private var showingExercisePicker = false
    @State private var selectedExerciseIndex: Int?
    @State private var searchText = ""
    @State private var selectedCategory: ExerciseCategory?
    @State private var showPRAlert = false
    @State private var prExerciseName = ""
    @State private var showRestTimer = false
    @State private var suggestions: [String: WeightSuggestion] = [:]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoadingExercises {
                    ProgressView("Loading exercises...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 16) {
                            // Sets List
                            ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                                SetRowView(
                                    set: $sets[index],
                                    setNumber: index + 1,
                                    suggestion: set.exercise.flatMap { suggestions[$0.name] },
                                    onSelectExercise: {
                                        selectedExerciseIndex = index
                                        showingExercisePicker = true
                                    },
                                    onDelete: {
                                        withAnimation {
                                            let _: SetInputState = sets.remove(at: index)
                                        }
                                    }
                                )
                            }

                            // Action Buttons
                            HStack(spacing: 12) {
                                // Add Set Button
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        addSet()
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add Set")
                                    }
                                    .font(.headline)
                                    .foregroundStyle(.green)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }

                                // Rest Timer Button (show when there are sets)
                                if !sets.isEmpty {
                                    Button {
                                        showRestTimer = true
                                        HapticsManager.shared.medium()
                                    } label: {
                                        HStack {
                                            Image(systemName: "timer")
                                            Text("Rest")
                                        }
                                        .font(.headline)
                                        .foregroundStyle(.orange)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.orange.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            }

                            // Quick Add Previous
                            if !sets.isEmpty, let lastSet = sets.last, lastSet.exercise != nil {
                                Button {
                                    duplicateLastSet()
                                    // Auto-show rest timer after duplicating
                                    showRestTimer = true
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.counterclockwise")
                                        Text("Same Set + Rest")
                                    }
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }

                            if isOfflineMode {
                                HStack {
                                    Image(systemName: "wifi.slash")
                                    Text("Offline mode - saving disabled. Connect to save workouts.")
                                }
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .padding(.horizontal)
                            }

                            if let error = error {
                                Text(error)
                                    .foregroundStyle(.red)
                                    .font(.caption)
                                    .padding()
                            }
                        }
                        .padding()
                    }

                    // Summary Footer
                    if !sets.isEmpty {
                        VStack(spacing: 8) {
                            Divider()
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("\(validSetsCount) sets")
                                        .font(.headline)
                                    Text("Volume: \(formattedTotalVolume)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Save Workout") {
                                    Task { await saveWorkout() }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(!canSave || isSaving)
                            }
                            .padding()
                        }
                        .background(Color(.systemBackground))
                    }
                }
            }
            .navigationTitle("Log Strength Workout")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button(action: { dismiss() }, label: { Text("Cancel") }))
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView(
                    exercises: exercises,
                    selectedCategory: $selectedCategory,
                    searchText: $searchText,
                    onSelect: { exercise in
                        if let index = selectedExerciseIndex {
                            sets[index].exercise = exercise
                            sets[index].exerciseId = exercise.id
                        }
                        showingExercisePicker = false
                        // Fetch suggestion for this exercise if not cached
                        if suggestions[exercise.name] == nil {
                            Task { await fetchSuggestion(for: exercise.name) }
                        }
                    }
                )
            }
            .alert("New Personal Record", isPresented: $showPRAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Congratulations! You set a new PR on \(prExerciseName)!")
            }
            .restTimerSheet(isPresented: $showRestTimer) {
                // Timer completed - ready for next set
                HapticsManager.shared.success()
            }
            .overlay {
                if isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
            .task {
                await loadExercises()
            }
        }
    }

    // MARK: - Computed Properties

    private var validSetsCount: Int {
        sets.filter { $0.isValid }.count
    }

    private var totalVolume: Double {
        sets.filter { $0.isValid }
            .compactMap { set -> Double? in
                guard let weight = Double(set.weight),
                      let reps = Int(set.reps) else { return nil }
                return weight * Double(reps)
            }
            .reduce(0, +)
    }

    private var formattedTotalVolume: String {
        if totalVolume >= 1000 {
            return String(format: "%.1fk kg", totalVolume / 1000)
        }
        return String(format: "%.0f kg", totalVolume)
    }

    private var canSave: Bool {
        !isOfflineMode && sets.contains { $0.isValid }
    }

    // MARK: - Actions

    private func loadExercises() async {
        isLoadingExercises = true
        do {
            exercises = try await APIService.shared.getExercises()
            isOfflineMode = false
        } catch {
            // Use default exercises for browsing, but mark as offline (can't save)
            exercises = Self.defaultExercises
            isOfflineMode = true
        }
        // Add initial empty set
        if sets.isEmpty {
            addSet()
        }
        isLoadingExercises = false
    }

    // Default exercises for offline use
    private static let defaultExercises: [Exercise] = [
        Exercise(id: UUID(), name: "Bench Press", category: .chest, muscleGroups: ["chest", "triceps"], equipment: .barbell, isCompound: true, createdAt: Date()),
        Exercise(id: UUID(), name: "Incline Dumbbell Press", category: .chest, muscleGroups: ["chest"], equipment: .dumbbell, isCompound: true, createdAt: Date()),
        Exercise(id: UUID(), name: "Push-ups", category: .chest, muscleGroups: ["chest", "triceps"], equipment: .bodyweight, isCompound: true, createdAt: Date()),
        Exercise(id: UUID(), name: "Deadlift", category: .back, muscleGroups: ["back", "hamstrings"], equipment: .barbell, isCompound: true, createdAt: Date()),
        Exercise(id: UUID(), name: "Pull-ups", category: .back, muscleGroups: ["back", "biceps"], equipment: .bodyweight, isCompound: true, createdAt: Date()),
        Exercise(id: UUID(), name: "Barbell Row", category: .back, muscleGroups: ["back"], equipment: .barbell, isCompound: true, createdAt: Date()),
        Exercise(id: UUID(), name: "Lat Pulldown", category: .back, muscleGroups: ["back"], equipment: .cable, isCompound: true, createdAt: Date()),
        Exercise(id: UUID(), name: "Overhead Press", category: .shoulders, muscleGroups: ["shoulders"], equipment: .barbell, isCompound: true, createdAt: Date()),
        Exercise(id: UUID(), name: "Lateral Raises", category: .shoulders, muscleGroups: ["shoulders"], equipment: .dumbbell, isCompound: false, createdAt: Date()),
        Exercise(id: UUID(), name: "Bicep Curls", category: .arms, muscleGroups: ["biceps"], equipment: .dumbbell, isCompound: false, createdAt: Date()),
        Exercise(id: UUID(), name: "Tricep Pushdown", category: .arms, muscleGroups: ["triceps"], equipment: .cable, isCompound: false, createdAt: Date()),
        Exercise(id: UUID(), name: "Squat", category: .legs, muscleGroups: ["quads", "glutes"], equipment: .barbell, isCompound: true, createdAt: Date()),
        Exercise(id: UUID(), name: "Leg Press", category: .legs, muscleGroups: ["quads"], equipment: .machine, isCompound: true, createdAt: Date()),
        Exercise(id: UUID(), name: "Romanian Deadlift", category: .legs, muscleGroups: ["hamstrings"], equipment: .barbell, isCompound: true, createdAt: Date()),
        Exercise(id: UUID(), name: "Lunges", category: .legs, muscleGroups: ["quads", "glutes"], equipment: .dumbbell, isCompound: true, createdAt: Date()),
        Exercise(id: UUID(), name: "Hip Thrusts", category: .legs, muscleGroups: ["glutes", "hamstrings"], equipment: .barbell, isCompound: true, createdAt: Date()),
        Exercise(id: UUID(), name: "Leg Curls", category: .legs, muscleGroups: ["hamstrings"], equipment: .machine, isCompound: false, createdAt: Date()),
        Exercise(id: UUID(), name: "Calf Raises", category: .legs, muscleGroups: ["calves"], equipment: .machine, isCompound: false, createdAt: Date()),
        Exercise(id: UUID(), name: "Plank", category: .core, muscleGroups: ["core"], equipment: .bodyweight, isCompound: false, createdAt: Date()),
        Exercise(id: UUID(), name: "Crunches", category: .core, muscleGroups: ["core"], equipment: .bodyweight, isCompound: false, createdAt: Date()),
    ]

    private func fetchSuggestion(for exerciseName: String) async {
        do {
            let result = try await APIService.shared.getExerciseSuggestions(exerciseNames: [exerciseName])
            if let suggestion = result[exerciseName] {
                suggestions[exerciseName] = suggestion
            }
        } catch {
            print("Failed to fetch suggestion for \(exerciseName): \(error)")
        }
    }

    private func addSet() {
        var newSet = SetInputState()
        // If we have a previous set, pre-fill the exercise
        if let lastSet = sets.last {
            newSet.exerciseId = lastSet.exerciseId
            newSet.exercise = lastSet.exercise
        }
        sets.append(newSet)
    }

    private func duplicateLastSet() {
        guard let lastSet = sets.last else { return }
        var newSet = SetInputState()
        newSet.exerciseId = lastSet.exerciseId
        newSet.exercise = lastSet.exercise
        newSet.weight = lastSet.weight
        newSet.reps = lastSet.reps
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            sets.append(newSet)
        }
        HapticsManager.shared.light()
    }

    private func saveWorkout() async {
        guard canSave else { return }

        isSaving = true
        error = nil

        // Convert to API format
        var setCreates: [WorkoutSetCreate] = []
        var setNumber = 1

        for set in sets where set.isValid {
            if let create = set.toCreate(setNumber: setNumber) {
                setCreates.append(create)
                setNumber += 1
            }
        }

        do {
            let savedSets = try await APIService.shared.logWorkoutSets(
                workoutId: workoutId,
                sets: setCreates
            )

            // Check for PRs
            let prSets = savedSets.filter { $0.isPR }
            if let firstPR = prSets.first, let name = firstPR.exerciseName {
                prExerciseName = name
                showPRAlert = true
            }

            onSave(savedSets)

            // Dismiss after short delay for PR alert
            if !prSets.isEmpty {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }
}

// MARK: - Set Row View (Simplified)

struct SetRowView: View {
    @Binding var set: SetInputState
    let setNumber: Int
    var suggestion: WeightSuggestion?
    let onSelectExercise: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Exercise selector
            Button(action: onSelectExercise) {
                HStack {
                    if let exercise = set.exercise {
                        Image(systemName: exercise.category.icon)
                            .foregroundStyle(exercise.category.color)
                        Text(exercise.name)
                            .foregroundStyle(.primary)
                    } else {
                        Image(systemName: "dumbbell")
                            .foregroundStyle(.secondary)
                        Text("Select Exercise")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Suggestion hint
            if let suggestion = suggestion, suggestion.status != "new" {
                SuggestionHint(suggestion: suggestion) {
                    if let weight = suggestion.suggestedWeightKg {
                        set.weight = formatWeight(weight)
                    }
                    HapticsManager.shared.light()
                }
                .padding(.horizontal, 4)
            }

            // Weight & Reps inputs (simplified - no RPE, no warmup)
            HStack(spacing: 16) {
                // Set number
                Text("#\(setNumber)")
                    .font(.title3.bold())
                    .foregroundStyle(.green)
                    .frame(width: 40)

                // Weight - larger touch target
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weight")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        TextField("0", text: $set.weight)
                            .keyboardType(.decimalPad)
                            .font(.title2.bold())
                            .frame(width: 80)
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Text("kg")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // Reps - larger touch target
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("0", text: $set.reps)
                        .keyboardType(.numberPad)
                        .font(.title2.bold())
                        .frame(width: 60)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Spacer()

                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red.opacity(0.7))
                        .font(.title2)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5)
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", w) : String(format: "%.1f", w)
    }
}

// MARK: - Exercise Picker View

struct ExercisePickerView: View {
    let exercises: [Exercise]
    @Binding var selectedCategory: ExerciseCategory?
    @Binding var searchText: String
    let onSelect: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss

    var filteredExercises: [Exercise] {
        var result = exercises

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return result
    }

    var groupedExercises: [ExerciseCategory: [Exercise]] {
        Dictionary(grouping: filteredExercises, by: { $0.category })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            title: "All",
                            isSelected: selectedCategory == nil,
                            action: { selectedCategory = nil }
                        )

                        ForEach(ExerciseCategory.allCases, id: \.self) { category in
                            FilterChip(
                                title: category.displayName,
                                icon: category.icon,
                                isSelected: selectedCategory == category,
                                action: { selectedCategory = category }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)

                Divider()

                // Exercise list
                List {
                    if selectedCategory == nil && searchText.isEmpty {
                        // Grouped by category
                        ForEach(ExerciseCategory.allCases, id: \.self) { category in
                            if let exercises = groupedExercises[category], !exercises.isEmpty {
                                Section(header: Text(category.displayName)) {
                                    ForEach(exercises) { exercise in
                                        ExerciseRowButton(exercise: exercise, onSelect: onSelect)
                                    }
                                }
                            }
                        }
                    } else {
                        // Flat list
                        ForEach(filteredExercises) { exercise in
                            ExerciseRowButton(exercise: exercise, onSelect: onSelect)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationBarItems(leading: Button(action: { dismiss() }, label: { Text("Cancel") }))
        }
    }
}

struct FilterChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? AppTheme.primary : Color(.secondarySystemBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

struct ExerciseRowButton: View {
    let exercise: Exercise
    let onSelect: (Exercise) -> Void

    var body: some View {
        Button {
            HapticsManager.shared.light()
            onSelect(exercise)
        } label: {
            HStack {
                Image(systemName: exercise.category.icon)
                    .foregroundStyle(exercise.category.color)
                    .font(.title3)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    if let equipment = exercise.equipment {
                        Text(equipment.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if exercise.isCompound {
                    Text("Compound")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }

                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.green)
                    .font(.title3)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    StrengthWorkoutLogView(workoutId: nil) { _ in }
}
