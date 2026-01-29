//
//  TrendsView.swift
//  HealthPulse
//
//  Charts and history view
//

import SwiftUI
import Charts

struct TrendsView: View {
    @State private var selectedMetric = "wellness"
    @State private var selectedPeriod = 7
    @State private var wellnessHistory: [WellnessScore] = []
    @State private var isLoading = false

    let metrics = ["wellness", "recovery", "readiness", "steps", "sleep"]
    let periods = [7, 14, 30]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Metric selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(metrics, id: \.self) { metric in
                                Button {
                                    selectedMetric = metric
                                } label: {
                                    Text(metric.capitalized)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(selectedMetric == metric ? Color.green : Color(.secondarySystemBackground))
                                        .foregroundStyle(selectedMetric == metric ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Period selector
                    Picker("Period", selection: $selectedPeriod) {
                        Text("7 Days").tag(7)
                        Text("14 Days").tag(14)
                        Text("30 Days").tag(30)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Chart
                    if isLoading {
                        ProgressView()
                            .frame(height: 250)
                    } else {
                        ChartView(data: chartData, metric: selectedMetric)
                            .frame(height: 250)
                            .padding()
                    }

                    // Summary stats
                    SummaryStatsView(data: chartData, metric: selectedMetric)
                        .padding(.horizontal)

                    // History list
                    VStack(alignment: .leading, spacing: 12) {
                        Text("History")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(chartData.reversed(), id: \.date) { item in
                            HistoryRow(date: item.date, value: item.value, metric: selectedMetric)
                                .padding(.horizontal)
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top)
            }
            .navigationTitle("Trends")
            .task {
                await loadData()
            }
            .onChange(of: selectedPeriod) {
                Task { await loadData() }
            }
        }
    }

    private var chartData: [ChartDataPoint] {
        // Generate sample data for demo
        let calendar = Calendar.current
        return (0..<selectedPeriod).reversed().map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
            let value = Double.random(in: 60...90)
            return ChartDataPoint(date: date, value: value)
        }
    }

    private func loadData() async {
        isLoading = true
        do {
            wellnessHistory = try await APIService.shared.getWellnessHistory(days: selectedPeriod)
        } catch {
            print("Failed to load history: \(error)")
        }
        isLoading = false
    }
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct ChartView: View {
    let data: [ChartDataPoint]
    let metric: String

    var body: some View {
        Chart(data) { item in
            LineMark(
                x: .value("Date", item.date),
                y: .value("Value", item.value)
            )
            .foregroundStyle(Color.green.gradient)
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("Date", item.date),
                y: .value("Value", item.value)
            )
            .foregroundStyle(Color.green.opacity(0.1).gradient)
            .interpolationMethod(.catmullRom)
        }
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: max(1, data.count / 5))) { value in
                AxisValueLabel(format: .dateTime.day().month())
            }
        }
    }
}

struct SummaryStatsView: View {
    let data: [ChartDataPoint]
    let metric: String

    var average: Double {
        guard !data.isEmpty else { return 0 }
        return data.map(\.value).reduce(0, +) / Double(data.count)
    }

    var highest: Double {
        data.map(\.value).max() ?? 0
    }

    var lowest: Double {
        data.map(\.value).min() ?? 0
    }

    var trend: String {
        guard data.count >= 2 else { return "stable" }
        let recent = data.suffix(3).map(\.value).reduce(0, +) / 3
        let older = data.prefix(3).map(\.value).reduce(0, +) / 3
        if recent > older + 3 { return "improving" }
        if recent < older - 3 { return "declining" }
        return "stable"
    }

    var body: some View {
        HStack(spacing: 16) {
            StatBox(title: "Average", value: String(format: "%.0f", average), color: .blue)
            StatBox(title: "Highest", value: String(format: "%.0f", highest), color: .green)
            StatBox(title: "Lowest", value: String(format: "%.0f", lowest), color: .orange)
            StatBox(title: "Trend", value: trend.capitalized, color: trendColor)
        }
    }

    var trendColor: Color {
        switch trend {
        case "improving": return .green
        case "declining": return .red
        default: return .gray
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundStyle(color)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct HistoryRow: View {
    let date: Date
    let value: Double
    let metric: String

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(date, style: .date)
                    .font(.subheadline)
                Text(date, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(String(format: "%.0f", value))
                .font(.title3.bold())
                .foregroundStyle(scoreColor)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    var scoreColor: Color {
        if value >= 80 { return .green }
        if value >= 60 { return .orange }
        return .red
    }
}

#Preview {
    TrendsView()
}
