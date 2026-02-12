//
//  SocialView.swift
//  HealthPulse
//
//  Social tab: training partners, invite codes, leaderboards
//

import SwiftUI
import Combine

// MARK: - View Model

@MainActor
class SocialViewModel: ObservableObject {
    @Published var partners: [Partner] = []
    @Published var leaderboardEntries: [String: [LeaderboardEntry]] = [:]
    @Published var isLoading = false
    @Published var error: String?

    var pendingPartners: [Partner] {
        partners.filter { $0.isPending }
    }

    var activePartners: [Partner] {
        partners.filter { $0.isActive }
    }

    func loadData() async {
        isLoading = true
        error = nil

        do {
            partners = try await APIService.shared.getPartners()

            // Preload leaderboard previews if we have active partners
            if !activePartners.isEmpty {
                async let streaks = APIService.shared.getLeaderboard(category: "workout_streaks")
                async let nutrition = APIService.shared.getLeaderboard(category: "nutrition_consistency")

                leaderboardEntries["workout_streaks"] = try await streaks
                leaderboardEntries["nutrition_consistency"] = try await nutrition
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func acceptPartner(_ id: UUID) async {
        do {
            let updated = try await APIService.shared.acceptPartnership(id)
            if let index = partners.firstIndex(where: { $0.id == id }) {
                partners[index] = updated
            }
            HapticsManager.shared.success()
        } catch {
            HapticsManager.shared.error()
        }
    }

    func declinePartner(_ id: UUID) async {
        do {
            _ = try await APIService.shared.declinePartnership(id)
            partners.removeAll { $0.id == id }
            HapticsManager.shared.medium()
        } catch {
            HapticsManager.shared.error()
        }
    }

    func endPartnership(_ id: UUID) async {
        do {
            _ = try await APIService.shared.endPartnership(id)
            partners.removeAll { $0.id == id }
            HapticsManager.shared.medium()
        } catch {
            HapticsManager.shared.error()
        }
    }
}

// MARK: - Social View

struct SocialView: View {
    @StateObject private var viewModel = SocialViewModel()
    @State private var showInviteSheet = false
    @State private var showUseCodeSheet = false
    @State private var showEndConfirmation: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Pending Requests
                    if !viewModel.pendingPartners.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Pending Requests", systemImage: "bell.badge.fill")
                                .font(.headline)
                                .foregroundStyle(.orange)

                            ForEach(viewModel.pendingPartners) { partner in
                                PendingPartnerCard(
                                    partner: partner,
                                    onAccept: { await viewModel.acceptPartner(partner.id) },
                                    onDecline: { await viewModel.declinePartner(partner.id) }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Active Partners
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Training Partners", systemImage: "person.2.fill")
                            .font(.headline)

                        if viewModel.activePartners.isEmpty {
                            EmptyPartnersCard(
                                onInvite: { showInviteSheet = true },
                                onEnterCode: { showUseCodeSheet = true }
                            )
                        } else {
                            ForEach(viewModel.activePartners) { partner in
                                ActivePartnerCard(partner: partner) {
                                    showEndConfirmation = partner.id
                                }
                            }

                            // Invite more
                            HStack(spacing: 12) {
                                Button {
                                    showInviteSheet = true
                                } label: {
                                    Label("Invite Partner", systemImage: "plus.circle.fill")
                                        .font(.subheadline.bold())
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.green.opacity(0.15))
                                        .foregroundStyle(.green)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }

                                Button {
                                    showUseCodeSheet = true
                                } label: {
                                    Label("Enter Code", systemImage: "keyboard")
                                        .font(.subheadline.bold())
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color(.secondarySystemBackground))
                                        .foregroundStyle(.primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Leaderboards
                    if !viewModel.activePartners.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Leaderboards", systemImage: "chart.bar.fill")
                                .font(.headline)

                            ForEach(LeaderboardCategory.allCases) { category in
                                NavigationLink {
                                    LeaderboardDetailView(category: category)
                                } label: {
                                    LeaderboardCard(
                                        category: category,
                                        entries: viewModel.leaderboardEntries[category.rawValue] ?? []
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Social")
            .refreshable {
                await viewModel.loadData()
            }
            .task {
                await viewModel.loadData()
            }
            .sheet(isPresented: $showInviteSheet) {
                InvitePartnerSheet()
            }
            .sheet(isPresented: $showUseCodeSheet) {
                UseInviteSheet {
                    await viewModel.loadData()
                }
            }
            .confirmationDialog(
                "End Partnership",
                isPresented: Binding(
                    get: { showEndConfirmation != nil },
                    set: { if !$0 { showEndConfirmation = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("End Partnership", role: .destructive) {
                    if let id = showEndConfirmation {
                        Task { await viewModel.endPartnership(id) }
                    }
                }
            } message: {
                Text("This will remove you from each other's leaderboards. You can always reconnect later.")
            }
        }
    }
}

// MARK: - Empty State

struct EmptyPartnersCard: View {
    let onInvite: () -> Void
    let onEnterCode: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text("No training partners yet")
                    .font(.headline)
                Text("Invite a friend or enter their code to start competing")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button(action: onInvite) {
                    Label("Invite Partner", systemImage: "plus.circle.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button(action: onEnterCode) {
                    Label("Enter Code", systemImage: "keyboard")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(24)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Pending Partner Card

struct PendingPartnerCard: View {
    let partner: Partner
    let onAccept: () async -> Void
    let onDecline: () async -> Void
    @State private var isProcessing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(partner.displayName)
                        .font(.headline)
                    Text("wants to be your training partner")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Proposed terms
            HStack(spacing: 16) {
                Label(partner.challenge.displayName, systemImage: partner.challenge.icon)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(partner.challenge.color.opacity(0.15))
                    .foregroundStyle(partner.challenge.color)
                    .clipShape(Capsule())

                Label(partner.duration.displayName, systemImage: "clock")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemBackground))
                    .foregroundStyle(.secondary)
                    .clipShape(Capsule())
            }

            // Accept / Decline buttons
            HStack(spacing: 12) {
                Button {
                    isProcessing = true
                    Task {
                        await onDecline()
                        isProcessing = false
                    }
                } label: {
                    Text("Decline")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(.tertiarySystemBackground))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(isProcessing)

                Button {
                    isProcessing = true
                    Task {
                        await onAccept()
                        isProcessing = false
                    }
                } label: {
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    } else {
                        Text("Accept")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                }
                .background(Color.green)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .disabled(isProcessing)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Active Partner Card

struct ActivePartnerCard: View {
    let partner: Partner
    let onEnd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text(partner.displayName)
                        .font(.headline)

                    if let days = partner.daysRemaining {
                        Text("\(days) days remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Ongoing partnership")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Menu {
                    Button("End Partnership", role: .destructive, action: onEnd)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                }
            }

            // Challenge badge + progress
            HStack(spacing: 12) {
                Label(partner.challenge.displayName, systemImage: partner.challenge.icon)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(partner.challenge.color.opacity(0.15))
                    .foregroundStyle(partner.challenge.color)
                    .clipShape(Capsule())

                if let total = partner.durationWeeks, let remaining = partner.daysRemaining {
                    let totalDays = total * 7
                    let elapsed = totalDays - remaining
                    ProgressView(value: Double(elapsed), total: Double(totalDays))
                        .tint(.green)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Invite Partner Sheet

struct InvitePartnerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var inviteCode: InviteCode?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "link.badge.plus")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)

                if let code = inviteCode {
                    VStack(spacing: 16) {
                        Text("Share this code")
                            .font(.headline)

                        Text(code.code)
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                        if let expires = code.expiresAt {
                            Text("Expires \(expires, style: .relative)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ShareLink(
                            item: "Join me on HealthPulse! Use my invite code: \(code.code)",
                            subject: Text("HealthPulse Training Partner Invite"),
                            message: Text("Use my code \(code.code) to become training partners!")
                        ) {
                            Label("Share Code", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.green)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 40)
                    }
                } else if isLoading {
                    ProgressView("Generating code...")
                } else {
                    Text("Generate an invite code for your training partner")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        generateCode()
                    } label: {
                        Text("Generate Code")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 40)
                }

                Spacer()
            }
            .navigationTitle("Invite Partner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func generateCode() {
        isLoading = true
        Task {
            do {
                inviteCode = try await APIService.shared.createInviteCode()
            } catch {
                print("Failed to generate invite code: \(error)")
            }
            isLoading = false
        }
    }
}

// MARK: - Use Invite Sheet

struct UseInviteSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onComplete: () async -> Void

    @State private var code = ""
    @State private var selectedChallenge: ChallengeType = .general
    @State private var selectedDuration: PartnershipDuration = .eightWeeks
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Code input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Invite Code")
                            .font(.headline)

                        TextField("Enter 6-character code", text: $code)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .onChange(of: code) { _, newValue in
                                code = String(newValue.prefix(6)).uppercased()
                            }
                    }

                    // Challenge type
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Challenge Focus")
                            .font(.headline)

                        ForEach(ChallengeType.allCases) { challenge in
                            Button {
                                selectedChallenge = challenge
                                HapticsManager.shared.selection()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: challenge.icon)
                                        .font(.title3)
                                        .foregroundStyle(selectedChallenge == challenge ? .white : challenge.color)
                                        .frame(width: 36, height: 36)
                                        .background(selectedChallenge == challenge ? challenge.color : challenge.color.opacity(0.15))
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(challenge.displayName)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.primary)
                                        Text(challenge.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if selectedChallenge == challenge {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    }
                                }
                                .padding(12)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedChallenge == challenge ? Color.green : Color.clear, lineWidth: 2)
                                )
                            }
                        }
                    }

                    // Duration
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Duration")
                            .font(.headline)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(PartnershipDuration.allCases) { duration in
                                Button {
                                    selectedDuration = duration
                                    HapticsManager.shared.selection()
                                } label: {
                                    Text(duration.displayName)
                                        .font(.subheadline.bold())
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(selectedDuration == duration ? Color.green : Color(.secondarySystemBackground))
                                        .foregroundStyle(selectedDuration == duration ? .white : .primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    // Submit
                    Button {
                        submitRequest()
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Send Request")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(code.count == 6 ? Color.green : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .disabled(code.count != 6 || isSubmitting)
                }
                .padding()
            }
            .navigationTitle("Enter Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func submitRequest() {
        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                _ = try await APIService.shared.useInviteCode(
                    code,
                    challengeType: selectedChallenge.rawValue,
                    durationWeeks: selectedDuration.weeks
                )
                await onComplete()
                HapticsManager.shared.success()
                dismiss()
            } catch let error as APIError {
                errorMessage = error.message
                HapticsManager.shared.error()
            } catch {
                errorMessage = "Something went wrong. Please try again."
                HapticsManager.shared.error()
            }
            isSubmitting = false
        }
    }
}

// MARK: - Leaderboard Card

struct LeaderboardCard: View {
    let category: LeaderboardCategory
    let entries: [LeaderboardEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundStyle(category.color)

                Text(category.displayName)
                    .font(.headline)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if entries.isEmpty {
                Text("No data yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // Top 3 preview
                ForEach(entries.prefix(3)) { entry in
                    HStack(spacing: 12) {
                        Text("#\(entry.rank)")
                            .font(.caption.bold())
                            .foregroundStyle(entry.rank == 1 ? .yellow : .secondary)
                            .frame(width: 28)

                        Text(entry.displayName ?? "Partner")
                            .font(.subheadline)
                            .foregroundStyle(entry.isCurrentUser ? .green : .primary)

                        Spacer()

                        Text("\(Int(entry.value)) \(category.unit)")
                            .font(.subheadline.bold())
                            .foregroundStyle(entry.isCurrentUser ? .green : .primary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Leaderboard Detail View

struct LeaderboardDetailView: View {
    let category: LeaderboardCategory
    @State private var entries: [LeaderboardEntry] = []
    @State private var isLoading = true
    @State private var exerciseName = ""

    var body: some View {
        List {
            if category == .exercisePrs {
                Section {
                    TextField("Exercise name (e.g. Bench Press)", text: $exerciseName)
                        .onSubmit { loadLeaderboard() }
                }
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if entries.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: category.icon)
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No entries yet")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 40)
                    Spacer()
                }
            } else {
                Section {
                    ForEach(entries) { entry in
                        HStack(spacing: 16) {
                            // Rank badge
                            ZStack {
                                Circle()
                                    .fill(rankColor(entry.rank).opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Text("\(entry.rank)")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(rankColor(entry.rank))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.displayName ?? "Partner")
                                    .font(.body)
                                    .foregroundStyle(entry.isCurrentUser ? .green : .primary)
                                if entry.isCurrentUser {
                                    Text("You")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }

                            Spacer()

                            Text("\(Int(entry.value)) \(category.unit)")
                                .font(.headline)
                                .foregroundStyle(entry.isCurrentUser ? .green : .primary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle(category.displayName)
        .task {
            if category != .exercisePrs {
                loadLeaderboard()
            } else {
                isLoading = false
            }
        }
    }

    private func loadLeaderboard() {
        isLoading = true
        Task {
            do {
                let name = category == .exercisePrs && !exerciseName.isEmpty ? exerciseName : nil
                entries = try await APIService.shared.getLeaderboard(
                    category: category.rawValue,
                    exerciseName: name
                )
            } catch {
                print("Leaderboard load error: \(error)")
            }
            isLoading = false
        }
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .secondary
        }
    }
}

#Preview {
    SocialView()
}
