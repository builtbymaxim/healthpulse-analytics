//
//  WeeklyMealPlanView.swift
//  HealthPulse
//
//  Phase 9A: Weekly meal planner — 7-day grid, macro balance, calendar sync
//

import SwiftUI
import Combine

// MARK: - ViewModel

@MainActor
class WeeklyMealPlanViewModel: ObservableObject {
    @Published var currentPlan: WeeklyMealPlan?
    @Published var macros: [DayMacroSummary] = []
    @Published var nutritionGoal: NutritionGoal?
    @Published var templates: [MealPlanTemplate] = []
    @Published var recipes: [Recipe] = []
    @Published var weekOffset = 0
    @Published var isLoading = false
    @Published var error: String?
    @Published var successMessage: String?

    var weekStartDate: Date {
        let cal = Calendar(identifier: .iso8601)
        let today = cal.startOfDay(for: Date())
        guard let monday = cal.dateInterval(of: .weekOfYear, for: today)?.start else { return today }
        return cal.date(byAdding: .weekOfYear, value: weekOffset, to: monday) ?? monday
    }

    var weekStartString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: weekStartDate)
    }

    var weekLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let start = fmt.string(from: weekStartDate)
        let end = fmt.string(from: Calendar.current.date(byAdding: .day, value: 6, to: weekStartDate) ?? weekStartDate)
        return "\(start) – \(end)"
    }

    static let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    static let mealTypes: [MealType] = [.breakfast, .lunch, .dinner, .snack]

    func itemFor(day: Int, mealType: MealType) -> WeeklyPlanItem? {
        currentPlan?.items.first { $0.dayOfWeek == day && $0.mealType == mealType.rawValue }
    }

    var todayISODay: Int {
        let weekday = Calendar(identifier: .iso8601).component(.weekday, from: Date())
        // ISO: Mon=1..Sun=7 — Calendar.iso8601 weekday is Mon=2..Sun=1
        return weekday == 1 ? 7 : weekday - 1
    }

    func loadPlan() async {
        isLoading = true
        error = nil
        do {
            currentPlan = try await APIService.shared.getWeeklyPlanForDate(weekStartString)
            if currentPlan != nil {
                await loadMacros()
            }
            if nutritionGoal == nil {
                nutritionGoal = try await APIService.shared.getNutritionGoal()
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadMacros() async {
        guard let planId = currentPlan?.id else { return }
        do {
            macros = try await APIService.shared.getDayMacros(planId: planId)
        } catch {
            print("Failed to load macros: \(error)")
        }
    }

    func createPlan() async {
        let name = "Week of \(weekLabel)"
        let req = CreateWeeklyPlanRequest(name: name, weekStartDate: weekStartString, isRecurring: false)
        do {
            currentPlan = try await APIService.shared.createWeeklyPlan(req)
            HapticsManager.shared.success()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addItem(day: Int, mealType: MealType, recipe: Recipe, servings: Double) async {
        guard let planId = currentPlan?.id else { return }
        let req = UpsertPlanItemRequest(
            dayOfWeek: day,
            mealType: mealType.rawValue,
            recipeId: recipe.id,
            servings: servings,
            sortOrder: 0
        )
        do {
            _ = try await APIService.shared.upsertPlanItem(planId: planId, req)
            currentPlan = try await APIService.shared.getWeeklyPlan(id: planId)
            await loadMacros()
            syncCalendar()
            HapticsManager.shared.light()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func removeItem(_ item: WeeklyPlanItem) async {
        guard let planId = currentPlan?.id else { return }
        do {
            try await APIService.shared.deletePlanItem(planId: planId, itemId: item.id)
            currentPlan = try await APIService.shared.getWeeklyPlan(id: planId)
            await loadMacros()
            syncCalendar()
            HapticsManager.shared.light()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func autoFill(templateId: UUID, mode: String) async {
        guard let planId = currentPlan?.id else { return }
        do {
            currentPlan = try await APIService.shared.autoFillPlan(planId: planId, request: AutoFillRequest(templateId: templateId, mode: mode))
            await loadMacros()
            syncCalendar()
            HapticsManager.shared.success()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func applyToFoodLog(mode: String) async {
        guard let planId = currentPlan?.id else { return }
        do {
            let result = try await APIService.shared.applyPlanToFoodLog(planId: planId, mode: mode)
            successMessage = "\(result.entriesCreated) meals added to food log"
            HapticsManager.shared.success()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func copyToNextWeek() async {
        guard let planId = currentPlan?.id else { return }
        do {
            _ = try await APIService.shared.copyPlanToNextWeek(planId: planId)
            successMessage = "Plan copied to next week"
            HapticsManager.shared.success()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadTemplates() async {
        do {
            templates = try await APIService.shared.getMealPlanTemplates()
        } catch {
            print("Failed to load templates: \(error)")
        }
    }

    func loadRecipes(search: String = "") async {
        do {
            recipes = try await APIService.shared.getRecipes(search: search.isEmpty ? nil : search)
        } catch {
            print("Failed to load recipes: \(error)")
        }
    }

    private func syncCalendar() {
        guard let plan = currentPlan else { return }
        CalendarSyncService.shared.syncMealPlan(plan)
    }
}

// MARK: - Main View

struct WeeklyMealPlanView: View {
    @StateObject private var vm = WeeklyMealPlanViewModel()
    @State private var selectedTab = 0 // 0=Plan, 1=Macros
    @State private var showingRecipePicker = false
    @State private var showingTemplateFill = false
    @State private var showingShoppingList = false
    @State private var showingApplyConfirm = false
    @State private var pickerDay = 1
    @State private var pickerMealType: MealType = .breakfast

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Week navigator
                weekNavigator

                // Tab picker
                Picker("View", selection: $selectedTab) {
                    Text("Plan").tag(0)
                    Text("Macros").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                if vm.isLoading && vm.currentPlan == nil {
                    Spacer()
                    ProgressView("Loading plan...")
                    Spacer()
                } else if vm.currentPlan == nil {
                    emptyState
                } else {
                    ScrollView {
                        if selectedTab == 0 {
                            planGridView
                            actionButtons
                        } else {
                            macroBalanceView
                        }
                    }
                }
            }
            .navigationTitle("Weekly Planner")
            .navigationBarTitleDisplayMode(.inline)
            .task { await vm.loadPlan() }
            .onChange(of: vm.weekOffset) { _, _ in
                Task { await vm.loadPlan() }
            }
            .alert("Error", isPresented: .init(get: { vm.error != nil }, set: { if !$0 { vm.error = nil } })) {
                Button("OK") { vm.error = nil }
            } message: {
                Text(vm.error ?? "")
            }
            .alert("Success", isPresented: .init(get: { vm.successMessage != nil }, set: { if !$0 { vm.successMessage = nil } })) {
                Button("OK") { vm.successMessage = nil }
            } message: {
                Text(vm.successMessage ?? "")
            }
            .sheet(isPresented: $showingRecipePicker) {
                RecipePickerSheet(day: pickerDay, mealType: pickerMealType, vm: vm)
            }
            .sheet(isPresented: $showingTemplateFill) {
                TemplateFillSheet(vm: vm)
            }
            .sheet(isPresented: $showingShoppingList) {
                WeeklyShoppingListSheet(planId: vm.currentPlan?.id ?? UUID())
            }
        }
    }

    // MARK: - Week Navigator

    private var weekNavigator: some View {
        HStack {
            Button {
                vm.weekOffset -= 1
                HapticsManager.shared.light()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
            }

            Spacer()

            VStack(spacing: 2) {
                Text(vm.weekLabel)
                    .font(.headline)
                if vm.weekOffset == 0 {
                    Text("This Week")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            Button {
                vm.weekOffset += 1
                HapticsManager.shared.light()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.bold())
            }
        }
        .padding()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.green.opacity(0.6))

            Text("No plan for this week")
                .font(.title3.bold())

            Text("Create a meal plan to organize your weekly meals")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                Task { await vm.createPlan() }
            } label: {
                Label("Create Plan", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: 240)
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            Spacer()
        }
    }

    // MARK: - Plan Grid

    private var planGridView: some View {
        VStack(spacing: 2) {
            // Header row: meal type icons
            HStack(spacing: 2) {
                Text("")
                    .frame(width: 40)
                ForEach(WeeklyMealPlanViewModel.mealTypes, id: \.self) { meal in
                    VStack(spacing: 2) {
                        Image(systemName: meal.icon)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(meal.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)

            // Day rows
            ForEach(1...7, id: \.self) { day in
                HStack(spacing: 2) {
                    // Day label
                    VStack(spacing: 0) {
                        Text(WeeklyMealPlanViewModel.dayNames[day - 1])
                            .font(.caption.bold())
                        if day == vm.todayISODay && vm.weekOffset == 0 {
                            Circle()
                                .fill(.green)
                                .frame(width: 5, height: 5)
                        }
                    }
                    .frame(width: 40)

                    // Meal slots
                    ForEach(WeeklyMealPlanViewModel.mealTypes, id: \.self) { meal in
                        MealSlotCell(
                            item: vm.itemFor(day: day, mealType: meal),
                            onTap: {
                                pickerDay = day
                                pickerMealType = meal
                                showingRecipePicker = true
                            },
                            onRemove: { item in
                                Task { await vm.removeItem(item) }
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ActionButton(title: "Auto-Fill", icon: "wand.and.stars", color: .purple) {
                    showingTemplateFill = true
                }
                ActionButton(title: "Shopping List", icon: "cart.fill", color: .orange) {
                    showingShoppingList = true
                }
            }

            HStack(spacing: 10) {
                ActionButton(title: "Apply to Log", icon: "tray.and.arrow.down.fill", color: .green) {
                    showingApplyConfirm = true
                }
                ActionButton(title: "Copy Next Week", icon: "doc.on.doc.fill", color: .blue) {
                    Task { await vm.copyToNextWeek() }
                }
            }
        }
        .padding()
        .confirmationDialog("Apply meals to food log", isPresented: $showingApplyConfirm) {
            Button("Today's meals only") {
                Task { await vm.applyToFoodLog(mode: "today") }
            }
            Button("Entire week") {
                Task { await vm.applyToFoodLog(mode: "week") }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Macro Balance View

    private var macroBalanceView: some View {
        VStack(spacing: 12) {
            if vm.macros.isEmpty {
                Text("Add meals to see macro breakdown")
                    .foregroundStyle(.secondary)
                    .padding(.top, 40)
            } else {
                ForEach(vm.macros) { daySummary in
                    DayMacroCard(
                        dayName: WeeklyMealPlanViewModel.dayNames[daySummary.dayOfWeek - 1],
                        summary: daySummary,
                        goal: vm.nutritionGoal
                    )
                }
            }
        }
        .padding()
    }
}

// MARK: - Meal Slot Cell

struct MealSlotCell: View {
    let item: WeeklyPlanItem?
    let onTap: () -> Void
    let onRemove: (WeeklyPlanItem) -> Void

    @State private var showingOptions = false

    var body: some View {
        Group {
            if let item = item {
                filledSlot(item)
            } else {
                emptySlot
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
    }

    private func filledSlot(_ item: WeeklyPlanItem) -> some View {
        Button {
            showingOptions = true
        } label: {
            VStack(spacing: 2) {
                Text(item.recipe?.name ?? "Recipe")
                    .font(.system(size: 9, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text("\(Int(item.totalCalories))cal")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
            .padding(4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background((item.mealTypeEnum?.slotColor ?? .gray).opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .confirmationDialog("Meal Options", isPresented: $showingOptions) {
            Button("Remove", role: .destructive) {
                onRemove(item)
            }
            Button("Swap Recipe") {
                onRemove(item)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onTap() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var emptySlot: some View {
        Button(action: onTap) {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundStyle(.gray.opacity(0.4))
                .overlay {
                    Image(systemName: "plus")
                        .font(.caption2)
                        .foregroundStyle(.gray.opacity(0.5))
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .font(.subheadline.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Day Macro Card

struct DayMacroCard: View {
    let dayName: String
    let summary: DayMacroSummary
    let goal: NutritionGoal?

    var calTarget: Double { goal?.effectiveCalorieTarget ?? 2000 }
    var proteinTarget: Double { goal?.effectiveProteinTarget ?? 150 }
    var carbsTarget: Double { goal?.effectiveCarbsTarget ?? 250 }
    var fatTarget: Double { goal?.effectiveFatTarget ?? 65 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dayName)
                    .font(.headline)
                Spacer()
                Text("\(Int(summary.totalCalories)) / \(Int(calTarget)) cal")
                    .font(.subheadline)
                    .foregroundStyle(macroColor(current: summary.totalCalories, target: calTarget))
            }

            HStack(spacing: 16) {
                MacroIndicator(label: "P", current: summary.totalProteinG, target: proteinTarget)
                MacroIndicator(label: "C", current: summary.totalCarbsG, target: carbsTarget)
                MacroIndicator(label: "F", current: summary.totalFatG, target: fatTarget)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    func macroColor(current: Double, target: Double) -> Color {
        guard target > 0 else { return .gray }
        let ratio = current / target
        if ratio > 1.15 { return .red }
        if ratio < 0.85 { return .orange }
        return .green
    }
}

struct MacroIndicator: View {
    let label: String
    let current: Double
    let target: Double

    var color: Color {
        guard target > 0 else { return .gray }
        let ratio = current / target
        if ratio > 1.15 { return .red }
        if ratio < 0.85 { return .orange }
        return .green
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            Text("\(Int(current))g")
                .font(.caption.bold())
                .foregroundStyle(color)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * min(current / max(target, 1), 1.0))
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Recipe Picker Sheet

struct RecipePickerSheet: View {
    let day: Int
    let mealType: MealType
    @ObservedObject var vm: WeeklyMealPlanViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var search = ""
    @State private var servings: Double = 1.0

    var filtered: [Recipe] {
        if search.isEmpty { return vm.recipes }
        return vm.recipes.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { recipe in
                Button {
                    Task {
                        await vm.addItem(day: day, mealType: mealType, recipe: recipe, servings: servings)
                        dismiss()
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recipe.name)
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            Text("\(Int(recipe.caloriesPerServing)) cal · \(Int(recipe.proteinGPerServing))g P · \(Int(recipe.carbsGPerServing))g C · \(Int(recipe.fatGPerServing))g F")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .searchable(text: $search, prompt: "Search recipes")
            .navigationTitle("\(WeeklyMealPlanViewModel.dayNames[day - 1]) · \(mealType.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Text("Servings:")
                            .font(.subheadline)
                        Stepper("\(String(format: "%.1f", servings))", value: $servings, in: 0.5...5, step: 0.5)
                            .font(.subheadline)
                    }
                }
            }
            .task { await vm.loadRecipes() }
            .onChange(of: search) { _, newValue in
                Task { await vm.loadRecipes(search: newValue) }
            }
        }
    }
}

// MARK: - Template Fill Sheet

struct TemplateFillSheet: View {
    @ObservedObject var vm: WeeklyMealPlanViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMode = "repeat"

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Fill Mode", selection: $selectedMode) {
                    Text("Repeat daily").tag("repeat")
                    Text("Rotate meals").tag("rotate")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Text(selectedMode == "repeat" ? "Same meals every day" : "Cycle template meals across 7 days")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                List(vm.templates) { template in
                    Button {
                        Task {
                            await vm.autoFill(templateId: template.id, mode: selectedMode)
                            dismiss()
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                HStack(spacing: 8) {
                                    Label(template.goalDisplayName, systemImage: template.goalIcon)
                                        .font(.caption)
                                        .foregroundStyle(template.goalColor)
                                    Text("· \(Int(template.totalCalories)) cal")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "wand.and.stars")
                                .foregroundStyle(.purple)
                        }
                    }
                }
            }
            .navigationTitle("Auto-Fill from Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await vm.loadTemplates() }
        }
    }
}

// MARK: - Shopping List Sheet

struct WeeklyShoppingListSheet: View {
    let planId: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var items: [ShoppingListItem] = []
    @State private var isLoading = true

    var shareText: String {
        items.map { "- \($0.displayAmount) \($0.name)" }.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading...")
                } else if items.isEmpty {
                    Text("No items — add meals to your plan first")
                        .foregroundStyle(.secondary)
                } else {
                    List(items) { item in
                        HStack {
                            Text(item.name)
                            Spacer()
                            Text(item.displayAmount)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if !items.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: shareText, subject: Text("Weekly Shopping List"))
                    }
                }
            }
            .task {
                do {
                    items = try await APIService.shared.getWeeklyShoppingList(planId: planId)
                } catch {
                    print("Failed to load shopping list: \(error)")
                }
                isLoading = false
            }
        }
    }
}

// MARK: - MealType Slot Color Extension

extension MealType {
    var slotColor: Color {
        switch self {
        case .breakfast: return .orange
        case .lunch: return .yellow
        case .dinner: return .indigo
        case .snack: return .green
        }
    }
}

#Preview {
    WeeklyMealPlanView()
}
