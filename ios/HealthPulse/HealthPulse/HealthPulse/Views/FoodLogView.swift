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
    @State private var showAmountPicker = false

    @State private var isSaving = false
    @State private var error: String?
    @State private var showSaveError = false

    // Food search (unified with name field)
    @State private var searchResults: [BarcodeProduct] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var suppressSearch = false
    @State private var searchRanEmpty = false

    // Recently logged foods
    @State private var recentFoods: [RecentFood] = []

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
                    // Food Name & Search (unified)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What did you eat?")
                            .font(.headline)

                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Search or enter food name", text: $name)
                                .textInputAutocapitalization(.words)
                                .onChange(of: name) { _, newValue in
                                    searchTask?.cancel()
                                    searchRanEmpty = false
                                    guard !suppressSearch else {
                                        suppressSearch = false
                                        return
                                    }
                                    guard newValue.count >= 3 else {
                                        searchResults = []
                                        return
                                    }
                                    searchTask = Task {
                                        try? await Task.sleep(nanoseconds: 1_000_000_000)
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
                        } else if searchRanEmpty {
                            Text("No results for \"\(name)\" — enter macros manually")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 4)
                        }

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

                        HStack(spacing: 10) {
                            ForEach([50, 100, 150, 200], id: \.self) { grams in
                                Button {
                                    amountGrams = String(grams)
                                    HapticsManager.shared.light()
                                } label: {
                                    Text("\(grams)g")
                                        .font(.subheadline.bold())
                                        .fixedSize()
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(amountGrams == String(grams) ? Color.green : AppTheme.surface2)
                                        .foregroundStyle(amountGrams == String(grams) ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                            }

                            Spacer()

                            // Custom amount pill — tap for wheel picker
                            Button {
                                showAmountPicker = true
                                HapticsManager.shared.selection()
                            } label: {
                                Text("\(Int(amount)) g")
                                    .font(.title2.bold())
                                    .monospacedDigit()
                                    .fixedSize()
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(AppTheme.surface2)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.green.opacity(0.4), lineWidth: 1.5)
                                    )
                            }
                            .foregroundStyle(.primary)
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

                    // Recently Logged Foods
                    if !recentFoods.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recently Logged")
                                .font(.headline)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(recentFoods) { food in
                                        QuickFoodChip(
                                            name: food.name,
                                            cal: food.caloriesPer100g,
                                            p: food.proteinGPer100g,
                                            c: food.carbsGPer100g,
                                            f: food.fatGPer100g
                                        ) {
                                            fillQuickAdd(
                                                name: food.name,
                                                cal: food.caloriesPer100g,
                                                p: food.proteinGPer100g,
                                                c: food.carbsGPer100g,
                                                f: food.fatGPer100g
                                            )
                                        }
                                    }
                                }
                            }
                        }
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
            .task {
                guard !isEditing else { return }
                if let foods = try? await APIService.shared.getRecentFoods() {
                    recentFoods = foods
                }
            }
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
            .alert("Could not save", isPresented: $showSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(error ?? "An unknown error occurred. Please try again.")
            }
            .sheet(isPresented: $showAmountPicker) {
                AmountPickerSheet(amountGrams: $amountGrams)
            }
        }
    }

    private func performSearch(_ query: String) async {
        await MainActor.run { isSearching = true }
        do {
            let results = try await APIService.shared.searchFood(query: query)
            await MainActor.run {
                searchResults = results
                searchRanEmpty = results.isEmpty
                isSearching = false
            }
        } catch {
            await MainActor.run {
                searchResults = []
                searchRanEmpty = true
                isSearching = false
                ToastManager.shared.error("Search failed. Check your connection.")
            }
        }
    }

    private func selectSearchResult(_ product: BarcodeProduct) {
        suppressSearch = true
        name = product.name ?? "Unknown"
        caloriesPer100g = String(Int(product.caloriesPer100g))
        proteinPer100g = String(format: "%.1f", product.proteinGPer100g)
        carbsPer100g = String(format: "%.1f", product.carbsGPer100g)
        fatPer100g = String(format: "%.1f", product.fatGPer100g)
        amountGrams = "100"
        searchResults = []
        HapticsManager.shared.light()
    }

    private func fillQuickAdd(name: String, cal: Double, p: Double, c: Double, f: Double) {
        suppressSearch = true
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
        suppressSearch = true
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
            self.showSaveError = true
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
    @State private var showPicker = false

    private var displayValue: String {
        if let v = Double(value), v > 0 {
            return v.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(v))" : String(format: "%.1f", v)
        }
        return "0"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                showPicker = true
                HapticsManager.shared.selection()
            } label: {
                HStack {
                    Text(displayValue)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .sheet(isPresented: $showPicker) {
                NutrientPickerSheet(label: label, value: $value, unit: unit, color: color)
            }
        }
    }
}

struct NutrientPickerSheet: View {
    let label: String
    @Binding var value: String
    let unit: String
    let color: Color
    @Environment(\.dismiss) private var dismiss

    @State private var wholeValue: Int = 0
    @State private var decimalValue: Int = 0

    private var isCalories: Bool { unit == "kcal" }
    private var maxWhole: Int { isCalories ? 2000 : 200 }
    private var step: Int { isCalories ? 5 : 1 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(formattedDisplay)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(color)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: wholeValue)

                HStack(spacing: 0) {
                    Picker("Whole", selection: $wholeValue) {
                        ForEach(Array(stride(from: 0, through: maxWhole, by: step)), id: \.self) { v in
                            Text("\(v)").tag(v)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 100)
                    .clipped()
                    .onChange(of: wholeValue) { _, _ in HapticsManager.shared.selection() }

                    if !isCalories {
                        Text(".")
                            .font(.title3.bold())
                            .foregroundStyle(.secondary)

                        Picker("Decimal", selection: $decimalValue) {
                            ForEach(0..<10, id: \.self) { d in
                                Text("\(d)").tag(d)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 60)
                        .clipped()
                        .onChange(of: decimalValue) { _, _ in HapticsManager.shared.selection() }
                    }

                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
                .frame(height: 150)
            }
            .padding()
            .navigationTitle(label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if isCalories {
                            value = "\(wholeValue)"
                        } else {
                            let total = Double(wholeValue) + Double(decimalValue) / 10.0
                            value = total.truncatingRemainder(dividingBy: 1) == 0
                                ? "\(Int(total))" : String(format: "%.1f", total)
                        }
                        dismiss()
                    }
                    .bold()
                }
            }
        }
        .presentationDetents([.height(340)])
        .onAppear {
            let parsed = Double(value) ?? 0
            wholeValue = isCalories ? (Int(parsed) / step) * step : Int(parsed)
            decimalValue = isCalories ? 0 : Int((parsed - Double(Int(parsed))) * 10)
        }
    }

    private var formattedDisplay: String {
        if isCalories {
            return "\(wholeValue) \(unit)"
        }
        let total = Double(wholeValue) + Double(decimalValue) / 10.0
        return total.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(total)) \(unit)" : String(format: "%.1f %@", total, unit)
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

struct AmountPickerSheet: View {
    @Binding var amountGrams: String
    @Environment(\.dismiss) private var dismiss
    @State private var pickerValue: Int = 100

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("\(pickerValue) g")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: pickerValue)

                Picker("Grams", selection: $pickerValue) {
                    ForEach(Array(stride(from: 10, through: 1000, by: 10)), id: \.self) { g in
                        Text("\(g)").tag(g)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 150)
                .onChange(of: pickerValue) { _, _ in
                    HapticsManager.shared.selection()
                }
            }
            .padding()
            .navigationTitle("Amount")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        amountGrams = String(pickerValue)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
        .presentationDetents([.height(320)])
        .onAppear {
            pickerValue = Int(amountGrams) ?? 100
        }
    }
}

#Preview {
    FoodLogView { _ in }
}
