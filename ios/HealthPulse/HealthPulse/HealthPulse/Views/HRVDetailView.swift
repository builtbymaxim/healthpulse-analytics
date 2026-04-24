//
//  HRVDetailView.swift
//  HealthPulse
//
//  HRV historical trend summary

import SwiftUI
import Charts

struct HRVDetailView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDays = 7
    @State private var isLoading = false
    @State private var selectedDate: Date?
    @State private var chartData: [HealthKitService.ChartDataPoint] = []

    let periods = [7, 14, 30]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // HEADER
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last \(selectedDays) Days")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Latest")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text("\(Int(currentHRV))ms")
                                    .font(.title2.bold())
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Average")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text("\(Int(averageHRV))ms")
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
                    Picker("Days", selection: $selectedDays) {
                        Text("7 Days").tag(7)
                        Text("14 Days").tag(14)
                        Text("30 Days").tag(30)
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    // Chart
                    if isLoading {
                        ProgressView()
                            .frame(height: 250)
                    } else if !chartData.isEmpty {
                        hrvChart
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

                    // Stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(
                            title: "Min",
                            value: String(format: "%.0f", minHRV),
                            subtitle: "ms"
                        )
                        StatCard(
                            title: "Max",
                            value: String(format: "%.0f", maxHRV),
                            subtitle: "ms"
                        )
                        StatCard(
                            title: "Trend",
                            value: trendArrow
                        )
                        StatCard(
                            title: "Status",
                            value: hrvStatus.label,
                            subtitle: hrvStatus.icon
                        )
                    }
                    .padding(.horizontal)

                    // Healthy zone note
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle()
                                .fill(Color.indigo)
                                .frame(width: 12, height: 12)
                            Text("Healthy Zone: 40–100 ms")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .padding()
                    .background(AppTheme.surface1)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
                .padding(.top)
            }
            .background(ThemedBackground())
            .navigationTitle("HRV Trend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadHRVData()
            }
            .onChange(of: selectedDays) {
                Task { await loadHRVData() }
            }
        }
    }

    private var hrvChart: some View {
        Chart(chartData) { point in
            // Healthy zone band — indigo, clearly separate from emerald data
            RectangleMark(yStart: .value("Low", 40), yEnd: .value("High", 100))
                .foregroundStyle(Color.indigo.opacity(0.12))
                .zIndex(0)

            // Zone boundaries — dashed lines
            RuleMark(y: .value("Upper", 100))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(Color.indigo.opacity(0.5))
                .zIndex(0)

            RuleMark(y: .value("Lower", 40))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(Color.indigo.opacity(0.5))
                .zIndex(0)

            // Thin connecting line (guide, behind dots)
            LineMark(x: .value("Date", point.date), y: .value("HRV", point.value))
                .foregroundStyle(AppTheme.primary.opacity(0.4))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .zIndex(1)

            // Prominent dots (hero element, tappable)
            PointMark(x: .value("Date", point.date), y: .value("HRV", point.value))
                .foregroundStyle(AppTheme.primary)
                .symbolSize(isSelectedPoint(point) ? 140 : 80)
                .zIndex(2)
        }
        .chartXSelection(value: $selectedDate)
        .chartYScale(domain: 0...max(120, (chartData.map { $0.value }.max() ?? 100) * 1.1))
        .chartPlotStyle { plotArea in
            plotArea.background(AppTheme.surface1)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: max(1, chartData.count / 4))) { _ in
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
        .overlay(alignment: .top) {
            if let selected = selectedPoint {
                VStack(spacing: 4) {
                    Text(String(format: "%.0f ms", selected.value))
                        .font(.caption.bold())
                    Text(dateLabel(selected.date))
                        .font(.caption2)
                    Text(hrvStatus.label)
                        .font(.caption)
                        .foregroundStyle(hrvStatus.color)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.surface2)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.top, 8)
            }
        }
    }

    private var currentHRV: Double {
        chartData.last?.value ?? 0
    }

    private var averageHRV: Double {
        chartData.isEmpty ? 0 : chartData.map { $0.value }.reduce(0, +) / Double(chartData.count)
    }

    private var minHRV: Double {
        chartData.map { $0.value }.min() ?? 0
    }

    private var maxHRV: Double {
        chartData.map { $0.value }.max() ?? 0
    }

    private var hrvStatus: (label: String, icon: String, color: Color) {
        let current = currentHRV
        if current >= 100 {
            return ("Excellent", "heart.fill", .green)
        } else if current >= 40 {
            return ("Normal", "heart.fill", AppTheme.primary)
        } else {
            return ("Low", "heart.fill", .orange)
        }
    }

    private var trendArrow: String {
        if chartData.count < 2 { return "→" }
        let recentHalf = chartData.suffix(chartData.count / 2).map { $0.value }.reduce(0, +) / Double(max(chartData.count / 2, 1))
        let olderHalf = chartData.prefix(chartData.count / 2).map { $0.value }.reduce(0, +) / Double(max(chartData.count / 2, 1))
        if recentHalf > olderHalf + 3 { return "↑" }
        if recentHalf < olderHalf - 3 { return "↓" }
        return "→"
    }

    private var selectedPoint: HealthKitService.ChartDataPoint? {
        guard let selectedDate else { return nil }
        let calendar = Calendar.current
        return chartData.first { point in
            calendar.isDate(point.date, inSameDayAs: selectedDate)
        }
    }

    private func isSelectedPoint(_ point: HealthKitService.ChartDataPoint) -> Bool {
        selectedPoint?.id == point.id
    }

    private func dateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func loadHRVData() async {
        isLoading = true
        let data = await HealthKitService.shared.fetchHRVHistory(days: selectedDays)
        chartData = data
        isLoading = false
    }
}

#Preview {
    HRVDetailView()
}
