//
//  CommitmentsView.swift
//  HealthPulseWatch
//
//  Shows Today's Now / Next / Tonight commitment cards from the iPhone dashboard.
//

import SwiftUI

struct CommitmentsView: View {
    @EnvironmentObject var store: WatchWorkoutStore

    var body: some View {
        Group {
            if store.commitments.isEmpty {
                emptyState
            } else {
                commitmentList
            }
        }
        .containerBackground(.black, for: .navigation)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Open HealthPulse on iPhone")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var commitmentList: some View {
        List(store.commitments) { commitment in
            commitmentRow(commitment)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
    }

    private func commitmentRow(_ commitment: WatchCommitment) -> some View {
        HStack(spacing: 8) {
            Image(systemName: commitment.icon)
                .font(.system(size: 14))
                .foregroundStyle(slotColor(commitment.slot))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(commitment.slot.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(slotColor(commitment.slot))
                Text(commitment.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(2)
                if !commitment.subtitle.isEmpty {
                    Text(commitment.subtitle)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if let modifier = commitment.loadModifier {
                Spacer()
                Text(modifier)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func slotColor(_ slot: String) -> Color {
        switch slot.lowercased() {
        case "now":    return .green
        case "next":   return .orange
        case "tonight": return .blue
        default:        return .secondary
        }
    }
}
