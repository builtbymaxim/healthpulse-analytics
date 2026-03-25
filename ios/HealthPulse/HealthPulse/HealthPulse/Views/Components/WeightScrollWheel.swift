//
//  WeightScrollWheel.swift
//  HealthPulse
//
//  Native wheel picker for weight input. 0–300 kg in 1.25 kg increments.
//

import SwiftUI

struct WeightScrollWheel: View {
    @Binding var weight: Double?

    private let steps: [Double] = stride(from: 0.0, through: 300.0, by: 1.25).map { $0 }

    var body: some View {
        Picker("Weight (kg)", selection: Binding(
            get: { weight ?? 0 },
            set: { weight = $0 == 0 ? nil : $0 }
        )) {
            ForEach(steps, id: \.self) { step in
                Text(step == 0 ? "—" : formatted(step))
                    .tag(step)
            }
        }
        .pickerStyle(.wheel)
        .frame(height: 140)
        .clipped()
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f kg", value)
            : String(format: "%.2g kg", value)
    }
}
