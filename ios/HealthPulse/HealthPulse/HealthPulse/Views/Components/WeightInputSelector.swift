//
//  WeightInputSelector.swift
//  HealthPulse
//
//  Sheet container toggling between plate-tap and scroll wheel weight input.
//  Mode preference persisted via @AppStorage.
//

import SwiftUI

struct WeightInputSelector: View {
    @Binding var weight: Double?
    @AppStorage("weightInputMode") private var mode: String = "plates"

    var body: some View {
        VStack(spacing: 16) {
            Picker("Input mode", selection: $mode) {
                Text("Plates").tag("plates")
                Text("Wheel").tag("wheel")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if mode == "wheel" {
                WeightScrollWheel(weight: $weight)
            } else {
                BarbellWeightPicker(weight: $weight)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 12)
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
    }
}
