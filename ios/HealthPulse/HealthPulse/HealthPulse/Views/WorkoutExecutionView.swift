//
//  WorkoutExecutionView.swift
//  HealthPulse
//
//  Quick performance logging view for executing planned workouts
//

import SwiftUI
import Combine

struct WorkoutExecutionView: View {
    let workout: TodayWorkoutResponse
    let planId: UUID?
    let onComplete: ([PRInfo]) -> Void

    @StateObject private var viewModel: WorkoutExecutionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showExercisePicker = false

    init(workout: TodayWorkoutResponse, planId: UUID?, onComplete: @escaping ([PRInfo]) -> Void) {
        self.workout = workout
        self.planId = planId
        self.onComplete = onComplete
        _viewModel = StateObject(wrappedValue: WorkoutExecutionViewModel(workout: workout, planId: planId))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Workout header
                WorkoutHeader(
                    workoutName: workout.workoutName ?? "Workout",
                    focus: workout.workoutFocus,
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
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green.opacity(0.1))
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
                Button {
                    viewModel.completeWorkout { prs in
                        onComplete(prs)
                        dismiss()
                    }
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
                .background(viewModel.canComplete ? Color.green : Color.gray)
                .foregroundStyle(.white)
                .disabled(!viewModel.canComplete || viewModel.isSaving)
            }
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.stopTimer()
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.startTimer()
            }
            .onDisappear {
                viewModel.stopTimer()
            }
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
        .background(Color(.secondarySystemBackground))
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
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
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
}

// MARK: - Set Log Row

struct SetLogRow: View {
    let setNumber: Int
    @Binding var setLog: SetLogEntry
    let inputType: ExerciseInputType
    let onDelete: () -> Void

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
        HStack(spacing: 4) {
            TextField("", value: $setLog.weight, format: .number)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .overlay(alignment: .leading) {
                    if setLog.weight == nil {
                        Text("0")
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 8)
                            .allowsHitTesting(false)
                    }
                }
            Text("kg")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 80)
    }

    private var repsInput: some View {
        TextField("", value: $setLog.reps, format: .number)
            .keyboardType(.numberPad)
            .textFieldStyle(.roundedBorder)
            .frame(width: 60)
            .overlay(alignment: .leading) {
                if setLog.reps == nil {
                    Text("0")
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 8)
                        .allowsHitTesting(false)
                }
            }
    }

    private var rpeSelector: some View {
        Menu {
            ForEach(6...10, id: \.self) { rpe in
                Button("RPE \(rpe)") {
                    setLog.rpe = rpe
                }
            }
            Button("Clear") {
                setLog.rpe = nil
            }
        } label: {
            Text(setLog.rpe != nil ? "\(setLog.rpe!)" : "-")
                .font(.subheadline)
                .frame(width: 40)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .frame(width: 50)
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

// MARK: - Exercise Log Entry (View Model)

/// Infer exercise input type from reps string (e.g., "60s" → timeOnly)
private func inferInputType(from reps: String?, exerciseName: String) -> ExerciseInputType {
    // Check reps string for time indicator
    if let reps = reps {
        let lowercased = reps.lowercased()
        if lowercased.hasSuffix("s") || lowercased.contains("sec") {
            return .timeOnly
        }
        if lowercased.contains("km") || lowercased.contains("mi") || lowercased.contains("m ") {
            return .distanceAndTime
        }
    }

    // Check known bodyweight exercises
    let bodyweightExercises = ["push-up", "pushup", "pull-up", "pullup", "chin-up", "chinup",
                                "dip", "burpee", "sit-up", "situp", "crunch", "lunge"]
    let timedExercises = ["plank", "wall sit", "dead hang", "hollow hold", "l-sit"]

    let nameLower = exerciseName.lowercased()
    if timedExercises.contains(where: { nameLower.contains($0) }) {
        return .timeOnly
    }
    if bodyweightExercises.contains(where: { nameLower.contains($0) }) {
        return .repsOnly
    }

    return .weightAndReps
}

struct ExerciseLogEntry: Identifiable {
    let id = UUID()
    let name: String
    let isKeyLift: Bool
    let inputType: ExerciseInputType
    let targetSetsReps: String?
    var sets: [SetLogEntry]
    var isCompleted: Bool

    init(from planned: PlannedExercise, isKeyLift: Bool = false) {
        self.name = planned.name
        self.isKeyLift = isKeyLift
        self.inputType = inferInputType(from: planned.reps, exerciseName: planned.name)

        if let sets = planned.sets, let reps = planned.reps {
            self.targetSetsReps = "\(sets) x \(reps)"
            // Pre-populate empty sets based on target
            self.sets = (0..<sets).map { _ in SetLogEntry() }
        } else {
            self.targetSetsReps = nil
            self.sets = isKeyLift ? [SetLogEntry(), SetLogEntry(), SetLogEntry()] : []
        }
        self.isCompleted = false
    }

    // For adding custom exercises during workout
    init(name: String, isKeyLift: Bool, inputType: ExerciseInputType = .weightAndReps, targetSetsReps: String?, sets: [SetLogEntry], isCompleted: Bool) {
        self.name = name
        self.isKeyLift = isKeyLift
        self.inputType = inputType
        self.targetSetsReps = targetSetsReps
        self.sets = sets
        self.isCompleted = isCompleted
    }
}

struct SetLogEntry: Identifiable {
    let id = UUID()
    var weight: Double?                 // For weight_and_reps (nil = empty field)
    var reps: Int?                      // For weight_and_reps, reps_only
    var duration: Int?                  // For time_only (seconds)
    var distance: Double?               // For distance_and_time (km)
    var rpe: Int?
    var completedAt: Date?
}

// MARK: - View Model

@MainActor
class WorkoutExecutionViewModel: ObservableObject {
    @Published var exerciseLogs: [ExerciseLogEntry] = []
    @Published var elapsedTime: TimeInterval = 0
    @Published var isTimerRunning = false
    @Published var isSaving = false

    private let workout: TodayWorkoutResponse
    private let planId: UUID?
    private var timer: Timer?
    private let startTime = Date()

    init(workout: TodayWorkoutResponse, planId: UUID?) {
        self.workout = workout
        self.planId = planId

        // Initialize exercise logs from planned exercises
        if let exercises = workout.exercises {
            // First 2-3 exercises are typically key lifts
            exerciseLogs = exercises.enumerated().map { index, exercise in
                ExerciseLogEntry(from: exercise, isKeyLift: index < 2)
            }
        }
    }

    var canComplete: Bool {
        // At least one set logged or one exercise completed
        exerciseLogs.contains { log in
            if log.isCompleted { return true }

            // Check sets based on input type
            return log.sets.contains { set in
                switch log.inputType {
                case .weightAndReps:
                    return (set.weight ?? 0) > 0 && (set.reps ?? 0) > 0
                case .repsOnly:
                    return (set.reps ?? 0) > 0
                case .timeOnly:
                    return (set.duration ?? 0) > 0
                case .distanceAndTime:
                    return (set.distance ?? 0) > 0 || (set.duration ?? 0) > 0
                }
            }
        }
    }

    func startTimer() {
        isTimerRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.elapsedTime = Date().timeIntervalSince(self?.startTime ?? Date())
            }
        }
    }

    func stopTimer() {
        isTimerRunning = false
        timer?.invalidate()
        timer = nil
    }

    func addSet(to exerciseIndex: Int) {
        guard exerciseIndex < exerciseLogs.count else { return }
        exerciseLogs[exerciseIndex].sets.append(SetLogEntry())
    }

    func deleteSet(from exerciseIndex: Int, setIndex: Int) {
        guard exerciseIndex < exerciseLogs.count,
              setIndex < exerciseLogs[exerciseIndex].sets.count else { return }
        exerciseLogs[exerciseIndex].sets.remove(at: setIndex)
    }

    func addExercise(name: String) {
        let detectedInputType = inferInputType(from: nil, exerciseName: name)
        let newExercise = ExerciseLogEntry(
            name: name,
            isKeyLift: false,  // Added exercises are accessories
            inputType: detectedInputType,
            targetSetsReps: nil,
            sets: [SetLogEntry()],
            isCompleted: false
        )
        exerciseLogs.append(newExercise)
    }

    func completeWorkout(completion: @escaping ([PRInfo]) -> Void) {
        isSaving = true
        stopTimer()

        Task {
            do {
                // Convert exercise logs to API format
                let exercises = exerciseLogs.compactMap { log -> ExerciseLog? in
                    // Filter out empty sets based on input type
                    let validSets = log.sets.filter { set in
                        switch log.inputType {
                        case .weightAndReps:
                            return (set.weight ?? 0) > 0 && (set.reps ?? 0) > 0
                        case .repsOnly:
                            return (set.reps ?? 0) > 0
                        case .timeOnly:
                            return (set.duration ?? 0) > 0
                        case .distanceAndTime:
                            return (set.distance ?? 0) > 0 || (set.duration ?? 0) > 0
                        }
                    }

                    // Skip exercises with no data
                    guard log.isCompleted || !validSets.isEmpty else { return nil }

                    let setLogs = validSets.map { entry in
                        SetLog(
                            weight: entry.weight ?? 0,
                            reps: entry.reps ?? 0,
                            rpe: entry.rpe,
                            completedAt: entry.completedAt ?? Date()
                        )
                    }

                    return ExerciseLog(
                        name: log.name,
                        isKeyLift: log.isKeyLift,
                        sets: setLogs,
                        isCompleted: log.isCompleted
                    )
                }

                let sessionRequest = WorkoutSessionRequest(
                    planId: planId,
                    plannedWorkoutName: workout.workoutName,
                    startedAt: startTime,
                    completedAt: Date(),
                    durationMinutes: Int(elapsedTime / 60),
                    exercises: exercises,
                    overallRating: nil,
                    notes: nil
                )

                let response = try await APIService.shared.logWorkoutSession(sessionRequest)

                await MainActor.run {
                    isSaving = false
                    HapticsManager.shared.success()
                    completion(response.prsAchieved)
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    HapticsManager.shared.error()
                    ToastManager.shared.error("Failed to save workout")
                    print("Failed to save workout: \(error)")
                }
            }
        }
    }
}

// MARK: - PR Celebration View

struct PRCelebrationView: View {
    let prs: [PRInfo]
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 64))
                .foregroundStyle(.yellow)

            Text("New Personal Records!")
                .font(.title.bold())

            VStack(spacing: 12) {
                ForEach(prs) { pr in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pr.exerciseName)
                                .font(.headline)
                            Text(pr.recordType.uppercased())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(pr.value)) kg")
                                .font(.title3.bold())
                                .foregroundStyle(.green)
                            if let previous = pr.previousValue {
                                Text("+\(Int(pr.value - previous)) kg")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)

            Button("Awesome!") {
                onDismiss()
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
        .padding(.vertical, 32)
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
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text("💡 Tip: Most working sets should be RPE 7-9. Leave RPE 10 for PR attempts.")
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
                .background(Color.green.opacity(0.1))
                .foregroundStyle(.green)
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
        workoutName: "Upper Body A",
        workoutFocus: "Chest Focus",
        exercises: [
            PlannedExercise(name: "Bench Press", sets: 4, reps: "5", notes: nil),
            PlannedExercise(name: "Overhead Press", sets: 3, reps: "8", notes: nil),
            PlannedExercise(name: "Lat Pulldown", sets: 3, reps: "10", notes: nil)
        ],
        estimatedMinutes: 60,
        dayOfWeek: 1,
        planName: "Upper/Lower Split"
    )

    return WorkoutExecutionView(workout: mockWorkout, planId: nil) { _ in }
}
