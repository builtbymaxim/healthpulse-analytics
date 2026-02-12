//
//  GreetingView.swift
//  HealthPulse
//
//  Full-screen animated greeting shown on app launch.
//  Displays a daily rotating motivational message with the user's name
//  while dashboard data loads in the background behind the overlay.
//

import SwiftUI

struct GreetingView: View {
    let displayName: String?
    let onDismiss: () -> Void

    @State private var textOpacity: Double = 0
    @State private var textScale: CGFloat = 0.9
    @State private var subtitleOpacity: Double = 0
    @State private var verticalOffset: CGFloat = 0
    @State private var dismissOpacity: Double = 1

    // Pool of ~20 motivational greetings that rotate daily
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
        if hour < 12 {
            return "Good morning"
        } else if hour < 17 {
            return "Good afternoon"
        } else {
            return "Good evening"
        }
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text(timeOfDayGreeting)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.6))
                    .opacity(subtitleOpacity)

                Text(greeting)
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(textOpacity)
                    .scaleEffect(textScale)
            }
            .offset(y: verticalOffset)
        }
        .opacity(dismissOpacity)
        .onAppear {
            runAnimation()
        }
    }

    private func runAnimation() {
        // Phase 1: Fade in greeting text with scale-up (0.3s)
        withAnimation(.easeOut(duration: 0.3)) {
            textOpacity = 1
            textScale = 1.0
        }

        // Subtitle fades in slightly after
        withAnimation(.easeOut(duration: 0.3).delay(0.15)) {
            subtitleOpacity = 1
        }

        // Phase 2: Hold for ~1.5s, then Phase 3: fade out + slide up (0.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeIn(duration: 0.4)) {
                dismissOpacity = 0
                verticalOffset = -40
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
