//
//  GreetingView.swift
//  HealthPulse
//
//  Full-screen greeting — Phase 11 blur-to-clear premium reveal.
//  Dashboard data loads in the background while this overlay is shown.
//

import SwiftUI

struct GreetingView: View {
    let displayName: String?
    let onDismiss: () -> Void

    // Blur-to-clear entrance
    @State private var textBlur: CGFloat = 14
    @State private var textOpacity: Double = 0
    @State private var subtitleBlur: CGFloat = 10
    @State private var subtitleOpacity: Double = 0

    // Radial background sweep
    @State private var radialScale: CGFloat = 0.1
    @State private var radialOpacity: Double = 0.18

    // Exit
    @State private var dismissOpacity: Double = 1
    @State private var dismissBlur: CGFloat = 0
    @State private var dismissScale: CGFloat = 1.0

    private static let greetings: [(personalized: String, fallback: String)] = [
        ("Let's make today count, {name}", "Let's make today count"),
        ("Ready to crush it, {name}?", "Ready to crush it?"),
        ("One day closer to your goals, {name}", "One day closer to your goals"),
        ("Consistency is your superpower, {name}", "Consistency is your superpower"),
        ("Time to level up, {name}", "Time to level up"),
        ("Your body will thank you, {name}", "Your body will thank you"),
        ("Show up. Work hard. Repeat, {name}", "Show up. Work hard. Repeat"),
        ("Champions are made daily, {name}", "Champions are made daily"),
        ("Today's effort, tomorrow's results, {name}", "Today's effort, tomorrow's results"),
        ("Small steps, big changes, {name}", "Small steps, big changes"),
        ("You've got this, {name}", "You've got this"),
        ("Progress over perfection, {name}", "Progress over perfection"),
        ("Keep building, {name}", "Keep building"),
        ("Every rep counts, {name}", "Every rep counts"),
        ("Stronger every day, {name}", "Stronger every day"),
        ("The grind never lies, {name}", "The grind never lies"),
        ("Discipline wins, {name}", "Discipline wins"),
        ("Your best is yet to come, {name}", "Your best is yet to come"),
        ("Stay hungry, stay focused, {name}", "Stay hungry, stay focused"),
        ("Make it happen, {name}", "Make it happen"),
    ]

    private var greeting: String {
        let dayIndex = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        let pair = Self.greetings[dayIndex % Self.greetings.count]
        if let name = displayName, !name.isEmpty {
            return pair.personalized.replacingOccurrences(of: "{name}", with: name)
        }
        return pair.fallback
    }

    private var timeOfDayGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        else if hour < 17 { return "Good afternoon" }
        else { return "Good evening" }
    }

    var body: some View {
        ZStack {
            // Deep dark background
            AppTheme.backgroundDark
                .ignoresSafeArea()

            // Slow radial green sweep — barely perceptible
            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppTheme.primary.opacity(radialOpacity), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 300
                    )
                )
                .frame(width: 600, height: 600)
                .scaleEffect(radialScale)
                .allowsHitTesting(false)

            VStack(spacing: 16) {
                Text(timeOfDayGreeting)
                    .font(.title3)
                    .foregroundStyle(AppTheme.textSecondary)
                    .blur(radius: subtitleBlur)
                    .opacity(subtitleOpacity)

                Text(greeting)
                    .font(.title.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .blur(radius: textBlur)
                    .opacity(textOpacity)
            }
        }
        .opacity(dismissOpacity)
        .blur(radius: dismissBlur)
        .scaleEffect(dismissScale)
        .onAppear {
            runAnimation()
        }
    }

    private func runAnimation() {
        // Phase 1: Radial background starts expanding
        withAnimation(.easeOut(duration: 8).repeatForever(autoreverses: true)) {
            radialScale = 1.2
            radialOpacity = 0.12
        }

        // Phase 1: Text materialises — blur clears, opacity rises
        withAnimation(.easeOut(duration: 0.5)) {
            textBlur = 0
            textOpacity = 1
        }

        // Subtitle clears slightly later
        withAnimation(.easeOut(duration: 0.5).delay(0.12)) {
            subtitleBlur = 0
            subtitleOpacity = 1
        }

        // Phase 3: Exit — blur back up + scale down + fade
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeIn(duration: 0.4)) {
                dismissOpacity = 0
                dismissBlur = 8
                dismissScale = 0.98
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                onDismiss()
            }
        }
    }
}

#Preview {
    GreetingView(displayName: "Max") { }
}
