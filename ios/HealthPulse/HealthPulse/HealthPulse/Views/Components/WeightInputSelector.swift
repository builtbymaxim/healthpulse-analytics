//
//  WeightInputSelector.swift
//  HealthPulse
//
//  Sheet container toggling between WeightScrollWheel and BarbellWeightPicker.
//  Mode preference persisted via @AppStorage.
//

import SwiftUI

struct WeightInputSelector: View {
    @Binding var weight: Double?
    @AppStorage("weightInputMode") private var mode: String = "wheel"

    var body: some View {
        VStack(spacing: 16) {
            Picker("Input mode", selection: $mode) {
                Text("Scroll Wheel").tag("wheel")
                Text("Barbell").tag("barbell")
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
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
    }
}
