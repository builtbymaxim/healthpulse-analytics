//
//  WeightScrollWheel.swift
//  HealthPulse
//
//  Dual-column wheel picker for weight input.
//  Left: whole kg (0–300). Right: fraction (.00/.25/.50/.75).
//

import SwiftUI

struct WeightScrollWheel: View {
    @Binding var weight: Double?

    @State private var wholeKg: Int = 0
    @State private var fraction: Double = 0.0

    private let fractions: [Double] = [0.0, 0.25, 0.50, 0.75]

    var body: some View {
        HStack(spacing: 0) {
            // Whole kg column
            Picker("kg", selection: $wholeKg) {
                Text("—").tag(0)
                ForEach(1...300, id: \.self) { kg in
                    Text("\(kg)").tag(kg)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 100)
            .clipped()
            .onChange(of: wholeKg) { _, _ in
                syncWeight()
                HapticsManager.shared.selection()
            }

            Text(".")
                .font(.title3.bold())
                .foregroundStyle(.secondary)

            // Fraction column
            Picker("fraction", selection: $fraction) {
                ForEach(fractions, id: \.self) { f in
                    Text(fractionLabel(f)).tag(f)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 80)
            .clipped()
            .onChange(of: fraction) { _, _ in
                syncWeight()
                HapticsManager.shared.selection()
            }

            Text("kg")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
        }
        .frame(height: 140)
        .onAppear { initFromWeight() }
    }

    private func fractionLabel(_ f: Double) -> String {
        switch f {
        case 0.0:  return "00"
        case 0.25: return "25"
        case 0.50: return "50"
        case 0.75: return "75"
        default:   return "00"
        }
    }

    private func syncWeight() {
        let total = Double(wholeKg) + fraction
        weight = total == 0 ? nil : total
    }

    private func initFromWeight() {
        guard let w = weight, w > 0 else { return }
        wholeKg = Int(w)
        let remainder = w - Double(Int(w))
        // Snap to nearest fraction
        fraction = fractions.min(by: { abs($0 - remainder) < abs($1 - remainder) }) ?? 0.0
    }
}
