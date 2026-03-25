//
//  BarbellWeightPicker.swift
//  HealthPulse
//
//  Interactive barbell plate visualizer. Olympic bar = 20 kg.
//  Tap a plate button to add a pair (both sides); long-press to remove last pair of that size.
//

import SwiftUI

struct BarbellWeightPicker: View {
    @Binding var weight: Double?

    private let barWeight = 20.0
    private let plates: [(kg: Double, color: Color)] = [
        (1.25, .gray),
        (2.5,  Color(white: 0.85)),
        (5,    Color(white: 0.9)),
        (10,   .green),
        (15,   .yellow),
        (20,   .blue),
        (25,   .red)
    ]

    @State private var platePairs: [Double] = []

    private var totalWeight: Double {
        barWeight + platePairs.reduce(0) { $0 + $1 * 2 }
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(weightLabel(totalWeight))
                .font(.title2.bold())
                .monospacedDigit()

            barbellDiagram

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(plates, id: \.kg) { plate in
                    plateButton(plate)
                }
            }

            Button("Clear") {
                platePairs.removeAll()
                syncWeight()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .onAppear { initFromWeight() }
    }

    // MARK: - Barbell Diagram

    private var barbellDiagram: some View {
        HStack(spacing: 2) {
            ForEach(platePairs.reversed(), id: \.self) { kg in
                plateSlice(kg)
            }
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 56, height: 10)
            ForEach(platePairs, id: \.self) { kg in
                plateSlice(kg)
            }
        }
        .frame(height: 36)
        .animation(MotionTokens.micro, value: platePairs.count)
    }

    private func plateSlice(_ kg: Double) -> some View {
        let w = max(7, CGFloat(kg) * 1.4)
        return RoundedRectangle(cornerRadius: 2)
            .fill(colorFor(kg))
            .frame(width: w, height: 30)
            .overlay(
                Text(kg < 10 ? String(format: "%.2g", kg) : "\(Int(kg))")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.black.opacity(0.5))
                    .rotationEffect(.degrees(-90))
            )
    }

    // MARK: - Plate Buttons

    private func plateButton(_ plate: (kg: Double, color: Color)) -> some View {
        let label = plate.kg < 10 ? String(format: "%.2g", plate.kg) : "\(Int(plate.kg))"
        return Button {
            platePairs.append(plate.kg)
            syncWeight()
            HapticsManager.shared.selection()
        } label: {
            Text("+\(label)")
                .font(.caption.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(plate.color.opacity(0.25))
                .foregroundStyle(plate.color == Color(white: 0.85) || plate.color == Color(white: 0.9) ? Color.primary : plate.color)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(plate.color.opacity(0.4), lineWidth: 1))
        }
        .simultaneousGesture(
            LongPressGesture().onEnded { _ in
                if let last = platePairs.lastIndex(of: plate.kg) {
                    platePairs.remove(at: last)
                    syncWeight()
                    HapticsManager.shared.selection()
                }
            }
        )
    }

    // MARK: - Helpers

    private func colorFor(_ kg: Double) -> Color {
        plates.first { $0.kg == kg }?.color ?? .gray
    }

    private func syncWeight() {
        weight = totalWeight
    }

    private func weightLabel(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f kg", value)
            : String(format: "%.2g kg", value)
    }

    private func initFromWeight() {
        guard let w = weight, w > barWeight else { return }
        var remaining = (w - barWeight) / 2
        var result: [Double] = []
        for plate in plates.sorted(by: { $0.kg > $1.kg }) {
            while remaining >= plate.kg - 0.001 {
                result.append(plate.kg)
                remaining -= plate.kg
            }
        }
        platePairs = result
    }
}
