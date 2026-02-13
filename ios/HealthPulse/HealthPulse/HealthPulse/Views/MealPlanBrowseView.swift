//
//  MealPlanBrowseView.swift
//  HealthPulse
//
//  Meal plan template browsing, detail view, shopping list
//

import SwiftUI
import Combine

// MARK: - View Model

@MainActor
class MealPlanBrowseViewModel: ObservableObject {
    @Published var templates: [MealPlanTemplate] = []
    @Published var isLoading = false
    @Published var selectedGoalType: String?

    let goalTypes = [
        ("All", nil as String?),
        ("Weight Loss", "lose_weight"),
        ("Muscle", "build_muscle"),
        ("Maintain", "maintain"),
        ("Health", "general_health"),
    ]

    func loadTemplates() async {
        isLoading = true
        do {
            templates = try await APIService.shared.getMealPlanTemplates(goalType: selectedGoalType)
        } catch {
            templates = []
        }
        isLoading = false
    }
}

// MARK: - Meal Plan Browse View

struct MealPlanBrowseView: View {
    @StateObject private var viewModel = MealPlanBrowseViewModel()
    @Environment(\.dismiss) private var dismiss
    var onMealsAdded: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Goal type filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.goalTypes, id: \.0) { label, goalType in
                                Button {
                                    viewModel.selectedGoalType = goalType
                                    HapticsManager.shared.selection()
                                    Task { await viewModel.loadTemplates() }
                                } label: {
                                    Text(label)
                                        .font(.subheadline.bold())
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(viewModel.selectedGoalType == goalType ? Color.green : Color(.secondarySystemBackground))
                                        .foregroundStyle(viewModel.selectedGoalType == goalType ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Templates list
                    if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 40)
                    } else if viewModel.templates.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("No meal plans found")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.templates) { template in
                                MealPlanCard(template: template, onMealsAdded: onMealsAdded)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
            }
            .navigationTitle("Meal Plans")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await viewModel.loadTemplates() }
        }
    }
}

// MARK: - Meal Plan Card

private struct MealPlanCard: View {
    let template: MealPlanTemplate
    var onMealsAdded: (() -> Void)?
    @State private var showingDetail = false

    var body: some View {
        Button {
            showingDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    // Goal badge
                    HStack(spacing: 4) {
                        Image(systemName: template.goalIcon)
                        Text(template.goalDisplayName)
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(template.goalColor.opacity(0.15))
                    .foregroundStyle(template.goalColor)
                    .clipShape(Capsule())

                    Spacer()

                    if let count = template.itemCount {
                        Text("\(count) meals")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(template.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let desc = template.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Macro summary
                HStack(spacing: 0) {
                    macroLabel(value: template.totalCalories, label: "Cal", color: .orange)
                    macroLabel(value: template.totalProteinG, label: "Protein", color: .blue)
                    macroLabel(value: template.totalCarbsG, label: "Carbs", color: .yellow)
                    macroLabel(value: template.totalFatG, label: "Fat", color: .purple)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8)
        }
        .sheet(isPresented: $showingDetail) {
            MealPlanDetailSheet(templateId: template.id, onMealsAdded: onMealsAdded)
        }
    }

    private func macroLabel(value: Double, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(value))")
                .font(.subheadline.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Meal Plan Detail Sheet

private struct MealPlanDetailSheet: View {
    let templateId: UUID
    var onMealsAdded: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var template: MealPlanTemplate?
    @State private var isLoading = true
    @State private var isAddingAll = false
    @State private var showSuccess = false
    @State private var showingShoppingList = false
    @State private var showingWeeklyPlanner = false
    @State private var loadError: String?

    private let mealOrder = ["breakfast", "lunch", "dinner", "snack"]

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if let errorMsg = loadError {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(.orange)
                        Text(errorMsg)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            loadError = nil
                            isLoading = true
                            Task { await loadTemplate() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                    .padding()
                } else if let template {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Header macros
                            headerMacros(template)

                            // Grouped items
                            if let items = template.items {
                                let grouped = Dictionary(grouping: items) { $0.mealType }
                                ForEach(mealOrder, id: \.self) { mealType in
                                    if let mealItems = grouped[mealType], !mealItems.isEmpty {
                                        mealSection(mealType: mealType, items: mealItems)
                                    }
                                }
                            }

                            // Action buttons
                            VStack(spacing: 12) {
                                // Log entire day
                                Button {
                                    addAllMeals()
                                } label: {
                                    HStack {
                                        if isAddingAll {
                                            ProgressView().tint(.white)
                                        } else if showSuccess {
                                            Image(systemName: "checkmark.circle.fill")
                                            Text("All meals logged!")
                                        } else {
                                            Image(systemName: "plus.circle.fill")
                                            Text("Log Entire Day")
                                        }
                                    }
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(showSuccess ? Color.green : Color.green)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                                .disabled(isAddingAll || showSuccess)

                                // Plan this week
                                Button {
                                    showingWeeklyPlanner = true
                                } label: {
                                    HStack {
                                        Image(systemName: "calendar")
                                        Text("Plan This Week")
                                    }
                                    .font(.headline)
                                    .foregroundStyle(.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                }

                                // Shopping list
                                Button {
                                    showingShoppingList = true
                                } label: {
                                    HStack {
                                        Image(systemName: "cart.fill")
                                        Text("Shopping List")
                                    }
                                    .font(.headline)
                                    .foregroundStyle(.green)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                } else {
                    Text("Meal plan not found")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(template?.name ?? "Meal Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await loadTemplate() }
            .sheet(isPresented: $showingShoppingList) {
                ShoppingListSheet(templateId: templateId)
            }
            .sheet(isPresented: $showingWeeklyPlanner) {
                WeeklyMealPlanView()
            }
        }
    }

    private func headerMacros(_ template: MealPlanTemplate) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: template.goalIcon)
                Text(template.goalDisplayName)
            }
            .font(.subheadline.bold())
            .foregroundStyle(template.goalColor)

            if let desc = template.description {
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 0) {
                macroItem(value: template.totalCalories, label: "Calories", color: .orange)
                macroItem(value: template.totalProteinG, label: "Protein", unit: "g", color: .blue)
                macroItem(value: template.totalCarbsG, label: "Carbs", unit: "g", color: .yellow)
                macroItem(value: template.totalFatG, label: "Fat", unit: "g", color: .purple)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func macroItem(value: Double, label: String, unit: String = "", color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(Int(value))\(unit)")
                .font(.title3.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func mealSection(mealType: String, items: [MealPlanItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let cat = RecipeCategory(rawValue: mealType) {
                    Image(systemName: cat.icon)
                        .foregroundStyle(cat.color)
                }
                Text(mealType.capitalized)
                    .font(.headline)
            }
            .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.recipe?.name ?? "Recipe")
                                .font(.subheadline)
                            if item.servings != 1 {
                                Text("\(formatAmount(item.servings)) servings")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(item.totalCalories ?? 0)) cal")
                                .font(.subheadline.bold())
                                .foregroundStyle(.orange)
                            Text("\(Int(item.totalProteinG ?? 0))g protein")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    if index < items.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    private func addAllMeals() {
        guard let items = template?.items else { return }
        isAddingAll = true
        Task {
            var allSuccess = true
            for item in items {
                guard let recipeId = item.recipe?.id ?? UUID(uuidString: item.recipeId.uuidString) else { continue }
                let request = QuickAddRecipeRequest(
                    recipeId: recipeId,
                    mealType: item.mealType,
                    servings: item.servings,
                    loggedAt: nil
                )
                do {
                    _ = try await APIService.shared.quickAddRecipe(request)
                } catch {
                    allSuccess = false
                }
            }
            if allSuccess {
                HapticsManager.shared.success()
                showSuccess = true
                onMealsAdded?()
                try? await Task.sleep(nanoseconds: 800_000_000)
                dismiss()
            } else {
                HapticsManager.shared.error()
                isAddingAll = false
            }
        }
    }

    private func loadTemplate() async {
        do {
            template = try await APIService.shared.getMealPlanTemplate(id: templateId)
        } catch {
            loadError = "Failed to load meal plan. Please try again."
        }
        isLoading = false
    }

    private func formatAmount(_ value: Double) -> String {
        if value == value.rounded() { return "\(Int(value))" }
        return String(format: "%.1f", value)
    }
}

// MARK: - Shopping List Sheet

struct ShoppingListSheet: View {
    let templateId: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var items: [ShoppingListItem] = []
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if let errorMsg = loadError {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(.orange)
                        Text(errorMsg)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Retry") {
                            loadError = nil
                            isLoading = true
                            Task { await loadShoppingList() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                    .padding()
                } else if items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "cart")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No ingredients found")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List {
                        ForEach(items) { item in
                            HStack {
                                Image(systemName: "circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(item.name.capitalized)
                                    .font(.subheadline)
                                Spacer()
                                Text(item.displayAmount)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if !items.isEmpty {
                        ShareLink(item: shoppingListText) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .task { await loadShoppingList() }
        }
    }

    private var shoppingListText: String {
        var text = "Shopping List\n"
        text += String(repeating: "—", count: 20) + "\n"
        for item in items {
            text += "□ \(item.name.capitalized) — \(item.displayAmount)\n"
        }
        return text
    }

    private func loadShoppingList() async {
        do {
            items = try await APIService.shared.getShoppingList(templateId: templateId)
        } catch {
            loadError = "Failed to load shopping list."
        }
        isLoading = false
    }
}
