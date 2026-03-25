//
//  WorkoutExecutionView.swift
//  HealthPulse
//
//  Quick performance logging view for executing planned workouts
//

import SwiftUI
import Combine
import ActivityKit

struct WorkoutExecutionView: View {
    @ObservedObject var viewModel: WorkoutExecutionViewModel
    let onComplete: ([PRInfo]) -> Void

    @State private var showExercisePicker = false
    @State private var showCancelConfirmation = false
    @State private var showCompletion = false
    @State private var completionPRs: [PRInfo] = []
    @State private var completionSummary: (duration: Int, exercises: Int, sets: Int)?
    @State private var saveError: String?
    @State private var isFocusMode = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isFocusMode {
                    FocusModeView(viewModel: viewModel, onFinish: { triggerComplete() })
                } else {
                // Workout header
                WorkoutHeader(
                    workoutName: viewModel.workoutName,
                    focus: viewModel.workoutFocus,
                    elapsedTime: viewModel.elapsedTime,
                    isRunning: viewModel.isTimerRunning
                )

                // Exercise list grouped by key lifts vs accessories
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Key Lifts Section
                        let keyLiftIndices = viewModel.exerciseLogs.indices.filter { viewModel.exerciseLogs[$0].isKeyLift }
                        if !keyLiftIndices.isEmpty {
                            SectionHeader(
                                icon: "star.fill",
                                iconColor: .yellow,
                                title: "Key Lifts",
                                subtitle: "Track every set in detail"
                            )

                            ForEach(keyLiftIndices, id: \.self) { index in
                                ExerciseLogCard(
                                    exerciseLog: $viewModel.exerciseLogs[index],
                                    onAddSet: { viewModel.addSet(to: index) },
                                    onDeleteSet: { setIndex in viewModel.deleteSet(from: index, setIndex: setIndex) }
                                )
                            }
                        }

                        // Accessories Section
                        let accessoryIndices = viewModel.exerciseLogs.indices.filter { !viewModel.exerciseLogs[$0].isKeyLift }
                        if !accessoryIndices.isEmpty {
                            SectionHeader(
                                icon: "dumbbell.fill",
                                iconColor: .secondary,
                                title: "Accessories",
                                subtitle: "Quick check-off or add sets"
                            )
                            .padding(.top, keyLiftIndices.isEmpty ? 0 : 8)

                            ForEach(accessoryIndices, id: \.self) { index in
                                ExerciseLogCard(
                                    exerciseLog: $viewModel.exerciseLogs[index],
                                    onAddSet: { viewModel.addSet(to: index) },
                                    onDeleteSet: { setIndex in viewModel.deleteSet(from: index, setIndex: setIndex) }
                                )
                            }
                        }

                        // Add Exercise button
                        Button {
                            showExercisePicker = true
                            HapticsManager.shared.light()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Exercise")
                            }
                            .font(.headline)
                            .foregroundStyle(AppTheme.primary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppTheme.primary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding()
                }
                .sheet(isPresented: $showExercisePicker) {
                    AddExerciseSheet { exerciseName in
                        viewModel.addExercise(name: exerciseName)
                    }
                }

                // Complete workout button
                VStack(spacing: 6) {
                    Button {
                        triggerComplete()
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Complete Workout")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.canComplete ? AppTheme.primary : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(!viewModel.canComplete || viewModel.isSaving)

                    if !viewModel.canComplete {
                        Text("Log at least one set to complete")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }   // closes else
        }       // closes VStack(spacing: 0)
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    showCancelConfirmation = true
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 4) {
                    Button {
                        withAnimation(MotionTokens.snappy) { isFocusMode.toggle() }
                    } label: {
                        Image(systemName: isFocusMode ? "list.bullet" : "rectangle.stack")
                    }
                    Button {
                        WorkoutSessionStore.shared.minimize()
                    } label: {
                        Image(systemName: "minus")
                    }
                }
            }
        }
        .alert("Cancel Workout?", isPresented: $showCancelConfirmation) {
            Button("Keep Going", role: .cancel) { }
            Button("Discard", role: .destructive) {
                WorkoutSessionStore.shared.cancelWorkout()
            }
        } message: {
            Text("Your workout progress will be lost.")
        }
        .task {
            await viewModel.fetchSuggestions()
        }
        .fullScreenCover(isPresented: $showCompletion) {
            if let summary = completionSummary {
                WorkoutCompletionView(summary: summary) {
                    showCompletion = false
                    WorkoutSessionStore.shared.endWorkout(prs: completionPRs)
                }
            }
        }
        .alert("Save Failed", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("Try Again") {
                saveError = nil
                triggerComplete()
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveError ?? "Could not save your workout. Please try again.")
        }
        .alert("Resume Workout?", isPresented: $viewModel.wasInterrupted) {
            Button("Resume") {}
            Button("Discard", role: .destructive) {
                viewModel.discardSavedWorkout()
            }
        } message: {
            Text("You have an unfinished workout from a previous session.")
        }
    }
    }

    private func triggerComplete() {
        viewModel.completeWorkout(onError: { message in
            saveError = message
        }) { prs in
            let exerciseCount = viewModel.exerciseLogs.filter { log in
                log.isCompleted || log.sets.contains { ($0.weight ?? 0) > 0 || ($0.reps ?? 0) > 0 || ($0.duration ?? 0) > 0 }
            }.count
            let setCount = viewModel.exerciseLogs.flatMap(\.sets).filter { ($0.weight ?? 0) > 0 || ($0.reps ?? 0) > 0 || ($0.duration ?? 0) > 0 }.count
            completionSummary = (duration: Int(viewModel.elapsedTime / 60), exercises: exerciseCount, sets: setCount)
            completionPRs = prs
            showCompletion = true
        }
    }
}

// MARK: - Workout Header

struct WorkoutHeader: View {
    let workoutName: String
    let focus: String?
    let elapsedTime: TimeInterval
    let isRunning: Bool

    var formattedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workoutName)
                        .font(.title3.bold())
                    if let focus = focus {
                        Text(focus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(isRunning ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(formattedTime)
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(AppTheme.surface2)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .font(.subheadline)

            Text(title)
                .font(.headline)

            Text("–")
                .foregroundStyle(.tertiary)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Exercise Log Card

struct ExerciseLogCard: View {
    @Binding var exerciseLog: ExerciseLogEntry
    @State private var showRPEInfo = false

    let onAddSet: () -> Void
    let onDeleteSet: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Exercise header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(exerciseLog.name)
                            .font(.headline)
                        if exerciseLog.isKeyLift {
                            Text("KEY")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }
                    }
                    if let target = exerciseLog.targetSetsReps {
                        Text("Target: \(target)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    // Weight suggestion hint
                    if let suggestion = exerciseLog.suggestion {
                        SuggestionHint(suggestion: suggestion) {
                            applySuggestion(suggestion)
                        }
                    }
                }

                Spacer()

                // Quick complete toggle for accessories
                if !exerciseLog.isKeyLift {
                    Button {
                        exerciseLog.isCompleted.toggle()
                        HapticsManager.shared.selection()
                    } label: {
                        Image(systemName: exerciseLog.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(exerciseLog.isCompleted ? .green : .secondary)
                    }
                }
            }

            // Sets for key lifts
            if exerciseLog.isKeyLift || !exerciseLog.sets.isEmpty {
                VStack(spacing: 8) {
                    // Column headers (dynamic based on input type)
                    columnHeaders

                    ForEach(exerciseLog.sets.indices, id: \.self) { setIndex in
                        SetLogRow(
                            setNumber: setIndex + 1,
                            setLog: $exerciseLog.sets[setIndex],
                            inputType: exerciseLog.inputType,
                            onDelete: { onDeleteSet(setIndex) }
                        )
                    }

                    // Add set button
                    Button {
                        onAddSet()
                        HapticsManager.shared.light()
                    } label: {
                        Label("Add Set", systemImage: "plus.circle")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .cardShadow()
    }

    // Dynamic column headers based on exercise input type
    private var columnHeaders: some View {
        HStack {
            Text("Set")
                .frame(width: 35, alignment: .leading)

            switch exerciseLog.inputType {
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
        .sheet(isPresented: $showRPEInfo) {
            RPEInfoSheet()
        }
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

    private func applySuggestion(_ suggestion: WeightSuggestion) {
        guard let weight = suggestion.suggestedWeightKg, weight > 0 else { return }
        for i in exerciseLog.sets.indices {
            if exerciseLog.sets[i].weight == nil || exerciseLog.sets[i].weight == suggestion.lastWeightKg {
                exerciseLog.sets[i].weight = weight
            }
        }
        HapticsManager.shared.light()
    }
}

// MARK: - Suggestion Hint

struct SuggestionHint: View {
    let suggestion: WeightSuggestion
    let onTap: () -> Void

    var body: some View {
        if suggestion.status != "new", let suggested = suggestion.suggestedWeightKg {
            Button(action: onTap) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.caption2)
                    Text(label(suggested: suggested))
                        .font(.caption)
                }
                .foregroundStyle(color)
            }
            .buttonStyle(.plain)
        }
    }

    private var icon: String {
        switch suggestion.status {
        case "increase": return "arrow.up.right"
        case "deload": return "arrow.down.right"
        default: return "arrow.right"
        }
    }

    private var color: Color {
        switch suggestion.status {
        case "increase": return .green
        case "deload": return .orange
        default: return .secondary
        }
    }

    private func label(suggested: Double) -> String {
        let suggestedStr = formatWeight(suggested)
        if let last = suggestion.lastWeightKg {
            let lastStr = formatWeight(last)
            switch suggestion.status {
            case "increase": return "\(suggestedStr)kg (was \(lastStr)kg)"
            case "deload": return "\(suggestedStr)kg (deload from \(lastStr)kg)"
            default: return "\(suggestedStr)kg (maintain)"
            }
        }
        return "\(suggestedStr)kg"
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", w) : String(format: "%.1f", w)
    }
}

// MARK: - Set Log Row

struct SetLogRow: View {
    let setNumber: Int
    @Binding var setLog: SetLogEntry
    let inputType: ExerciseInputType
    let onDelete: () -> Void

    @State private var showWeightPicker = false
    @State private var showRepsPicker = false
    @State private var showRPEPicker = false

    var body: some View {
        HStack {
            Text("\(setNumber)")
                .font(.subheadline.bold())
                .frame(width: 35, alignment: .leading)

            // Conditional inputs based on exercise type
            switch inputType {
            case .weightAndReps:
                weightInput
                repsInput
                rpeSelector

            case .repsOnly:
                repsInput
                rpeSelector
                Spacer()

            case .timeOnly:
                durationInput
                Spacer()

            case .distanceAndTime:
                distanceInput
                durationInput
            }

            Spacer()

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red.opacity(0.7))
            }
        }
    }

    // MARK: - Input Components

    private var weightInput: some View {
        Button {
            showWeightPicker = true
            HapticsManager.shared.selection()
        } label: {
            HStack(spacing: 4) {
                Text(setLog.weight.map { w in
                    w.truncatingRemainder(dividingBy: 1) == 0
                        ? String(format: "%.0f", w)
                        : String(format: "%.2g", w)
                } ?? "—")
                .font(.body.monospacedDigit())
                .foregroundStyle(setLog.weight == nil ? .tertiary : .primary)
                .frame(width: 46, alignment: .trailing)
                Text("kg")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(AppTheme.surface2, in: RoundedRectangle(cornerRadius: 8))
        }
        .sheet(isPresented: $showWeightPicker) {
            WeightInputSelector(weight: $setLog.weight)
        }
        .frame(width: 80)
    }

    private var repsInput: some View {
        Button {
            showRepsPicker = true
            HapticsManager.shared.selection()
        } label: {
            Text(setLog.reps.map { "\($0)" } ?? "—")
                .font(.body.monospacedDigit())
                .foregroundStyle(setLog.reps == nil ? .tertiary : .primary)
                .frame(width: 46, alignment: .center)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(AppTheme.surface2, in: RoundedRectangle(cornerRadius: 8))
        }
        .frame(width: 60)
        .sheet(isPresented: $showRepsPicker) {
            VStack(spacing: 12) {
                Text("Reps")
                    .font(.headline)
                    .padding(.top, 12)
                Picker("Reps", selection: Binding(
                    get: { setLog.reps ?? 0 },
                    set: { setLog.reps = $0 == 0 ? nil : $0 }
                )) {
                    Text("—").tag(0)
                    ForEach(1...99, id: \.self) { rep in
                        Text("\(rep)").tag(rep)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 140)
                .clipped()
                .onChange(of: setLog.reps) { _, _ in
                    HapticsManager.shared.selection()
                }
            }
            .presentationDetents([.height(220)])
            .presentationDragIndicator(.visible)
        }
    }

    private var rpeSelector: some View {
        Button {
            showRPEPicker = true
            HapticsManager.shared.selection()
        } label: {
            Text(setLog.rpe != nil ? "\(setLog.rpe!)" : "-")
                .font(.body.monospacedDigit())
                .foregroundStyle(setLog.rpe == nil ? .tertiary : .primary)
                .frame(width: 40)
                .padding(.vertical, 6)
                .background(AppTheme.surface2, in: RoundedRectangle(cornerRadius: 8))
        }
        .frame(width: 50)
        .sheet(isPresented: $showRPEPicker) {
            RPEPickerSheet(selectedRPE: $setLog.rpe)
        }
    }

    private var durationInput: some View {
        HStack(spacing: 4) {
            TextField("", value: $setLog.duration, format: .number)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .overlay(alignment: .leading) {
                    if setLog.duration == nil {
                        Text("0")
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 8)
                            .allowsHitTesting(false)
                    }
                }
            Text("sec")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 80)
    }

    private var distanceInput: some View {
        HStack(spacing: 4) {
            TextField("", value: $setLog.distance, format: .number)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .overlay(alignment: .leading) {
                    if setLog.distance == nil {
                        Text("0")
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 8)
                            .allowsHitTesting(false)
                    }
                }
            Text("km")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 80)
    }
}

// MARK: - RPE Info Sheet

struct RPEInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Rate of Perceived Exertion")
                        .font(.title2.bold())

                    Text("RPE is a scale from 1-10 that measures how hard a set felt. It helps you track intensity without needing exact percentages.")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        rpeRow(10, "Maximum effort - couldn't do another rep")
                        rpeRow(9, "Very hard - maybe 1 rep left")
                        rpeRow(8, "Hard - 2 reps left in the tank")
                        rpeRow(7, "Moderate - 3 reps left")
                        rpeRow(6, "Light - 4+ reps left")
                    }
                    .padding()
                    .background(AppTheme.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text("Tip: Most working sets should be RPE 7-9. Leave RPE 10 for PR attempts.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("What is RPE?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Got it") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func rpeRow(_ value: Int, _ description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(value)")
                .font(.headline.bold())
                .foregroundStyle(rpeColor(value))
                .frame(width: 30)
            Text(description)
                .font(.subheadline)
        }
    }

    private func rpeColor(_ value: Int) -> Color {
        switch value {
        case 10: return .red
        case 9: return .orange
        case 8: return .yellow
        case 7: return .green
        default: return .blue
        }
    }
}

// MARK: - RPE Picker Sheet

struct RPEPickerSheet: View {
    @Binding var selectedRPE: Int?
    @Environment(\.dismiss) private var dismiss

    private let rpeOptions: [(value: Int, description: String, color: Color)] = [
        (10, "Max effort — couldn't do another rep", .red),
        (9, "Very hard — maybe 1 rep left", .orange),
        (8, "Hard — 2 reps left in the tank", .yellow),
        (7, "Moderate — 3 reps left", .green),
        (6, "Light — 4+ reps left", .blue)
    ]

    var body: some View {
        VStack(spacing: 0) {
            Text("Rate of Perceived Exertion")
                .font(.headline)
                .padding(.top, 16)
                .padding(.bottom, 12)

            ForEach(rpeOptions, id: \.value) { option in
                Button {
                    selectedRPE = option.value
                    HapticsManager.shared.light()
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Text("\(option.value)")
                            .font(.title3.bold())
                            .foregroundStyle(option.color)
                            .frame(width: 32)
                        Text(option.description)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedRPE == option.value {
                            Image(systemName: "checkmark")
                                .foregroundStyle(option.color)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }

            Divider().padding(.top, 4)

            Button {
                selectedRPE = nil
                HapticsManager.shared.selection()
                dismiss()
            } label: {
                Text("Clear")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Add Exercise Sheet

struct AddExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (String) -> Void

    @State private var searchText = ""
    @State private var exercises: [Exercise] = []
    @State private var isLoading = true

    // Common exercises for quick access
    private let commonExercises = [
        "Bench Press", "Squat", "Deadlift", "Overhead Press",
        "Barbell Row", "Pull-up", "Dumbbell Curl", "Tricep Pushdown",
        "Leg Press", "Lat Pulldown", "Face Pull", "Lateral Raise",
        "Romanian Deadlift", "Hip Thrust", "Calf Raise", "Plank"
    ]

    var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return exercises
        }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("Add Exercise")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                .task {
                    await loadExercises()
                }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if isLoading {
            ProgressView("Loading exercises...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            exerciseList
        }
    }

    private var exerciseList: some View {
        List {
            if searchText.isEmpty {
                commonExercisesSection
            }
            searchResultsSection
        }
        .searchable(text: $searchText, prompt: "Search exercises")
    }

    private var commonExercisesSection: some View {
        Section("Common Exercises") {
            commonExercisesGrid
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
    }

    private var commonExercisesGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(commonExercises.prefix(8), id: \.self) { exercise in
                commonExerciseButton(exercise)
            }
        }
    }

    private func commonExerciseButton(_ exercise: String) -> some View {
        Button {
            addExercise(exercise)
        } label: {
            Text(exercise)
                .font(.caption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(AppTheme.primary.opacity(0.1))
                .foregroundStyle(AppTheme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var searchResultsSection: some View {
        Section(searchText.isEmpty ? "All Exercises" : "Search Results") {
            if filteredExercises.isEmpty && !searchText.isEmpty {
                customExerciseButton
            } else {
                ForEach(filteredExercises) { exercise in
                    exerciseRow(exercise)
                }
            }
        }
    }

    private var customExerciseButton: some View {
        Button {
            addExercise(searchText)
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.green)
                Text("Add \"\(searchText)\" as custom exercise")
            }
        }
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        Button {
            addExercise(exercise.name)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .foregroundStyle(.primary)
                    Text(exercise.category.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "plus.circle")
                    .foregroundStyle(.green)
            }
        }
    }

    private func loadExercises() async {
        do {
            let fetchedExercises = try await APIService.shared.getExercises()
            await MainActor.run {
                exercises = fetchedExercises
                isLoading = false
            }
        } catch {
            print("Failed to load exercises: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func addExercise(_ name: String) {
        HapticsManager.shared.medium()
        onAdd(name)
        dismiss()
    }
}

#Preview {
    let mockWorkout = TodayWorkoutResponse(
        hasPlan: true,
        isRestDay: false,
        isCompleted: false,
        workoutName: "Upper Body A",
        workoutFocus: "Chest Focus",
        exercises: [
            PlannedExercise(name: "Bench Press", sets: 4, reps: "5", notes: nil, isKeyLift: true, restSeconds: 120),
            PlannedExercise(name: "Overhead Press", sets: 3, reps: "8", notes: nil, isKeyLift: false, restSeconds: 90),
            PlannedExercise(name: "Lat Pulldown", sets: 3, reps: "10", notes: nil, isKeyLift: false, restSeconds: 60)
        ],
        estimatedMinutes: 60,
        dayOfWeek: 1,
        planName: "Upper/Lower Split",
        planId: nil
    )

    WorkoutExecutionView(
        viewModel: WorkoutExecutionViewModel(workout: mockWorkout, planId: nil),
        onComplete: { _ in }
    )
}
