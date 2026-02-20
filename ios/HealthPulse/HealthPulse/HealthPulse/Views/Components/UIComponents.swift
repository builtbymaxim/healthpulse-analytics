//
//  UIComponents.swift
//  HealthPulse
//
//  Reusable UI components — Phase 11 "Emerald Night" design system
//

import SwiftUI
import UIKit
import Combine

// MARK: - App Theme

/// Central theme configuration — "Emerald Night" palette
struct AppTheme {
    // Brand colors — deep emerald family
    static let primary      = Color(hex: "16C784")   // Deep emerald (was neon mint)
    static let primaryDark  = Color(hex: "0D9668")   // Dark emerald for pressed states
    static let accent       = Color(hex: "34D399")   // Bright mint for highlights only

    // Background surfaces
    static let backgroundDark   = Color(hex: "080B0A")  // Near-black with faint warmth
    static let backgroundMedium = Color(hex: "0F1511")  // Surface 1 — base cards
    static let surface1         = Color(hex: "0F1511")  // Dark green-tinted base
    static let surface2         = Color(hex: "161D18")  // Elevated cards
    static let surface3         = Color(hex: "1E2920")  // Floating sheets / modals
    static let cardBackground   = Color(hex: "161D18")  // Alias for surface2
    static let greenTint        = Color(hex: "0A1F12")  // BG gradient midpoint

    // Border
    static let border = Color(hex: "2A3B2E")

    // Text tokens
    static let textPrimary   = Color(hex: "F0FAF2")  // Near-white with green warmth
    static let textSecondary = Color(hex: "8BA98E")  // Muted green-gray
    static let textTertiary  = Color(hex: "4D6651")  // Very muted — captions, timestamps

    // Gradients
    static let backgroundGradient = LinearGradient(
        colors: [Color(hex: "080B0A"), Color(hex: "0A1F12"), Color(hex: "080B0A")],
        startPoint: .top,
        endPoint: .bottom
    )

    // Semantic colors
    static let success = Color(hex: "16C784")  // Same as primary — reinforces brand
    static let warning = Color(hex: "F59E0B")  // Amber — warmer than generic orange
    static let error   = Color(hex: "EF4444")  // Crisp red
    static let info    = Color(hex: "3B82F6")  // Electric blue
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Themed Background

/// Reusable themed background with drifting glow orbs
struct ThemedBackground: View {
    var showGlow: Bool = true
    var glowIntensity: Double = 0.20

    @State private var driftX: CGFloat = 0
    @State private var driftY: CGFloat = 0

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            if showGlow {
                // Top-right drifting glow
                Circle()
                    .fill(AppTheme.primary.opacity(glowIntensity))
                    .blur(radius: 120)
                    .frame(width: 300, height: 300)
                    .offset(x: 150 + driftX, y: -200 + driftY)

                // Bottom-left subtle glow
                Circle()
                    .fill(AppTheme.primary.opacity(glowIntensity * 0.5))
                    .blur(radius: 100)
                    .frame(width: 200, height: 200)
                    .offset(x: -150 - driftX, y: 400 + driftY)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) {
                driftX = 15
                driftY = -15
            }
        }
    }
}

// MARK: - Animated Gradient Background

/// Animated gradient for auth / landing screens
struct AnimatedGradientBackground: View {
    @State private var animateGradient = false

    var body: some View {
        LinearGradient(
            colors: [
                Color(hex: "080B0A"),
                Color(hex: "0A1F12"),
                Color(hex: "080B0A"),
                Color(hex: "0D1A10")
            ],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                animateGradient = true
            }
        }
    }
}

// MARK: - Themed Background Modifier

extension View {
    func themedBackground(showGlow: Bool = true) -> some View {
        ZStack {
            ThemedBackground(showGlow: showGlow)
            self
        }
    }
}

// MARK: - Glassmorphism Card

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 20
    let content: () -> Content

    init(cornerRadius: CGFloat = 20, @ViewBuilder content: @escaping () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content
    }

    var body: some View {
        content()
            .padding()
            .background {
                ZStack {
                    // Base fill — green-tinted dark surface
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(AppTheme.surface2.opacity(0.92))
                    // Top shimmer gradient
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.06), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.10), Color.white.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Section Header Label

/// ALL-CAPS tracked section header for visual hierarchy
struct SectionHeaderLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(1.2)
            .foregroundStyle(AppTheme.textTertiary)
    }
}

// MARK: - Press Effect Button Style

/// Subtle scale-down press effect for all primary buttons
struct PressEffect: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Card Shadow Modifier

extension View {
    /// Level 1 shadow — base cards on dark background
    func cardShadow() -> some View {
        self.shadow(color: .black.opacity(0.20), radius: 12, y: 4)
    }

    /// Level 2 shadow — elevated cards
    func elevatedShadow() -> some View {
        self.shadow(color: .black.opacity(0.35), radius: 20, y: 8)
    }

    /// Primary glow — active / selected elements
    func primaryGlow() -> some View {
        self.shadow(color: AppTheme.primary.opacity(0.20), radius: 24)
    }
}

// MARK: - Haptics Manager

class HapticsManager {
    static let shared = HapticsManager()
    private init() {}

    private let lightImpact      = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact     = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact      = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionFeedback    = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()

    func prepare() {
        lightImpact.prepare()
        mediumImpact.prepare()
        selectionFeedback.prepare()
    }

    func light()     { lightImpact.impactOccurred() }
    func medium()    { mediumImpact.impactOccurred() }
    func heavy()     { heavyImpact.impactOccurred() }
    func selection() { selectionFeedback.selectionChanged() }

    func success() { notificationFeedback.notificationOccurred(.success) }
    func warning() { notificationFeedback.notificationOccurred(.warning) }
    func error()   { notificationFeedback.notificationOccurred(.error) }

    /// Double-heavy tap — used for Personal Record achievements
    func doubleHeavy() {
        heavyImpact.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            self.heavyImpact.impactOccurred()
        }
    }
}

// MARK: - Skeleton View

struct SkeletonView: View {
    @State private var isAnimating = false

    var body: some View {
        LinearGradient(
            colors: [
                AppTheme.surface2,
                AppTheme.surface3,
                AppTheme.surface2
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .mask(Rectangle())
        .offset(x: isAnimating ? 200 : -200)
        .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)
        .onAppear { isAnimating = true }
    }
}

struct SkeletonShape: View {
    let width: CGFloat?
    let height: CGFloat

    init(width: CGFloat? = nil, height: CGFloat = 16) {
        self.width = width
        self.height = height
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(AppTheme.surface2)
            .frame(width: width, height: height)
            .overlay(SkeletonView())
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct SkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonShape(width: 120, height: 20)
            SkeletonShape(height: 14)
            SkeletonShape(width: 200, height: 14)
            HStack {
                SkeletonShape(width: 60, height: 30)
                Spacer()
                SkeletonShape(width: 80, height: 30)
            }
        }
        .padding()
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .cardShadow()
    }
}

// MARK: - Toast View

enum ToastType {
    case success, error, info, warning

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error:   return "xmark.circle.fill"
        case .info:    return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: return AppTheme.success
        case .error:   return AppTheme.error
        case .info:    return AppTheme.info
        case .warning: return AppTheme.warning
        }
    }
}

/// Animated icon that springs/spins into view
private struct AnimatedToastIcon: View {
    let type: ToastType
    @State private var scale: CGFloat = 0.1
    @State private var rotation: Double = -90
    @State private var opacity: Double = 0

    var body: some View {
        Image(systemName: type.icon)
            .foregroundStyle(type.color)
            .font(.body.weight(.semibold))
            .scaleEffect(scale)
            .rotationEffect(.degrees(type == .error ? rotation : 0))
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    scale = 1.0
                    rotation = 0
                    opacity = 1
                }
            }
    }
}

/// Pill-shaped bottom toast — premium frosted-glass style
struct ToastView: View {
    let message: String
    let type: ToastType

    var body: some View {
        HStack(spacing: 10) {
            AnimatedToastIcon(type: type)

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .background {
            ZStack {
                Capsule().fill(AppTheme.surface3.opacity(0.95))
                Capsule().fill(.thinMaterial)
            }
        }
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.10), Color.white.opacity(0.03)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .elevatedShadow()
    }
}

// MARK: - Toast Manager

@MainActor
class ToastManager: ObservableObject {
    static let shared = ToastManager()
    private init() {}

    @Published var currentToast: (message: String, type: ToastType)?
    @Published var isShowing = false

    func show(_ message: String, type: ToastType = .info) {
        // Dismiss current toast immediately if showing
        if isShowing {
            withAnimation(.easeIn(duration: 0.15)) { isShowing = false }
        }
        currentToast = (message, type)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) {
            isShowing = true
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation(.easeIn(duration: 0.25)) {
                isShowing = false
            }
        }
    }

    func success(_ message: String) { HapticsManager.shared.success(); show(message, type: .success) }
    func error(_ message: String)   { HapticsManager.shared.error();   show(message, type: .error)   }
    func info(_ message: String)    { show(message, type: .info) }
    func warning(_ message: String) { HapticsManager.shared.warning(); show(message, type: .warning) }
}

/// Bottom-anchored toast overlay — place on root ZStack
struct ToastContainer: View {
    @ObservedObject var manager = ToastManager.shared

    var body: some View {
        VStack {
            Spacer()
            if manager.isShowing, let toast = manager.currentToast {
                ToastView(message: toast.message, type: toast.type)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 96) // Clear the tab bar + safe area
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.72), value: manager.isShowing)
    }
}

// MARK: - Animated Number

struct AnimatedNumber: View {
    let value: Double
    let format: String

    @State private var animatedValue: Double = 0

    init(_ value: Double, format: String = "%.0f") {
        self.value = value
        self.format = format
    }

    var body: some View {
        Text(String(format: format, animatedValue))
            .contentTransition(.numericText())
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    animatedValue = value
                }
            }
            .onChange(of: value) { _, newValue in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    animatedValue = newValue
                }
            }
    }
}

// MARK: - Progress Ring

struct ProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let color: Color
    var backgroundColor: Color = Color.gray.opacity(0.15)

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(animatedProgress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Staggered Animation Modifier

struct StaggeredAnimation: ViewModifier {
    let index: Int
    let animation: Animation

    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .onAppear {
                // 60ms stagger (down from 100ms for snappier feel)
                withAnimation(animation.delay(Double(index) * 0.06)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func staggeredAnimation(
        index: Int,
        animation: Animation = .spring(response: 0.45, dampingFraction: 0.82)
    ) -> some View {
        modifier(StaggeredAnimation(index: index, animation: animation))
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.textTertiary)

            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.primary)
                    .padding(.top, 8)
            }
        }
        .padding(40)
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: ViewModifier {
    let isLoading: Bool
    let message: String?

    func body(content: Content) -> some View {
        content
            .overlay {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.35)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(AppTheme.primary)
                                .scaleEffect(1.2)
                            if let message = message {
                                Text(message)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        .padding(24)
                        .background(AppTheme.surface3)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .elevatedShadow()
                    }
                }
            }
    }
}

extension View {
    func loadingOverlay(isLoading: Bool, message: String? = nil) -> some View {
        modifier(LoadingOverlay(isLoading: isLoading, message: message))
    }
}

// MARK: - Previews

#Preview("Skeleton") {
    VStack(spacing: 16) {
        SkeletonCard()
        SkeletonCard()
    }
    .padding()
    .background(AppTheme.backgroundDark)
}

#Preview("Toast") {
    VStack(spacing: 12) {
        ToastView(message: "Workout saved successfully!", type: .success)
        ToastView(message: "Failed to load data", type: .error)
        ToastView(message: "New feature available", type: .info)
        ToastView(message: "Low battery", type: .warning)
    }
    .padding()
    .background(AppTheme.backgroundDark)
}

#Preview("Empty State") {
    EmptyStateView(
        icon: "dumbbell",
        title: "No Workouts Yet",
        message: "Start logging your workouts to see them here",
        actionTitle: "Log Workout",
        action: {}
    )
    .background(AppTheme.backgroundDark)
}
