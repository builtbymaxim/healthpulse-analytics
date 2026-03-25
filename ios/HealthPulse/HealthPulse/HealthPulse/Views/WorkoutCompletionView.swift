//
//  WorkoutCompletionView.swift
//  HealthPulse
//
//  Post-workout celebration and PR display screens.
//  Extracted from WorkoutExecutionView.
//

import SwiftUI

// MARK: - Workout Completion View

struct WorkoutCompletionView: View {
    let summary: (duration: Int, exercises: Int, sets: Int)
    let onDone: () -> Void

    @State private var checkmarkScale: CGFloat = 0.3
    @State private var checkmarkOpacity: Double = 0
    @State private var textOpacity: Double = 0

    // Generic messages (no name)
    private static let genericMessages = [
        "Another one in the books!",
        "Consistency wins. Always.",
        "Stronger than yesterday.",
        "That's how champions train.",
        "Hard work pays off.",
        "Discipline over motivation.",
        "Progress, not perfection.",
        "The only bad workout is the one that didn't happen.",
        "Beast mode: activated."
    ]

    // Personalized messages (with {name} placeholder)
    private static let personalizedMessages = [
        "Crushed it, {name}!",
        "Great work, {name}!",
        "You showed up, {name}. That's what matters.",
        "One step closer to your goals, {name}.",
        "Your future self will thank you, {name}.",
        "You earned this rest, {name}.",
        "Keep stacking those wins, {name}.",
    ]

    private let message: String

    init(summary: (duration: Int, exercises: Int, sets: Int), onDone: @escaping () -> Void) {
        self.summary = summary
        self.onDone = onDone

        let name = AuthService.shared.currentUser?.displayName
        if let name, !name.isEmpty {
            let allMessages = Self.personalizedMessages.map {
                $0.replacingOccurrences(of: "{name}", with: name)
            } + Self.genericMessages
            self.message = allMessages.randomElement() ?? "Well done!"
        } else {
            self.message = Self.genericMessages.randomElement() ?? "Well done!"
        }
    }

    var body: some View {
        ZStack {
            AppTheme.primary.opacity(0.15)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)
                    .scaleEffect(checkmarkScale)
                    .opacity(checkmarkOpacity)

                VStack(spacing: 8) {
                    Text("Workout Complete")
                        .font(.title.bold())

                    Text(message)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .opacity(textOpacity)

                GlassCard {
                    HStack(spacing: 24) {
                        SummaryStatView(value: "\(summary.duration)", label: "min", icon: "clock")
                        SummaryStatView(value: "\(summary.exercises)", label: "exercises", icon: "figure.strengthtraining.traditional")
                        SummaryStatView(value: "\(summary.sets)", label: "sets", icon: "checkmark.circle")
                    }
                }
                .padding(.horizontal)
                .opacity(textOpacity)
                .padding(.top, 8)

                Spacer()

                Button {
                    onDone()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.primary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .opacity(textOpacity)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) {
                checkmarkScale = 1.0
                checkmarkOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
                textOpacity = 1.0
            }
        }
    }
}

// MARK: - Summary Stat View

private struct SummaryStatView: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.green)
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - PR Celebration View

struct PRCelebrationView: View {
    let prs: [PRInfo]
    let onDismiss: () -> Void

    @State private var appeared = false
    @State private var confettiOpacity = 1.0

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.yellow)
                        .scaleEffect(appeared ? 1 : 0.5)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.05), value: appeared)

                    Text("New Personal Records!")
                        .font(.title.bold())
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.3).delay(0.15), value: appeared)
                }
                .padding(.top, 32)
                .padding(.bottom, 16)

                // PR cards
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(prs.enumerated()), id: \.element.id) { i, pr in
                            prCard(pr: pr)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 28)
                                .animation(
                                    .spring(response: 0.5, dampingFraction: 0.75)
                                        .delay(0.2 + Double(i) * 0.12),
                                    value: appeared
                                )
                        }
                    }
                    .padding(.horizontal)
                }

                // Dismiss button
                Button("Awesome!") {
                    onDismiss()
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.primary)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.bottom, 32)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.3 + Double(prs.count) * 0.12), value: appeared)
            }

            // Confetti overlay — non-interactive
            ConfettiView()
                .opacity(confettiOpacity)
                .allowsHitTesting(false)
                .ignoresSafeArea()
        }
        .onAppear {
            HapticsManager.shared.doubleHeavy()
            withAnimation { appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                withAnimation(.easeOut(duration: 0.5)) { confettiOpacity = 0 }
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(50))
            appeared = true
        }
    }

    // MARK: - PR Card

    private func prCard(pr: PRInfo) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(pr.exerciseName)
                    .font(.headline)
                Text(formattedRecordType(pr.recordType))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    Text(formattedValue(pr))
                        .font(.title3.bold())
                        .foregroundStyle(.green)
                    if let badge = improvementBadge(pr) {
                        Text(badge)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green, in: Capsule())
                    }
                }
                if let prev = pr.previousValue, prev > 0 {
                    Text("prev: \(formattedValue(pr, value: prev))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // Share button
            Button {
                sharePR(pr)
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
        }
        .padding()
        .background(AppTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func formattedRecordType(_ type: String) -> String {
        type.split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private func formattedValue(_ pr: PRInfo, value: Double? = nil) -> String {
        let v = value ?? pr.value
        let rounded = v.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", v) : String(format: "%.1f", v)
        switch pr.recordType {
        case "max_reps": return "\(rounded) reps"
        case "max_volume": return "\(rounded) kg vol"
        default: return "\(rounded) kg"
        }
    }

    private func improvementBadge(_ pr: PRInfo) -> String? {
        guard let prev = pr.previousValue, prev > 0, pr.value > prev else { return nil }
        let pct = Int(((pr.value - prev) / prev) * 100)
        return pct > 0 ? "+\(pct)%" : nil
    }

    private func sharePR(_ pr: PRInfo) {
        let card = PRShareCard(pr: pr)
            .frame(width: 300, height: 180)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        guard let image = renderer.uiImage else { return }
        let av = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.rootViewController?.present(av, animated: true)
    }
}

// MARK: - Confetti View

private struct ConfettiView: View {
    private let startDate = Date()
    private let particleCount = 60
    private let colors: [Color] = [AppTheme.primary, .yellow, .green, .orange, .red]

    // Fixed particle properties (deterministic random using index seed)
    private struct Particle {
        let startX: CGFloat        // 0–1 fraction of width
        let startYFraction: CGFloat // 0–1 initial y offset
        let velocity: CGFloat      // px/s downward
        let driftAmp: CGFloat      // horizontal drift amplitude
        let driftFreq: CGFloat     // drift frequency
        let driftPhase: CGFloat    // drift phase offset
        let spinRate: Double       // radians/s
        let width: CGFloat
        let height: CGFloat
        let colorIndex: Int
    }

    private let particles: [Particle]

    init() {
        var rng = SystemRandomNumberGenerator()
        particles = (0..<60).map { i in
            func rand(_ lo: Double, _ hi: Double) -> CGFloat {
                CGFloat(Double.random(in: lo...hi, using: &rng))
            }
            return Particle(
                startX: rand(0, 1),
                startYFraction: rand(-0.5, 0),
                velocity: rand(120, 260),
                driftAmp: rand(8, 28),
                driftFreq: rand(0.5, 2.0),
                driftPhase: rand(0, .pi * 2),
                spinRate: Double.random(in: 1...4, using: &rng),
                width: rand(6, 12),
                height: rand(4, 8),
                colorIndex: i % 5
            )
        }
    }

    var body: some View {
        TimelineView(.animation) { ctx in
            let elapsed = ctx.date.timeIntervalSince(startDate)
            Canvas { context, size in
                for p in particles {
                    let y = (p.startYFraction * size.height + CGFloat(elapsed) * p.velocity)
                        .truncatingRemainder(dividingBy: size.height + 40)
                    let x = p.startX * size.width
                        + sin(CGFloat(elapsed) * p.driftFreq + p.driftPhase) * p.driftAmp
                    let angle = Angle(radians: elapsed * p.spinRate)
                    var ctx2 = context
                    ctx2.translateBy(x: x, y: y)
                    ctx2.rotate(by: angle)
                    let rect = CGRect(x: -p.width / 2, y: -p.height / 2,
                                      width: p.width, height: p.height)
                    ctx2.fill(Path(rect), with: .color(colors[p.colorIndex].opacity(0.85)))
                }
            }
        }
    }
}

// MARK: - PR Share Card

private struct PRShareCard: View {
    let pr: PRInfo

    private func formattedRecordType(_ type: String) -> String {
        type.split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private func formattedValue(_ value: Double) -> String {
        let rounded = value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value) : String(format: "%.1f", value)
        switch pr.recordType {
        case "max_reps": return "\(rounded) reps"
        case "max_volume": return "\(rounded) kg vol"
        default: return "\(rounded) kg"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.caption.bold())
                Text("HealthPulse")
                    .font(.caption.bold())
                Spacer()
                Text("Personal Record")
                    .font(.caption2)
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(AppTheme.primary)

            // Body
            VStack(alignment: .leading, spacing: 10) {
                Text(pr.exerciseName)
                    .font(.headline)
                Text(formattedRecordType(pr.recordType).uppercased())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .tracking(1)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(formattedValue(pr.value))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)

                    if let prev = pr.previousValue, prev > 0, pr.value > prev {
                        let pct = Int(((pr.value - prev) / prev) * 100)
                        if pct > 0 {
                            Text("+\(pct)%")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green, in: Capsule())
                        }
                    }
                }

                if let prev = pr.previousValue, prev > 0 {
                    Text("Previous best: \(formattedValue(prev))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }
}
