//
//  RecipeLibraryView.swift
//  HealthPulse
//
//  Recipe browsing, filtering, detail view with quick-add
//

import SwiftUI
import Combine

// MARK: - View Model

@MainActor
class RecipeLibraryViewModel: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var isLoading = false
    @Published var searchText = ""
    @Published var selectedCategory: RecipeCategory?
    @Published var selectedGoalType: String?

    private var searchTask: Task<Void, Never>?

    func loadRecipes() async {
        isLoading = true
        do {
            recipes = try await APIService.shared.getRecipes(
                category: selectedCategory?.rawValue,
                goalType: selectedGoalType,
                search: searchText.isEmpty ? nil : searchText
            )
        } catch {
            recipes = []
        }
        isLoading = false
    }

    func debouncedSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await loadRecipes()
        }
    }
}

// MARK: - Recipe Library View

struct RecipeLibraryView: View {
    @StateObject private var viewModel = RecipeLibraryViewModel()
    @Environment(\.dismiss) private var dismiss
    var onRecipeAdded: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search recipes...", text: $viewModel.searchText)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                        if !viewModel.searchText.isEmpty {
                            Button {
                                viewModel.searchText = ""
                                Task { await viewModel.loadRecipes() }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Category filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            CategoryChip(title: "All", isSelected: viewModel.selectedCategory == nil) {
                                viewModel.selectedCategory = nil
                                Task { await viewModel.loadRecipes() }
                            }
                            ForEach(RecipeCategory.allCases, id: \.self) { category in
                                CategoryChip(
                                    title: category.displayName,
                                    icon: category.icon,
                                    isSelected: viewModel.selectedCategory == category
                                ) {
                                    viewModel.selectedCategory = category
                                    Task { await viewModel.loadRecipes() }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Recipe list
                    if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 40)
                    } else if viewModel.recipes.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("No recipes found")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.recipes) { recipe in
                                RecipeCard(recipe: recipe, onRecipeAdded: onRecipeAdded)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
            }
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await viewModel.loadRecipes() }
            .onChange(of: viewModel.searchText) { _, _ in
                viewModel.debouncedSearch()
            }
        }
    }
}

// MARK: - Category Chip

private struct CategoryChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            action()
            HapticsManager.shared.selection()
        }) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline.bold())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.green : Color(.secondarySystemBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Recipe Card

private struct RecipeCard: View {
    let recipe: Recipe
    var onRecipeAdded: (() -> Void)?
    @State private var showingDetail = false

    var body: some View {
        Button {
            showingDetail = true
        } label: {
            HStack(spacing: 14) {
                // Category icon
                Image(systemName: recipe.recipeCategory?.icon ?? "fork.knife")
                    .font(.title2)
                    .foregroundStyle(recipe.recipeCategory?.color ?? .green)
                    .frame(width: 48, height: 48)
                    .background((recipe.recipeCategory?.color ?? .green).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 12) {
                        Label("\(Int(recipe.caloriesPerServing)) cal", systemImage: "flame.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Label("\(Int(recipe.proteinGPerServing))g protein", systemImage: "p.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }

                    if let time = recipe.totalTimeMin {
                        Label("\(time) min", systemImage: "clock")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8)
        }
        .sheet(isPresented: $showingDetail) {
            RecipeDetailSheet(recipe: recipe, onRecipeAdded: onRecipeAdded)
        }
    }
}

// MARK: - Recipe Detail Sheet

struct RecipeDetailSheet: View {
    let recipe: Recipe
    var onRecipeAdded: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var fullRecipe: Recipe?
    @State private var selectedServings: Double = 1
    @State private var selectedMealType: String = "lunch"
    @State private var isAdding = false
    @State private var showSuccess = false

    private let servingOptions: [Double] = [0.5, 1, 1.5, 2]
    private let mealTypes = ["breakfast", "lunch", "dinner", "snack"]

    var displayRecipe: Recipe { fullRecipe ?? recipe }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Macro summary card
                    macroSummaryCard

                    // Ingredients
                    if let ingredients = displayRecipe.ingredients, !ingredients.isEmpty {
                        ingredientsSection(ingredients)
                    }

                    // Instructions
                    if let instructions = displayRecipe.instructions, !instructions.isEmpty {
                        instructionsSection(instructions)
                    }

                    // Serving selector
                    servingSelector

                    // Meal type selector
                    mealTypeSelector

                    // Add button
                    Button {
                        addToFoodLog()
                    } label: {
                        HStack {
                            if isAdding {
                                ProgressView()
                                    .tint(.white)
                            } else if showSuccess {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Added!")
                            } else {
                                Image(systemName: "plus.circle.fill")
                                Text("Add to Food Log")
                            }
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(showSuccess ? Color.green : Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(isAdding || showSuccess)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle(recipe.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await loadFullRecipe() }
        }
    }

    private var macroSummaryCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                macroItem(value: recipe.caloriesPerServing * selectedServings, label: "Calories", color: .orange)
                macroItem(value: recipe.proteinGPerServing * selectedServings, label: "Protein", unit: "g", color: .blue)
                macroItem(value: recipe.carbsGPerServing * selectedServings, label: "Carbs", unit: "g", color: .yellow)
                macroItem(value: recipe.fatGPerServing * selectedServings, label: "Fat", unit: "g", color: .purple)
            }

            if let desc = recipe.description {
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Tags
            if !recipe.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(recipe.tags, id: \.self) { tag in
                            Text(tag.replacingOccurrences(of: "_", with: " "))
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.15))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                    }
                }
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

    private func ingredientsSection(_ ingredients: [RecipeIngredient]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredients")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(Array(ingredients.enumerated()), id: \.offset) { index, ingredient in
                    HStack {
                        Text(ingredient.name)
                            .font(.subheadline)
                        Spacer()
                        Text("\(formatAmount(ingredient.amount * selectedServings)) \(ingredient.unit)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    if index < ingredients.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    private func instructionsSection(_ instructions: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Instructions")
                .font(.headline)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(instructions.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.green)
                            .clipShape(Circle())

                        Text(step)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    private var servingSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Servings")
                .font(.headline)
                .padding(.horizontal)

            HStack(spacing: 8) {
                ForEach(servingOptions, id: \.self) { serving in
                    Button {
                        selectedServings = serving
                        HapticsManager.shared.selection()
                    } label: {
                        Text("\(formatAmount(serving))x")
                            .font(.subheadline.bold())
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(selectedServings == serving ? Color.green : Color(.secondarySystemBackground))
                            .foregroundStyle(selectedServings == serving ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var mealTypeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Meal")
                .font(.headline)
                .padding(.horizontal)

            HStack(spacing: 8) {
                ForEach(mealTypes, id: \.self) { type in
                    Button {
                        selectedMealType = type
                        HapticsManager.shared.selection()
                    } label: {
                        Text(type.capitalized)
                            .font(.subheadline.bold())
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(selectedMealType == type ? Color.green : Color(.secondarySystemBackground))
                            .foregroundStyle(selectedMealType == type ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func addToFoodLog() {
        isAdding = true
        Task {
            do {
                let request = QuickAddRecipeRequest(
                    recipeId: recipe.id,
                    mealType: selectedMealType,
                    servings: selectedServings,
                    loggedAt: nil
                )
                _ = try await APIService.shared.quickAddRecipe(request)
                HapticsManager.shared.success()
                showSuccess = true
                onRecipeAdded?()
                try? await Task.sleep(nanoseconds: 800_000_000)
                dismiss()
            } catch {
                HapticsManager.shared.error()
                isAdding = false
            }
        }
    }

    private func loadFullRecipe() async {
        do {
            fullRecipe = try await APIService.shared.getRecipe(id: recipe.id)
        } catch {}
    }

    private func formatAmount(_ value: Double) -> String {
        if value == value.rounded() { return "\(Int(value))" }
        return String(format: "%.1f", value)
    }
}
