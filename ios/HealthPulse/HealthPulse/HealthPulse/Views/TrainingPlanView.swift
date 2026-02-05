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
                                onEdit: { viewModel.showEditSchedule = true }
                            )
                        } else {
                            NoPlanCard(onSelectPlan: { viewModel.showTemplates = true })
                        }

                        // Weekly Schedule
                        if let activePlan = viewModel.activePlan {
                            WeeklyScheduleCard(schedule: activePlan.schedule)
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
                        .background(Color.green.opacity(0.1))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }

                Menu {
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
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

// MARK: - No Plan Card

struct NoPlanCard: View {
    let onSelectPlan: () -> Void

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
                Label("Browse Plans", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

// MARK: - Weekly Schedule Card

struct WeeklyScheduleCard: View {
    let schedule: [String: String]

    private let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Schedule")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(1...7, id: \.self) { day in
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
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
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
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

// MARK: - Template Selection View

struct TemplateSelectionView: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTemplate: PlanTemplate?

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
                        if let template = selectedTemplate {
                            viewModel.activatePlan(template: template)
                            HapticsManager.shared.success()
                            dismiss()
                        }
                    }
                    .disabled(selectedTemplate == nil)
                }
            }
            .task {
                await viewModel.loadTemplates()
            }
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

                HStack(spacing: 16) {
                    Label("\(template.daysPerWeek) days", systemImage: "calendar")
                    Label(template.modality.capitalized, systemImage: modalityIcon(template.modality))
                    Label(template.difficulty.capitalized, systemImage: "chart.bar.fill")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

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
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
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

    private let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

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

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(1...7, id: \.self) { day in
                        HStack {
                            Text(dayNames[day - 1])
                                .frame(width: 100, alignment: .leading)

                            Spacer()

                            Menu {
                                Button("Rest Day") {
                                    editedSchedule[String(day)] = nil
                                }
                                Divider()
                                ForEach(availableWorkouts, id: \.self) { workout in
                                    Button(workout) {
                                        editedSchedule[String(day)] = workout
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
                    Text("Tap a day to change the workout or set it as a rest day.")
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
        }
    }

    private func saveSchedule() {
        isSaving = true
        // Convert to non-optional dict (excluding rest days)
        var finalSchedule: [String: String] = [:]
        for (day, workout) in editedSchedule {
            if let workout = workout {
                finalSchedule[day] = workout
            }
        }
        onSave(finalSchedule)
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
            } catch {
                ToastManager.shared.error("Failed to activate plan")
                print("Failed to activate plan: \(error)")
            }
        }
    }

    func deactivatePlan() {
        Task {
            do {
                _ = try await APIService.shared.deactivateTrainingPlan()
                activePlan = nil
                ToastManager.shared.success("Plan deactivated")
            } catch {
                ToastManager.shared.error("Failed to deactivate plan")
                print("Failed to deactivate plan: \(error)")
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
                    isActive: plan.isActive
                )

                ToastManager.shared.success("Schedule updated!")
                HapticsManager.shared.success()
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
