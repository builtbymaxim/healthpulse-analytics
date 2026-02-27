//
//  DeficitFixView.swift
//  HealthPulse
//
//  Fix My Deficit — recipe suggestions filtered by calorie/protein gap
//

import SwiftUI

struct DeficitFixView: View {
    let deficit: DeficitStatus
    @Environment(\.dismiss) private var dismiss
    @State private var recipes: [Recipe] = []
    @State private var isLoading = true
    @State private var selectedRecipe: Recipe?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with deficit summary
                deficitHeader

                Divider()

                // Recipe list
                if isLoading {
                    Spacer()
                    ProgressView("Finding recipes...")
                    Spacer()
                } else if let error {
                    Spacer()
                    ContentUnavailableView(
                        "No Recipes Found",
                        systemImage: "fork.knife",
                        description: Text(error)
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(recipes) { recipe in
                                DeficitRecipeCard(
                                    recipe: recipe,
                                    deficitKcal: max(deficit.caloriesRemaining, 0),
                                    deficitProteinG: max(deficit.proteinRemainingG, 0)
                                )
                                .onTapGesture { selectedRecipe = recipe }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Close Your Gap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedRecipe) { recipe in
                RecipeDetailSheet(recipe: recipe) {
                    dismiss()
                }
            }
            .task { await loadRecipes() }
        }
    }

    private var deficitHeader: some View {
        HStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("\(Int(max(deficit.caloriesRemaining, 0)))")
                    .font(.title2.weight(.bold))
                Text("kcal left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                Text("\(Int(max(deficit.proteinRemainingG, 0)))g")
                    .font(.title2.weight(.bold))
                Text("protein left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                let carbsRemaining = deficit.caloriesRemaining * 0.4 / 4 // approximate
                Text("\(Int(max(carbsRemaining, 0)))g")
                    .font(.title2.weight(.bold))
                Text("carbs left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppTheme.surface2)
    }

    private func loadRecipes() async {
        do {
            let kcal = max(deficit.caloriesRemaining, 100)
            let protein = max(deficit.proteinRemainingG, 0)
            recipes = try await APIService.shared.getDeficitFixRecipes(
                deficitKcal: kcal,
                deficitProteinG: protein
            )
            if recipes.isEmpty {
                error = "No matching recipes found for your dietary preferences."
            }
        } catch {
            self.error = "Could not load recipes. Please try again."
        }
        isLoading = false
    }
}

// MARK: - Deficit Recipe Card

private struct DeficitRecipeCard: View {
    let recipe: Recipe
    let deficitKcal: Double
    let deficitProteinG: Double

    private var caloriesCoverage: Double {
        guard deficitKcal > 0 else { return 1.0 }
        return min(recipe.caloriesPerServing / deficitKcal, 1.0)
    }

    private var proteinCoverage: Double {
        guard deficitProteinG > 0 else { return 1.0 }
        return min(recipe.proteinGPerServing / deficitProteinG, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)

                    if let time = recipe.totalTimeMin {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                            Text("\(time) min")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(recipe.caloriesPerServing)) kcal")
                        .font(.subheadline.weight(.medium))
                    Text("\(Int(recipe.proteinGPerServing))g protein")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

            // Coverage bars
            HStack(spacing: 12) {
                CoverageBar(label: "Calories", value: caloriesCoverage, color: .orange)
                CoverageBar(label: "Protein", value: proteinCoverage, color: .blue)
            }
        }
        .padding()
        .background(AppTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .cardShadow()
    }
}

private struct CoverageBar: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(color)
            }
            ProgressView(value: value)
                .tint(color)
        }
    }
}
