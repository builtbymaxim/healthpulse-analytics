//
//  StepDetailView.swift
//  HealthPulse
//
//  Step history with hourly/daily/monthly breakdown

import SwiftUI
import Charts

struct StepDetailView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var healthKit = HealthKitService.shared
    @State private var selectedPeriod: HealthKitService.ChartPeriod = .today
    @State private var stepData: [HealthKitService.ChartDataPoint] = []
    @State private var isLoading = false
    @State private var selectedDate: Date?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // HEADER — total/avg stats
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedPeriod == .today ? "Today" : periodLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text(Int(totalSteps).formatted())
                                    .font(.title2.bold())
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Average")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text(Int(averageSteps).formatted())
                                    .font(.title2.bold())
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                        }
                        .padding()
                        .background(AppTheme.surface2)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    // Period selector
                    Picker("Period", selection: $selectedPeriod) {
                        Text("Today (Hourly)").tag(HealthKitService.ChartPeriod.today)
                        Text("7 Days").tag(HealthKitService.ChartPeriod.sevenDays)
                        Text("30 Days").tag(HealthKitService.ChartPeriod.thirtyDays)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Chart
                    if isLoading {
                        ProgressView()
                            .frame(height: 250)
                    } else if !stepData.isEmpty {
                        stepChart
                            .frame(height: 250)
                            .padding()
                    } else {
                        Text("No data available")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(height: 250)
                            .frame(maxWidth: .infinity)
                            .background(AppTheme.surface1)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding()
                    }

                    // Goal progress
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Daily Goal")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                            Spacer()
                            Text("\(Int(totalSteps)) / 10,000")
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppTheme.surface1)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppTheme.primary)
                                    .frame(width: geo.size.width * CGFloat(min(totalSteps / 10000, 1)))
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding()
                    .background(AppTheme.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(
                            title: "Best Day",
                            value: String(format: "%.0f", bestDaySteps),
                            subtitle: bestDayLabel
                        )
                        StatCard(
                            title: "Trend",
                            value: trendArrow,
                            subtitle: "vs. prior period"
                        )
                        StatCard(
                            title: "Goal %",
                            value: String(format: "%.0f%%", min(totalSteps / 10000 * 100, 100))
                        )
                        StatCard(
                            title: "Frequency",
                            value: String(format: "%.0f", Double(daysWithSteps))
                        )
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
                .padding(.top)
            }
            .background(ThemedBackground())
            .navigationTitle("Steps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadStepData()
            }
            .onChange(of: selectedPeriod) {
                Task { await loadStepData() }
            }
        }
    }

    private var stepChart: some View {
        Chart(stepData) { point in
            BarMark(
                x: .value("Date", point.date, unit: bucketUnit),
                y: .value("Steps", point.value)
            )
            .foregroundStyle(isSelectedPoint(point) ? AppTheme.accent : AppTheme.primary)
            .cornerRadius(4)
            .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                if isSelectedPoint(point) {
                    Text(Int(point.value).formatted())
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.surface2)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.border, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartPlotStyle { plotArea in
            plotArea.background(AppTheme.surface1)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: bucketUnit)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisValueLabel()
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var bucketUnit: Calendar.Component {
        selectedPeriod == .today ? .hour : .day
    }

    private var periodLabel: String {
        switch selectedPeriod {
        case .sevenDays: return "Last 7 Days"
        case .thirtyDays: return "Last 30 Days"
        default: return ""
        }
    }

    private var totalSteps: Double {
        stepData.reduce(0) { $0 + $1.value }
    }

    private var averageSteps: Double {
        stepData.isEmpty ? 0 : totalSteps / Double(stepData.count)
    }

    private var bestDaySteps: Double {
        stepData.map { $0.value }.max() ?? 0
    }

    private var bestDayLabel: String {
        if let best = stepData.max(by: { $0.value < $1.value }) {
            let formatter = DateFormatter()
            formatter.dateFormat = selectedPeriod == .today ? "HH:mm" : "MMM d"
            return formatter.string(from: best.date)
        }
        return "—"
    }

    private var daysWithSteps: Int {
        stepData.filter { $0.value > 0 }.count
    }

    private var trendArrow: String {
        if stepData.count < 2 { return "→" }
        let recentHalf = stepData.suffix(stepData.count / 2).map { $0.value }.reduce(0, +) / Double(max(stepData.count / 2, 1))
        let olderHalf = stepData.prefix(stepData.count / 2).map { $0.value }.reduce(0, +) / Double(max(stepData.count / 2, 1))
        if recentHalf > olderHalf + 500 { return "↑" }
        if recentHalf < olderHalf - 500 { return "↓" }
        return "→"
    }

    private func isSelectedPoint(_ point: HealthKitService.ChartDataPoint) -> Bool {
        guard let selectedDate else { return false }
        let calendar = Calendar.current
        return calendar.isDate(point.date, inSameDayAs: selectedDate) ||
               (selectedPeriod == .today && calendar.component(.hour, from: point.date) == calendar.component(.hour, from: selectedDate))
    }

    private func loadStepData() async {
        isLoading = true
        stepData = await healthKit.fetchStepHistory(period: selectedPeriod)
        isLoading = false
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String?

    init(title: String, value: String, subtitle: String? = nil) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(AppTheme.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    StepDetailView()
}
