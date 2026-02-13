//
//  NutritionView.swift
//  HealthPulse
//
//  Daily nutrition tracking view with calorie and macro progress
//

import SwiftUI

struct NutritionView: View {
    @State private var summary: DailyNutritionSummary?
    @State private var isLoading = true
    @State private var error: String?
    @State private var showingFoodLog = false
    @State private var showingRecipeLibrary = false
    @State private var showingMealPlans = false
    @State private var showingBarcodeScanner = false
    @State private var selectedDate = Date()
    @State private var animationTrigger = false  // Triggers animation on food log

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView("Loading nutrition data...")
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let error = error {
                        ErrorView(message: error, retryAction: loadData)
                    } else if let summary = summary {
                        // Calorie Progress Ring
                        CalorieProgressCard(summary: summary, animationTrigger: animationTrigger)

                        // Macro Progress Bars
                        MacroProgressCard(summary: summary, animationTrigger: animationTrigger)

                        // Today's Meals
                        MealsListCard(entries: summary.entries)
                    }
                }
                .padding()
            }
            .navigationTitle("Nutrition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingBarcodeScanner = true
                        } label: {
                            Label("Scan Barcode", systemImage: "barcode.viewfinder")
                        }

                        Button {
                            showingRecipeLibrary = true
                        } label: {
                            Label("Browse Recipes", systemImage: "book.fill")
                        }

                        Button {
                            showingMealPlans = true
                        } label: {
                            Label("Meal Plans", systemImage: "list.bullet.clipboard.fill")
                        }

                        Divider()

                        Button {
                            showingFoodLog = true
                        } label: {
                            Label("Log Food Manually", systemImage: "pencil.line")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingFoodLog) {
                FoodLogView { newEntry in
                    Task {
                        await loadData()
                        animationTrigger.toggle()
                        HapticsManager.shared.success()
                    }
                }
            }
            .sheet(isPresented: $showingRecipeLibrary) {
                RecipeLibraryView(onRecipeAdded: {
                    Task {
                        await loadData()
                        animationTrigger.toggle()
                    }
                })
            }
            .sheet(isPresented: $showingMealPlans) {
                MealPlanBrowseView(onMealsAdded: {
                    Task {
                        await loadData()
                        animationTrigger.toggle()
                    }
                })
            }
            .sheet(isPresented: $showingBarcodeScanner) {
                BarcodeScannerView(onFoodAdded: {
                    Task {
                        await loadData()
                        animationTrigger.toggle()
                    }
                })
            }
            .refreshable {
                await loadData()
            }
            .task {
                await loadData()
            }
        }
    }

    private func loadData() async {
        // Only show full loading on initial load, not during pull-to-refresh
        if summary == nil {
            isLoading = true
        }
        error = nil

        do {
            summary = try await APIService.shared.getDailyNutritionSummary(date: selectedDate)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Calorie Progress Card

struct CalorieProgressCard: View {
    let summary: DailyNutritionSummary
    var animationTrigger: Bool = false

    @State private var animatedProgress: Double = 0
    @State private var showPulse: Bool = false

    var progress: Double {
        min(summary.calorieProgressPct / 100, 2.0)
    }

    var progressColor: Color {
        if summary.calorieProgressPct < 80 {
            return .blue
        } else if summary.calorieProgressPct <= 110 {
            return AppTheme.primary
        } else {
            return .orange
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Calories")
                    .font(.headline)
                Spacer()
                Text("\(Int(summary.nutritionScore))% Score")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)

                // Progress ring
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(progressColor, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                // Pulse effect at the tip when animating
                if showPulse {
                    Circle()
                        .fill(progressColor.opacity(0.4))
                        .frame(width: 30, height: 30)
                        .offset(y: -90)
                        .rotationEffect(.degrees(animatedProgress * 360 - 90))
                        .scaleEffect(showPulse ? 1.8 : 1.0)
                        .opacity(showPulse ? 0 : 1)
                }

                VStack(spacing: 4) {
                    Text("\(Int(summary.totalCalories))")
                        .font(.system(size: 36, weight: .bold))
                        .contentTransition(.numericText())
                    Text("of \(Int(summary.calorieTarget))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 180)

            HStack(spacing: 30) {
                VStack {
                    Text("\(Int(summary.caloriesRemaining))")
                        .font(.title3.bold())
                        .foregroundColor(summary.caloriesRemaining >= 0 ? .primary : .red)
                        .contentTransition(.numericText())
                    Text("Remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .frame(height: 30)

                VStack {
                    Text("\(Int(summary.calorieProgressPct))%")
                        .font(.title3.bold())
                        .contentTransition(.numericText())
                    Text("Progress")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
        .onAppear {
            // Animate on first appear
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            // Spring animation when progress changes
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animatedProgress = newValue
            }
        }
        .onChange(of: animationTrigger) { _, _ in
            // Show pulse effect when triggered by food log
            showPulse = true
            withAnimation(.easeOut(duration: 0.6)) {
                showPulse = false
            }
        }
    }
}

// MARK: - Macro Progress Card

struct MacroProgressCard: View {
    let summary: DailyNutritionSummary
    var animationTrigger: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Macros")
                    .font(.headline)
                Spacer()
            }

            MacroProgressBar(
                label: "Protein",
                current: summary.totalProteinG,
                target: summary.proteinTargetG,
                color: .blue,
                unit: "g",
                animationTrigger: animationTrigger
            )

            MacroProgressBar(
                label: "Carbs",
                current: summary.totalCarbsG,
                target: summary.carbsTargetG,
                color: .orange,
                unit: "g",
                animationTrigger: animationTrigger
            )

            MacroProgressBar(
                label: "Fat",
                current: summary.totalFatG,
                target: summary.fatTargetG,
                color: .purple,
                unit: "g",
                animationTrigger: animationTrigger
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

struct MacroProgressBar: View {
    let label: String
    let current: Double
    let target: Double
    let color: Color
    let unit: String
    var animationTrigger: Bool = false

    @State private var animatedWidth: CGFloat = 0
    @State private var showBounce: Bool = false

    var progress: Double {
        guard target > 0 else { return 0 }
        return min(current / target, 1.5)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text("\(Int(current))/\(Int(target))\(unit)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: animatedWidth)
                        .scaleEffect(y: showBounce ? 1.3 : 1.0, anchor: .center)
                }
                .onAppear {
                    // Animate on first appear
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
                        animatedWidth = geo.size.width * progress
                    }
                }
                .onChange(of: progress) { _, newValue in
                    // Spring animation when progress changes
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        animatedWidth = geo.size.width * newValue
                    }
                }
                .onChange(of: animationTrigger) { _, _ in
                    // Quick bounce effect when food is logged
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                        showBounce = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            showBounce = false
                        }
                    }
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Meals List Card

struct MealsListCard: View {
    let entries: [FoodEntry]

    var groupedByMeal: [String: [FoodEntry]] {
        Dictionary(grouping: entries) { $0.mealType ?? "other" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Food")
                    .font(.headline)
                Spacer()
                Text("\(entries.count) items")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No food logged today")
                        .foregroundStyle(.secondary)
                    Text("Tap + to add your first meal")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ForEach(MealType.allCases, id: \.self) { mealType in
                    if let mealEntries = groupedByMeal[mealType.rawValue], !mealEntries.isEmpty {
                        MealSection(mealType: mealType, entries: mealEntries)
                    }
                }

                // Other entries without meal type
                if let otherEntries = groupedByMeal["other"], !otherEntries.isEmpty {
                    MealSection(mealType: nil, entries: otherEntries)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

struct MealSection: View {
    let mealType: MealType?
    let entries: [FoodEntry]

    var totalCalories: Double {
        entries.reduce(0) { $0 + $1.calories }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let mealType = mealType {
                    Image(systemName: mealType.icon)
                        .foregroundStyle(.secondary)
                    Text(mealType.displayName)
                        .font(.subheadline.bold())
                } else {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                    Text("Other")
                        .font(.subheadline.bold())
                }
                Spacer()
                Text("\(Int(totalCalories)) cal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(entries) { entry in
                HStack {
                    Text(entry.name)
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(entry.calories)) cal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 24)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String
    let retryAction: () async -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Retry") {
                Task { await retryAction() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

#Preview {
    NutritionView()
}
