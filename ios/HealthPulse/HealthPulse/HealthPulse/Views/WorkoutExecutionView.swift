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

                // Exercise list
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.exerciseLogs.indices, id: \.self) { index in
                            ExerciseLogCard(
                                exerciseLog: $viewModel.exerciseLogs[index],
                                onAddSet: { viewModel.addSet(to: index) },
                                onDeleteSet: { setIndex in viewModel.deleteSet(from: index, setIndex: setIndex) }
                            )
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

// MARK: - Exercise Log Card

struct ExerciseLogCard: View {
    @Binding var exerciseLog: ExerciseLogEntry

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
                    // Column headers
                    HStack {
                        Text("Set")
                            .frame(width: 35, alignment: .leading)
                        Text("Weight")
                            .frame(width: 80)
                        Text("Reps")
                            .frame(width: 60)
                        Text("RPE")
                            .frame(width: 50)
                        Spacer()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    ForEach(exerciseLog.sets.indices, id: \.self) { setIndex in
                        SetLogRow(
                            setNumber: setIndex + 1,
                            setLog: $exerciseLog.sets[setIndex],
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
}

// MARK: - Set Log Row

struct SetLogRow: View {
    let setNumber: Int
    @Binding var setLog: SetLogEntry
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Text("\(setNumber)")
                .font(.subheadline.bold())
                .frame(width: 35, alignment: .leading)

            // Weight input
            HStack(spacing: 4) {
                TextField("0", value: $setLog.weight, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                Text("kg")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 80)

            // Reps input
            TextField("0", value: $setLog.reps, format: .number)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)

            // RPE selector
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

            Spacer()

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red.opacity(0.7))
            }
        }
    }
}

// MARK: - Exercise Log Entry (View Model)

struct ExerciseLogEntry: Identifiable {
    let id = UUID()
    let name: String
    let isKeyLift: Bool
    let targetSetsReps: String?
    var sets: [SetLogEntry]
    var isCompleted: Bool

    init(from planned: PlannedExercise, isKeyLift: Bool = false) {
        self.name = planned.name
        self.isKeyLift = isKeyLift
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
    init(name: String, isKeyLift: Bool, targetSetsReps: String?, sets: [SetLogEntry], isCompleted: Bool) {
        self.name = name
        self.isKeyLift = isKeyLift
        self.targetSetsReps = targetSetsReps
        self.sets = sets
        self.isCompleted = isCompleted
    }
}

struct SetLogEntry: Identifiable {
    let id = UUID()
    var weight: Double = 0
    var reps: Int = 0
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
            log.isCompleted || log.sets.contains { $0.weight > 0 && $0.reps > 0 }
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
        let newExercise = ExerciseLogEntry(
            name: name,
            isKeyLift: false,  // Added exercises are accessories
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
                    // Filter out empty sets
                    let validSets = log.sets.filter { $0.weight > 0 && $0.reps > 0 }

                    // Skip exercises with no data
                    guard log.isCompleted || !validSets.isEmpty else { return nil }

                    let setLogs = validSets.map { entry in
                        SetLog(
                            weight: entry.weight,
                            reps: entry.reps,
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
            Group {
                if isLoading {
                    ProgressView("Loading exercises...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // Quick add common exercises
                        if searchText.isEmpty {
                            Section("Common Exercises") {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                    ForEach(commonExercises.prefix(8), id: \.self) { exercise in
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
                                }
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                            }
                        }

                        // Search results or full list
                        Section(searchText.isEmpty ? "All Exercises" : "Search Results") {
                            if filteredExercises.isEmpty && !searchText.isEmpty {
                                // Allow adding custom exercise
                                Button {
                                    addExercise(searchText)
                                } label: {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(.green)
                                        Text("Add \"\(searchText)\" as custom exercise")
                                    }
                                }
                            } else {
                                ForEach(filteredExercises) { exercise in
                                    Button {
                                        addExercise(exercise.name)
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(exercise.name)
                                                    .foregroundStyle(.primary)
                                                Text(exercise.category.capitalized)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "plus.circle")
                                                .foregroundStyle(.green)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search exercises")
                }
            }
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
