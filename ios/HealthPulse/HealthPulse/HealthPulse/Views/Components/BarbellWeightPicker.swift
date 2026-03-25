//
//  BarbellWeightPicker.swift
//  HealthPulse
//
//  Plate-tap weight picker. Tap a plate to add its kg.
//  Loaded plates shown as colored chips — tap a chip to remove that plate.
//  Uses realistic plate images with IPF competition color coding.
//

import SwiftUI

struct BarbellWeightPicker: View {
    @Binding var weight: Double?
    @State private var addedPlates: [Double] = []

    private let plates: [(kg: Double, asset: String)] = [
        (1.25, "plate_1_25"),
        (2.5,  "plate_2_5"),
        (5,    "plate_5"),
        (10,   "plate_10"),
        (15,   "plate_15"),
        (20,   "plate_20"),
        (25,   "plate_25")
    ]

    var body: some View {
        VStack(spacing: 12) {
            // Animated weight total
            Text(weightLabel(weight ?? 0))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(MotionTokens.snappy, value: weight)

            // Loaded plates chip row
            loadedPlatesRow

            // Plate button grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                ForEach(plates, id: \.kg) { plate in
                    plateButton(plate)
                }
            }

            // Clear button
            Button("Clear") {
                withAnimation(MotionTokens.snappy) {
                    addedPlates.removeAll()
                    syncWeight()
                }
                HapticsManager.shared.selection()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .onAppear {
            if let w = weight, w > 0 {
                addedPlates = decompose(w)
                syncWeight()
            }
        }
    }

    // MARK: - Loaded Plates Chip Row

    @ViewBuilder
    private var loadedPlatesRow: some View {
        if !addedPlates.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(addedPlates.enumerated()), id: \.offset) { index, kg in
                        Button {
                            withAnimation(MotionTokens.snappy) {
                                addedPlates.remove(at: index)
                                syncWeight()
                            }
                            HapticsManager.shared.light()
                        } label: {
                            Text(formatPlate(kg))
                                .font(.caption2.bold())
                                .foregroundStyle(plateTextColor(kg))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(plateColor(kg), in: Capsule())
                                .overlay(
                                    Capsule().strokeBorder(
                                        Color.secondary.opacity(kg == 5 ? 0.4 : 0),
                                        lineWidth: 1
                                    )
                                )
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 28)
        }
    }

    // MARK: - Plate Button

    private func plateButton(_ plate: (kg: Double, asset: String)) -> some View {
        Button {
            withAnimation(MotionTokens.snappy) {
                addedPlates.append(plate.kg)
                addedPlates.sort(by: >)
                syncWeight()
            }
            HapticsManager.shared.selection()
        } label: {
            VStack(spacing: 4) {
                Image(plate.asset)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                Text(formatPlate(plate.kg))
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func syncWeight() {
        let total = addedPlates.reduce(0, +)
        weight = total == 0 ? nil : total
    }

    private func decompose(_ total: Double) -> [Double] {
        let available = plates.map(\.kg).sorted(by: >)
        var remaining = total
        var result: [Double] = []
        for plateKg in available {
            while remaining >= plateKg - 0.001 {
                result.append(plateKg)
                remaining -= plateKg
            }
        }
        return result
    }

    private func plateColor(_ kg: Double) -> Color {
        switch kg {
        case 25:   return .red
        case 20:   return .blue
        case 15:   return .yellow
        case 10:   return .green
        case 5:    return Color(UIColor.systemGray5)
        case 2.5:  return Color(UIColor.systemGray3)
        case 1.25: return Color(UIColor.systemGray3)
        default:   return .gray
        }
    }

    private func plateTextColor(_ kg: Double) -> Color {
        switch kg {
        case 25, 20, 10: return .white
        default:          return .primary
        }
    }

    private func formatPlate(_ kg: Double) -> String {
        kg.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f kg", kg)
            : String(format: "%g kg", kg)
    }

    private func weightLabel(_ value: Double) -> String {
        if value == 0 { return "— kg" }
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f kg", value)
            : String(format: "%g kg", value)
    }
}
