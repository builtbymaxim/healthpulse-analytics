//
//  FoodLogView.swift
//  HealthPulse
//
//  Simplified food logging: enter macros per 100g, then amount consumed
//

import SwiftUI

struct FoodLogView: View {
    @Environment(\.dismiss) private var dismiss

    let editingEntry: FoodEntry?
    let onSave: (FoodEntry) -> Void

    @State private var name = ""
    @State private var selectedMealType: MealType = .lunch
    @State private var showingBarcodeScanner = false
    @State private var showingRecipeLibrary = false

    // Per 100g values
    @State private var caloriesPer100g = ""
    @State private var proteinPer100g = ""
    @State private var carbsPer100g = ""
    @State private var fatPer100g = ""

    // Amount consumed
    @State private var amountGrams = "100"

    @State private var isSaving = false
    @State private var error: String?

    // Food search
    @State private var searchQuery = ""
    @State private var searchResults: [BarcodeProduct] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    var isEditing: Bool { editingEntry != nil }

    init(editingEntry: FoodEntry? = nil, onSave: @escaping (FoodEntry) -> Void) {
        self.editingEntry = editingEntry
        self.onSave = onSave
    }

    // Computed totals
    var amount: Double {
        Double(amountGrams) ?? 100
    }

    var multiplier: Double {
        amount / 100.0
    }

    var totalCalories: Double {
        (Double(caloriesPer100g) ?? 0) * multiplier
    }

    var totalProtein: Double {
        (Double(proteinPer100g) ?? 0) * multiplier
    }

    var totalCarbs: Double {
        (Double(carbsPer100g) ?? 0) * multiplier
    }

    var totalFat: Double {
        (Double(fatPer100g) ?? 0) * multiplier
    }

    var isValid: Bool {
        !name.isEmpty && !caloriesPer100g.isEmpty && Double(caloriesPer100g) != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Food Name & Meal Type
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What did you eat?")
                            .font(.headline)

                        TextField("Food name", text: $name)
                            .font(.title3)
                            .padding()
                            .background(AppTheme.surface2)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Meal type selector
                        HStack(spacing: 8) {
                            ForEach(MealType.allCases.prefix(4), id: \.self) { meal in
                                MealTypeChip(meal: meal, isSelected: selectedMealType == meal) {
                                    selectedMealType = meal
                                    HapticsManager.shared.selection()
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Food Search
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Search foods (e.g. chicken breast)", text: $searchQuery)
                                .textInputAutocapitalization(.never)
                                .onChange(of: searchQuery) { _, newValue in
                                    searchTask?.cancel()
                                    guard newValue.count >= 2 else {
                                        searchResults = []
                                        return
                                    }
                                    searchTask = Task {
                                        try? await Task.sleep(nanoseconds: 500_000_000)
                                        guard !Task.isCancelled else { return }
                                        await performSearch(newValue)
                                    }
                                }
                            if isSearching {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .padding()
                        .background(AppTheme.surface2)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        if !searchResults.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(searchResults.prefix(8), id: \.barcode) { product in
                                    Button {
                                        selectSearchResult(product)
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(product.name ?? "Unknown")
                                                    .font(.subheadline.bold())
                                                    .foregroundStyle(.primary)
                                                    .lineLimit(1)
                                                if let brand = product.brand, !brand.isEmpty {
                                                    Text(brand)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(1)
                                                }
                                            }
                                            Spacer()
                                            Text("\(Int(product.caloriesPer100g)) kcal")
                                                .font(.caption.bold())
                                                .foregroundStyle(.green)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                    }
                                    Divider()
                                }
                            }
                            .background(AppTheme.surface2)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)

                    // Nutritional Info per 100g
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Nutrition per 100g")
                            .font(.headline)

                        HStack(spacing: 12) {
                            NutrientInput(label: "Calories", value: $caloriesPer100g, unit: "kcal", color: .green)
                            NutrientInput(label: "Protein", value: $proteinPer100g, unit: "g", color: .blue)
                        }

                        HStack(spacing: 12) {
                            NutrientInput(label: "Carbs", value: $carbsPer100g, unit: "g", color: .orange)
                            NutrientInput(label: "Fat", value: $fatPer100g, unit: "g", color: .purple)
                        }
                    }
                    .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)

                    // Amount Consumed
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Amount consumed")
                            .font(.headline)

                        HStack(spacing: 16) {
                            // Quick amount buttons
                            ForEach([50, 100, 150, 200], id: \.self) { grams in
                                Button {
                                    amountGrams = String(grams)
                                    HapticsManager.shared.light()
                                } label: {
                                    Text("\(grams)g")
                                        .font(.subheadline.bold())
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(amountGrams == String(grams) ? Color.green : AppTheme.surface2)
                                        .foregroundStyle(amountGrams == String(grams) ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                            }

                            Spacer()

                            // Custom amount input
                            HStack {
                                TextField("100", text: $amountGrams)
                                    .keyboardType(.numberPad)
                                    .font(.title2.bold())
                                    .frame(width: 60)
                                    .multilineTextAlignment(.center)

                                Text("g")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background(AppTheme.surface2)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.horizontal)

                    // Calculated Total Preview
                    if isValid {
                        VStack(spacing: 12) {
                            Text("Total for \(Int(amount))g")
                                .font(.headline)

                            HStack(spacing: 24) {
                                TotalMacroDisplay(label: "Calories", value: totalCalories, unit: "", color: .green)
                                TotalMacroDisplay(label: "Protein", value: totalProtein, unit: "g", color: .blue)
                                TotalMacroDisplay(label: "Carbs", value: totalCarbs, unit: "g", color: .orange)
                                TotalMacroDisplay(label: "Fat", value: totalFat, unit: "g", color: .purple)
                            }
                        }
                        .padding()
                        .background(AppTheme.surface2)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    // Scan / Browse shortcuts
                    HStack(spacing: 12) {
                        Button {
                            showingBarcodeScanner = true
                        } label: {
                            HStack {
                                Image(systemName: "barcode.viewfinder")
                                Text("Scan Barcode")
                            }
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button {
                            showingRecipeLibrary = true
                        } label: {
                            HStack {
                                Image(systemName: "book.fill")
                                Text("Recipes")
                            }
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)

                    // Quick Add Suggestions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Add")
                            .font(.headline)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                QuickFoodChip(name: "Chicken", cal: 165, p: 31, c: 0, f: 3.6) {
                                    fillQuickAdd(name: "Chicken Breast", cal: 165, p: 31, c: 0, f: 3.6)
                                }
                                QuickFoodChip(name: "Rice", cal: 130, p: 2.7, c: 28, f: 0.3) {
                                    fillQuickAdd(name: "White Rice", cal: 130, p: 2.7, c: 28, f: 0.3)
                                }
                                QuickFoodChip(name: "Eggs", cal: 155, p: 13, c: 1.1, f: 11) {
                                    fillQuickAdd(name: "Eggs", cal: 155, p: 13, c: 1.1, f: 11)
                                }
                                QuickFoodChip(name: "Oats", cal: 389, p: 17, c: 66, f: 7) {
                                    fillQuickAdd(name: "Oats", cal: 389, p: 17, c: 66, f: 7)
                                }
                                QuickFoodChip(name: "Banana", cal: 89, p: 1.1, c: 23, f: 0.3) {
                                    fillQuickAdd(name: "Banana", cal: 89, p: 1.1, c: 23, f: 0.3)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Error message
                    if let error = error {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }

                    // Save Button
                    Button {
                        Task { await saveEntry() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(isEditing ? "Update Entry" : "Log Food")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValid ? Color.green : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(!isValid || isSaving)
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
                .padding(.top)
            }
            .navigationTitle(isEditing ? "Edit Entry" : "Log Food")
            .onAppear { prefillIfEditing() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingBarcodeScanner) {
                BarcodeScannerView(onFoodAdded: {
                    dismiss()
                })
            }
            .sheet(isPresented: $showingRecipeLibrary) {
                RecipeLibraryView(onRecipeAdded: {
                    dismiss()
                })
            }
        }
    }

    private func performSearch(_ query: String) async {
        await MainActor.run { isSearching = true }
        do {
            let results = try await APIService.shared.searchFood(query: query)
            await MainActor.run {
                searchResults = results
                isSearching = false
            }
        } catch {
            await MainActor.run {
                searchResults = []
                isSearching = false
            }
        }
    }

    private func selectSearchResult(_ product: BarcodeProduct) {
        name = product.name ?? "Unknown"
        caloriesPer100g = String(Int(product.caloriesPer100g))
        proteinPer100g = String(format: "%.1f", product.proteinGPer100g)
        carbsPer100g = String(format: "%.1f", product.carbsGPer100g)
        fatPer100g = String(format: "%.1f", product.fatGPer100g)
        amountGrams = "100"
        searchResults = []
        searchQuery = ""
        HapticsManager.shared.light()
    }

    private func fillQuickAdd(name: String, cal: Double, p: Double, c: Double, f: Double) {
        self.name = name
        self.caloriesPer100g = String(Int(cal))
        self.proteinPer100g = String(format: "%.1f", p)
        self.carbsPer100g = String(format: "%.1f", c)
        self.fatPer100g = String(format: "%.1f", f)
        self.amountGrams = "100"
        HapticsManager.shared.light()
    }

    private func prefillIfEditing() {
        guard let entry = editingEntry else { return }
        name = entry.name
        if let mealStr = entry.mealType, let meal = MealType(rawValue: mealStr) {
            selectedMealType = meal
        }
        // Pre-fill with total values (assume 100g serving for editing)
        caloriesPer100g = String(Int(entry.calories))
        proteinPer100g = String(format: "%.1f", entry.proteinG)
        carbsPer100g = String(format: "%.1f", entry.carbsG)
        fatPer100g = String(format: "%.1f", entry.fatG)
        amountGrams = "100"
    }

    private func saveEntry() async {
        guard isValid else { return }

        isSaving = true
        error = nil
        HapticsManager.shared.medium()

        do {
            if let existing = editingEntry {
                // Update existing entry
                let update = FoodEntryUpdate(
                    name: name,
                    mealType: selectedMealType.rawValue,
                    calories: totalCalories,
                    proteinG: totalProtein,
                    carbsG: totalCarbs,
                    fatG: totalFat
                )
                let savedEntry = try await APIService.shared.updateFood(entryId: existing.id, update: update)
                HapticsManager.shared.success()
                onSave(savedEntry)
            } else {
                // Create new entry
                let entry = FoodEntryCreate(
                    name: name,
                    mealType: selectedMealType,
                    calories: totalCalories,
                    proteinG: totalProtein,
                    carbsG: totalCarbs,
                    fatG: totalFat,
                    notes: nil
                )
                let savedEntry = try await APIService.shared.logFood(entry)
                HapticsManager.shared.success()
                onSave(savedEntry)
            }
            dismiss()
        } catch {
            self.error = error.localizedDescription
            HapticsManager.shared.error()
        }

        isSaving = false
    }
}

// MARK: - Helper Views

struct MealTypeChip: View {
    let meal: MealType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: meal.icon)
                    .font(.title3)
                Text(meal.displayName)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.green.opacity(0.2) : AppTheme.surface2)
            .foregroundStyle(isSelected ? .green : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct NutrientInput: View {
    let label: String
    @Binding var value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                TextField("0", text: $value)
                    .keyboardType(.decimalPad)
                    .font(.title3.bold())

                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct TotalMacroDisplay: View {
    let label: String
    let value: Double
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(String(format: "%.0f%@", value, unit))
                .font(.headline)
                .foregroundStyle(color)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct QuickFoodChip: View {
    let name: String
    let cal: Double
    let p: Double
    let c: Double
    let f: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.subheadline.bold())

                Text("\(Int(cal)) kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppTheme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FoodLogView { _ in }
}
