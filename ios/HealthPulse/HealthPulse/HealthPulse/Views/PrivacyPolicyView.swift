//
//  PrivacyPolicyView.swift
//  HealthPulse
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var processedText: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(LocalizedStringKey(processedText))
                    .font(.body)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineSpacing(4)
                    .padding()
            }
            .background(ThemedBackground())
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationBackground(.ultraThinMaterial)
        .task {
            guard let url = Bundle.main.url(forResource: "privacy-policy", withExtension: "md"),
                  let text = try? String(contentsOf: url, encoding: .utf8) else {
                processedText = "Privacy policy unavailable."
                return
            }
            processedText = text
                .replacingOccurrences(of: "## ", with: "**")
                .replacingOccurrences(of: "# ", with: "**")
                .replacingOccurrences(of: "- ", with: "• ")
        }
    }
}
