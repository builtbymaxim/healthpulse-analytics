//
//  TrainingPlanView.swift
//  HealthPulse
//
//  Training plan selection and customization view
//

import SwiftUI
import Combine

struct TrainingPlanView: View {
    @StateObject private var viewModel = TrainingPlanViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if viewModel.isLoading {
                        ProgressView("Loading plans...")
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        // Active Plan Section
                        if let activePlan = viewModel.activePlan {
                            ActivePlanCard(
                                plan: activePlan,
                                onChangePlan: { viewModel.showTemplates = true },
                                onDeactivate: { viewModel.deactivatePlan() },
                                onEdit: {
                                    viewModel.planToEdit = activePlan
                                    viewModel.showCustomBuilder = true
                                },
                                onCreateNew: {
                                    viewModel.planToEdit = nil
                                    viewModel.showCustomBuilder = true
                                }
                            )
                        } else {
                            NoPlanCard(
                            onSelectPlan: { viewModel.showTemplates = true },
                            onCreateCustom: {
                                viewModel.planToEdit = nil
                                viewModel.showCustomBuilder = true
                            }
                        )
                        }

                        // Weekly Schedule with exercise detail
                        if let activePlan = viewModel.activePlan {
                            WeeklyScheduleCard(
                                schedule: activePlan.schedule,
                                workouts: activePlan.workouts,
                                customizations: activePlan.customizations,
                                onSwapExercise: { exerciseName, replacement in
                                    viewModel.swapExercise(original: exerciseName, replacement: replacement)
                                }
                            )
                        }

                        // Quick Stats
                        if !viewModel.recentSessions.isEmpty {
                            RecentSessionsCard(sessions: viewModel.recentSessions)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Training Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $viewModel.showTemplates) {
                TemplateSelectionView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showCustomBuilder, onDismiss: {
                viewModel.planToEdit = nil
            }) {
                CustomPlanBuilderView(prefillPlanId: viewModel.planToEdit?.id) {
                    viewModel.planToEdit = nil
                    Task { await viewModel.loadData() }
                }
            }
            .sheet(isPresented: $viewModel.showEditSchedule) {
                if let plan = viewModel.activePlan {
                    EditScheduleSheet(
                        planId: plan.id,
                        planName: plan.name,
                        currentSchedule: plan.schedule,
                        availableWorkouts: viewModel.availableWorkouts,
                        onSave: { newSchedule in
                            viewModel.updateSchedule(newSchedule)
                        }
                    )
                }
            }
            .alert("Deactivate Plan?", isPresented: $viewModel.showDeactivateConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Deactivate", role: .destructive) {
                    viewModel.confirmDeactivatePlan()
                }
            } message: {
                Text("This will remove your current training plan. You can activate a new one anytime.")
            }
            .task {
                await viewModel.loadData()
            }
            .refreshable {
                await viewModel.loadData()
            }
        }
    }
}

// MARK: - Active Plan Card

struct ActivePlanCard: View {
    let plan: TrainingPlanSummary
    let onChangePlan: () -> Void
    let onDeactivate: () -> Void
    let onEdit: () -> Void
    let onCreateNew: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active Plan")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(plan.name)
                        .font(.title2.bold())
                }

                Spacer()

                Button {
                    onEdit()
                    HapticsManager.shared.light()
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppTheme.primary.opacity(0.1))
                        .foregroundStyle(AppTheme.primary)
                        .clipShape(Capsule())
                }

                Menu {
                    Button("Create New Custom Plan") { onCreateNew() }
                    Button("Change Plan", action: onChangePlan)
                    Button("Deactivate", role: .destructive, action: onDeactivate)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }

            if let description = plan.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 20) {
                Label("\(plan.daysPerWeek) days/week", systemImage: "calendar")
                Label("\(plan.schedule.count) workouts", systemImage: "dumbbell.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .cardShadow()
    }
}

// MARK: - No Plan Card

struct NoPlanCard: View {
    let onSelectPlan: () -> Void
    let onCreateCustom: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("No Active Training Plan")
                    .font(.headline)
                Text("Select a plan to get structured workouts tailored to your goals")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                onSelectPlan()
                HapticsManager.shared.medium()
            } label: {
                Label("Browse Plans", systemImage: "list.bullet")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.primary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                onCreateCustom()
                HapticsManager.shared.medium()
            } label: {
                Label("Build Custom Plan", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.primary.opacity(0.12))
                    .foregroundStyle(AppTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .cardShadow()
    }
}

// MARK: - Weekly Schedule Card

struct WeeklyScheduleCard: View {
    let schedule: [String: String]
    var workouts: [TemplateWorkout]?
    var customizations: [String: [String: String]]?
    var onSwapExercise: ((String, String) -> Void)?

    @State private var expandedDay: Int?
    @State private var swappingExercise: PlannedExercise?

    private let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Schedule")
                .font(.headline)

            VStack(spacing: 4) {
                ForEach(1...7, id: \.self) { day in
                    VStack(spacing: 0) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedDay = expandedDay == day ? nil : day
                            }
                            HapticsManager.shared.selection()
                        } label: {
                            HStack {
                                Text(dayNames[day - 1])
                                    .font(.subheadline)
                                    .frame(width: 40, alignment: .leading)

                                if let workout = schedule[String(day)] {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 8, height: 8)
                                        Text(workout)
                                            .font(.subheadline)
                                    }
                                } else {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 8, height: 8)
                                        Text("Rest")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                if schedule[String(day)] != nil, workouts != nil {
                                    Image(systemName: expandedDay == day ? "chevron.up" : "chevron.down")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .foregroundStyle(.primary)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)

                        // Expanded exercise list for this day
                        if expandedDay == day, let workout = workouts?.first(where: { $0.day == day }) {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(workout.exercises ?? [], id: \.name) { exercise in
                                    HStack(spacing: 10) {
                                        Image(systemName: exercise.isKeyLift == true ? "star.fill" : "circle.fill")
                                            .font(.system(size: exercise.isKeyLift == true ? 10 : 5))
                                            .foregroundStyle(exercise.isKeyLift == true ? .yellow : .secondary)

                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(exercise.name)
                                                .font(.caption.bold())
                                            if let sets = exercise.sets, let reps = exercise.reps {
                                                Text("\(sets) x \(reps)")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }

                                        Spacer()

                                        // Swap button
                                        if onSwapExercise != nil {
                                            Button {
                                                swappingExercise = exercise
                                            } label: {
                                                Image(systemName: "arrow.triangle.2.circlepath")
                                                    .font(.caption)
                                                    .foregroundStyle(.green)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 2)
                                    .padding(.leading, 48)
                                }
                            }
                            .padding(.bottom, 8)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .cardShadow()
        .sheet(item: $swappingExercise) { exercise in
            ExerciseSwapSheet(exercise: exercise) { replacement in
                onSwapExercise?(exercise.name, replacement)
            }
        }
    }
}

// MARK: - Exercise Swap Sheet

struct ExerciseSwapSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: PlannedExercise
    let onSwap: (String) -> Void

    // Static exercise alternatives grouped by muscle category
    private var alternatives: [String] {
        let muscleGroups: [String: [String]] = [
            "Barbell Squat": ["Goblet Squat", "Leg Press", "Front Squat", "Hack Squat"],
            "Front Squat": ["Barbell Squat", "Goblet Squat", "Leg Press"],
            "Goblet Squat": ["Barbell Squat", "Leg Press", "Front Squat"],
            "Bench Press": ["Dumbbell Bench Press", "Incline Dumbbell Press", "Push-Ups", "Machine Chest Press"],
            "Incline Bench Press": ["Incline Dumbbell Press", "Bench Press", "Landmine Press"],
            "Incline Dumbbell Press": ["Incline Bench Press", "Bench Press", "Cable Flyes"],
            "Overhead Press": ["Arnold Press", "Dumbbell Shoulder Press", "Landmine Press"],
            "Arnold Press": ["Overhead Press", "Dumbbell Shoulder Press", "Lateral Raise"],
            "Deadlift": ["Romanian Deadlift", "Trap Bar Deadlift", "Sumo Deadlift"],
            "Romanian Deadlift": ["Stiff-Leg Deadlift", "Good Mornings", "Deadlift"],
            "Trap Bar Deadlift": ["Deadlift", "Romanian Deadlift", "Barbell Hip Hinge"],
            "Barbell Row": ["Dumbbell Row", "Cable Row", "T-Bar Row", "Seated Cable Row"],
            "Cable Row": ["Barbell Row", "Dumbbell Row", "Seated Cable Row"],
            "Seated Cable Row": ["Barbell Row", "Cable Row", "T-Bar Row"],
            "Chin-Ups": ["Lat Pulldown", "Pull-Ups", "Band-Assisted Pull-Ups"],
            "Lat Pulldown": ["Chin-Ups", "Pull-Ups", "Cable Pullover"],
            "Hip Thrust": ["Glute Bridge", "Cable Pull-Through", "Hip Extension Machine"],
            "Glute Bridge": ["Hip Thrust", "Cable Pull-Through", "Single-Leg Glute Bridge"],
            "Bulgarian Split Squat": ["Lunges", "Walking Lunges", "Step-Ups", "Reverse Lunges"],
            "Walking Lunges": ["Bulgarian Split Squat", "Reverse Lunges", "Step-Ups"],
            "Leg Press": ["Barbell Squat", "Hack Squat", "Goblet Squat"],
            "Leg Curl": ["Nordic Curl", "Swiss Ball Curl", "Seated Leg Curl"],
            "Lateral Raise": ["Cable Lateral Raise", "Dumbbell Lateral Raise", "Machine Lateral Raise"],
            "Tricep Pushdown": ["Skull Crushers", "Overhead Tricep Extension", "Dips"],
            "Hammer Curls": ["Barbell Curls", "Incline Dumbbell Curls", "Cable Curls"],
            "Face Pulls": ["Band Pull-Apart", "Reverse Flyes", "Cable External Rotation"],
            "Plank": ["Dead Bug", "Ab Rollout", "Pallof Press"],
            "Power Clean": ["Hang Clean", "Kettlebell Swing", "Dumbbell Power Clean"],
            "Box Jumps": ["Broad Jumps", "Tuck Jumps", "Squat Jumps"],
        ]
        return muscleGroups[exercise.name] ?? ["Dumbbell variation", "Cable variation", "Machine variation"]
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Current")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(exercise.name)
                            .font(.subheadline.bold())
                    }

                    if let sets = exercise.sets, let reps = exercise.reps {
                        HStack {
                            Text("Prescription")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(sets) x \(reps)")
                                .font(.subheadline)
                        }
                    }
                }

                Section("Alternatives") {
                    ForEach(alternatives, id: \.self) { alt in
                        Button {
                            onSwap(alt)
                            dismiss()
                        } label: {
                            HStack {
                                Text(alt)
                                Spacer()
                                Image(systemName: "arrow.right.circle")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Swap Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Recent Sessions Card

struct RecentSessionsCard: View {
    let sessions: [WorkoutSession]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Workouts")
                    .font(.headline)
                Spacer()
                Text("\(sessions.count) this month")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(sessions.prefix(3)) { session in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.plannedWorkoutName ?? "Workout")
                            .font(.subheadline.bold())
                        Text(session.startedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let duration = session.durationMinutes {
                        Text("\(duration) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let rating = session.overallRating {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.caption2)
                                    .foregroundStyle(star <= rating ? .yellow : .gray.opacity(0.3))
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .cardShadow()
    }
}

// MARK: - Template Selection View

struct TemplateSelectionView: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTemplate: PlanTemplate?
    @State private var showActivationSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoadingTemplates {
                    ProgressView("Loading templates...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.templates.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No templates available")
                            .font(.headline)
                        Text("Check back later for new training plans")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.templates) { template in
                                TemplateCard(
                                    template: template,
                                    isSelected: selectedTemplate?.id == template.id,
                                    onTap: {
                                        selectedTemplate = template
                                        HapticsManager.shared.selection()
                                    }
                                )
                            }

                            Button {
                                viewModel.planToEdit = nil
                                viewModel.showCustomBuilder = true
                                dismiss()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "pencil.and.ruler")
                                    Text("Build from Scratch")
                                }
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppTheme.primary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(AppTheme.primary.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .padding(.top, 8)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Choose a Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Activate") {
                        showActivationSheet = true
                    }
                    .disabled(selectedTemplate == nil)
                }
            }
            .sheet(isPresented: $showActivationSheet) {
                if let template = selectedTemplate {
                    PlanActivationSheet(
                        template: template,
                        viewModel: viewModel,
                        onActivated: { dismiss() }
                    )
                }
            }
            .task {
                await viewModel.loadTemplates()
            }
        }
    }
}

// MARK: - Plan Activation Sheet

struct PlanActivationSheet: View {
    let template: PlanTemplate
    @ObservedObject var viewModel: TrainingPlanViewModel
    let onActivated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var workoutTime: Date
    @State private var addToCalendar = true
    @State private var conflicts: [Int: [String]] = [:]
    @State private var isCheckingConflicts = false
    @State private var isActivating = false

    private let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    private let calendarService = CalendarSyncService.shared

    init(template: PlanTemplate, viewModel: TrainingPlanViewModel, onActivated: @escaping () -> Void) {
        self.template = template
        self.viewModel = viewModel
        self.onActivated = onActivated
        _workoutTime = State(initialValue: CalendarSyncService.shared.defaultWorkoutTime)
    }

    /// Build the schedule dict from template workouts
    private var schedule: [String: String] {
        var s: [String: String] = [:]
        if let workouts = template.workouts {
            for workout in workouts {
                s[String(workout.day)] = workout.name
            }
        }
        return s
    }

    var body: some View {
        NavigationStack {
            List {
                // Time picker
                Section {
                    DatePicker("Preferred Workout Time",
                               selection: $workoutTime,
                               displayedComponents: .hourAndMinute)
                } footer: {
                    Text("Calendar events will be created at this time.")
                }

                // Schedule with conflict indicators
                Section {
                    ForEach(1...7, id: \.self) { day in
                        if let workoutName = schedule[String(day)] {
                            HStack {
                                Text(dayNames[day - 1])
                                    .frame(width: 90, alignment: .leading)

                                Text(workoutName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)

                                Spacer()

                                if let conflictTitles = conflicts[day], !conflictTitles.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.orange)
                                            .font(.caption)
                                        Text(conflictTitles.first ?? "Conflict")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                            .lineLimit(1)
                                    }
                                } else if !isCheckingConflicts {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                            .font(.caption)
                                        Text("Free")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Schedule")
                        if isCheckingConflicts {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                } footer: {
                    if !conflicts.isEmpty {
                        Text("Orange warnings show existing calendar events at your chosen workout time.")
                    }
                }

                // Calendar toggle
                Section {
                    Toggle("Add workouts to calendar", isOn: $addToCalendar)
                } footer: {
                    Text("Creates events in a dedicated HealthPulse calendar for the next 4 weeks.")
                }
            }
            .navigationTitle("Activate \(template.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Activate") {
                        activatePlan()
                    }
                    .disabled(isActivating)
                    .bold()
                }
            }
            .onChange(of: workoutTime) { _, _ in
                refreshConflicts()
            }
            .task {
                refreshConflicts()
            }
        }
    }

    private func refreshConflicts() {
        isCheckingConflicts = true
        // Update the service's time temporarily for conflict checking
        let originalTime = calendarService.defaultWorkoutTime
        calendarService.defaultWorkoutTime = workoutTime

        let durationMinutes = template.workouts?.first?.estimatedMinutes ?? 60
        conflicts = calendarService.checkConflicts(schedule: schedule, durationMinutes: durationMinutes)

        calendarService.defaultWorkoutTime = originalTime
        isCheckingConflicts = false
    }

    private func activatePlan() {
        isActivating = true

        // Save preferred workout time
        calendarService.defaultWorkoutTime = workoutTime
        calendarService.savePreferences()

        // Handle calendar sync preference
        if addToCalendar {
            calendarService.calendarSyncEnabled = true
            calendarService.savePreferences()

            Task {
                // Request access if needed
                if !calendarService.isAuthorized {
                    await calendarService.requestAccess()
                }

                // Activate the plan (ViewModel's activatePlan triggers calendar sync)
                viewModel.activatePlan(template: template)

                isActivating = false
                dismiss()
                onActivated()
            }
        } else {
            viewModel.activatePlan(template: template)
            isActivating = false
            dismiss()
            onActivated()
        }
    }
}

// MARK: - Template Card

struct TemplateCard: View {
    let template: PlanTemplate
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if let description = template.description {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                    }
                }

                HStack(spacing: 12) {
                    Label("\(template.daysPerWeek) days", systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label(template.modality.capitalized, systemImage: modalityIcon(template.modality))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(template.difficulty.capitalized)
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(difficultyColor(template.difficulty).opacity(0.15))
                        .foregroundStyle(difficultyColor(template.difficulty))
                        .clipShape(Capsule())
                }

                // Workout preview
                if let workouts = template.workouts, !workouts.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(workouts.prefix(3), id: \.day) { workout in
                            HStack {
                                Text("Day \(workout.day)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 50, alignment: .leading)
                                Text(workout.name)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                            }
                        }
                        if workouts.count > 3 {
                            Text("+\(workouts.count - 3) more")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .padding()
            .background(AppTheme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? AppTheme.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func modalityIcon(_ modality: String) -> String {
        switch modality.lowercased() {
        case "gym": return "dumbbell.fill"
        case "home": return "house.fill"
        case "outdoor": return "figure.run"
        default: return "arrow.triangle.2.circlepath"
        }
    }

    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty.lowercased() {
        case "beginner": return .green
        case "intermediate": return .orange
        case "advanced": return .red
        default: return .gray
        }
    }
}

// MARK: - Edit Schedule Sheet

struct EditScheduleSheet: View {
    let planId: UUID
    let planName: String
    let currentSchedule: [String: String]
    let availableWorkouts: [String]
    let onSave: ([String: String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var editedSchedule: [String: String?]
    @State private var isSaving = false
    @State private var conflicts: [Int: [String]] = [:]

    private let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    private let calendarService = CalendarSyncService.shared

    init(planId: UUID, planName: String, currentSchedule: [String: String], availableWorkouts: [String], onSave: @escaping ([String: String]) -> Void) {
        self.planId = planId
        self.planName = planName
        self.currentSchedule = currentSchedule
        self.availableWorkouts = availableWorkouts
        self.onSave = onSave
        // Initialize with current schedule (nil for rest days)
        var initial: [String: String?] = [:]
        for day in 1...7 {
            initial[String(day)] = currentSchedule[String(day)]
        }
        _editedSchedule = State(initialValue: initial)
    }

    /// Current schedule as non-optional dict for conflict checking
    private var activeSchedule: [String: String] {
        var s: [String: String] = [:]
        for (day, workout) in editedSchedule {
            if let workout = workout {
                s[day] = workout
            }
        }
        return s
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(1...7, id: \.self) { day in
                        HStack {
                            Text(dayNames[day - 1])
                                .frame(width: 100, alignment: .leading)

                            Spacer()

                            // Conflict indicator
                            if let conflictTitles = conflicts[day], !conflictTitles.isEmpty {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.caption2)
                            }

                            Menu {
                                Button("Rest Day") {
                                    editedSchedule[String(day)] = nil
                                    refreshConflicts()
                                }
                                Divider()
                                ForEach(availableWorkouts, id: \.self) { workout in
                                    Button(workout) {
                                        editedSchedule[String(day)] = workout
                                        refreshConflicts()
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    if let workout = editedSchedule[String(day)] ?? nil {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 8, height: 8)
                                        Text(workout)
                                            .foregroundStyle(.primary)
                                    } else {
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 8, height: 8)
                                        Text("Rest")
                                            .foregroundStyle(.secondary)
                                    }
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Weekly Schedule")
                } footer: {
                    if !conflicts.isEmpty {
                        Text("Days with ⚠ have calendar events at your workout time.")
                    } else {
                        Text("Tap a day to change the workout or set it as a rest day.")
                    }
                }

                Section {
                    let workoutDays = editedSchedule.values.compactMap { $0 }.count
                    HStack {
                        Text("Workout Days")
                        Spacer()
                        Text("\(workoutDays) per week")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Rest Days")
                        Spacer()
                        Text("\(7 - workoutDays) per week")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Summary")
                }
            }
            .navigationTitle("Edit Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSchedule()
                    }
                    .disabled(isSaving)
                }
            }
            .task {
                refreshConflicts()
            }
        }
    }

    private func refreshConflicts() {
        guard calendarService.calendarSyncEnabled, calendarService.isAuthorized else { return }
        conflicts = calendarService.checkConflicts(schedule: activeSchedule)
    }

    private func saveSchedule() {
        isSaving = true
        onSave(activeSchedule)
        dismiss()
    }
}

// MARK: - View Model

@MainActor
class TrainingPlanViewModel: ObservableObject {
    @Published var activePlan: TrainingPlanSummary?
    @Published var templates: [PlanTemplate] = []
    @Published var recentSessions: [WorkoutSession] = []
    @Published var availableWorkouts: [String] = []
    @Published var isLoading = false
    @Published var isLoadingTemplates = false
    @Published var showTemplates = false
    @Published var showEditSchedule = false
    @Published var showDeactivateConfirmation = false
    @Published var showCustomBuilder = false
    @Published var planToEdit: TrainingPlanSummary? = nil
    @Published var error: String?

    func loadData() async {
        isLoading = true
        error = nil

        do {
            async let planTask = APIService.shared.getActiveTrainingPlan()
            async let sessionsTask = APIService.shared.getWorkoutSessions(days: 30)
            async let templatesTask = APIService.shared.getTrainingPlanTemplates()

            let (plan, sessions, allTemplates) = try await (planTask, sessionsTask, templatesTask)
            activePlan = plan
            recentSessions = sessions

            // Extract available workouts from templates
            if let plan = plan {
                // Find the matching template to get workout names
                if let matchingTemplate = allTemplates.first(where: { $0.name == plan.name }),
                   let workouts = matchingTemplate.workouts {
                    availableWorkouts = workouts.map { $0.name }
                } else {
                    // Fallback: use current schedule workout names
                    availableWorkouts = Array(Set(plan.schedule.values)).sorted()
                }
            }
        } catch {
            self.error = error.localizedDescription
            print("Failed to load training plan data: \(error)")
        }

        isLoading = false
    }

    func loadTemplates() async {
        isLoadingTemplates = true

        do {
            templates = try await APIService.shared.getTrainingPlanTemplates()
        } catch {
            print("Failed to load templates: \(error)")
        }

        isLoadingTemplates = false
    }

    func activatePlan(template: PlanTemplate) {
        Task {
            do {
                // Build schedule from template workouts
                var schedule: [String: String] = [:]
                if let workouts = template.workouts {
                    for workout in workouts {
                        schedule[String(workout.day)] = workout.name
                    }
                }

                _ = try await APIService.shared.activateTrainingPlan(
                    templateId: template.id,
                    schedule: schedule
                )

                // Reload data
                await loadData()
                ToastManager.shared.success("Plan activated!")
                HapticsManager.shared.success()

                // Sync to calendar
                await CalendarSyncService.shared.syncCalendar(schedule: schedule, planName: template.name)
            } catch {
                ToastManager.shared.error("Failed to activate plan")
                print("Failed to activate plan: \(error)")
            }
        }
    }

    func deactivatePlan() {
        showDeactivateConfirmation = true
    }

    func confirmDeactivatePlan() {
        Task {
            do {
                _ = try await APIService.shared.deactivateTrainingPlan()
                activePlan = nil
                ToastManager.shared.success("Plan deactivated")

                // Remove calendar events
                await CalendarSyncService.shared.syncCalendar(schedule: nil, planName: nil)
            } catch {
                ToastManager.shared.error("Failed to deactivate plan")
                print("Failed to deactivate plan: \(error)")
            }
        }
    }

    func swapExercise(original: String, replacement: String) {
        guard let plan = activePlan else { return }

        // Merge with existing swaps
        var swaps = plan.customizations?["exerciseSwaps"] ?? [:]
        swaps[original] = replacement

        Task {
            do {
                _ = try await APIService.shared.updateTrainingPlan(
                    planId: plan.id,
                    customizations: ["exerciseSwaps": swaps]
                )
                // Reload to get updated plan with swaps applied
                await loadData()
                ToastManager.shared.success("Exercise swapped!")
                HapticsManager.shared.success()
            } catch {
                ToastManager.shared.error("Failed to swap exercise")
            }
        }
    }

    func updateSchedule(_ newSchedule: [String: String]) {
        guard let plan = activePlan else { return }

        Task {
            do {
                _ = try await APIService.shared.updateTrainingPlan(
                    planId: plan.id,
                    schedule: newSchedule
                )

                // Update local state
                activePlan = TrainingPlanSummary(
                    id: plan.id,
                    name: plan.name,
                    description: plan.description,
                    daysPerWeek: newSchedule.count,
                    schedule: newSchedule,
                    isActive: plan.isActive,
                    workouts: plan.workouts,
                    customizations: plan.customizations
                )

                ToastManager.shared.success("Schedule updated!")
                HapticsManager.shared.success()

                // Update calendar events
                await CalendarSyncService.shared.syncCalendar(schedule: newSchedule, planName: plan.name)
            } catch {
                ToastManager.shared.error("Failed to update schedule")
                print("Failed to update schedule: \(error)")
            }
        }
    }
}

#Preview {
    TrainingPlanView()
}
