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

/// Central theme configuration — adaptive "Emerald Night" (dark) / "Emerald Day" (light) palette
struct AppTheme {
    // Brand colors — deep emerald family (same in both modes)
    static let primary      = Color(hex: "16C784")   // Deep emerald
    static let primaryDark  = Color(hex: "0D9668")   // Dark emerald for pressed states
    static let accent       = Color(hex: "34D399")   // Bright mint for highlights only

    // Background surfaces — adaptive light/dark
    static let backgroundDark   = Color.adaptive(light: "FAFCFB", dark: "080B0A")
    static let backgroundMedium = Color.adaptive(light: "F0F4F1", dark: "0F1511")
    static let surface1         = Color.adaptive(light: "F0F4F1", dark: "0F1511")
    static let surface2         = Color.adaptive(light: "FFFFFF", dark: "161D18")
    static let surface3         = Color.adaptive(light: "FFFFFF", dark: "1E2920")
    static let cardBackground   = Color.adaptive(light: "FFFFFF", dark: "161D18")
    static let greenTint        = Color.adaptive(light: "E8F5E9", dark: "0A1F12")

    // Border
    static let border = Color.adaptive(light: "D4E0D6", dark: "2A3B2E")

    // Text tokens — adaptive
    static let textPrimary   = Color.adaptive(light: "1A2E1E", dark: "F0FAF2")
    static let textSecondary = Color.adaptive(light: "5A7A5E", dark: "8BA98E")
    static let textTertiary  = Color.adaptive(light: "8BA98E", dark: "4D6651")

    // Gradients — dark mode
    static let backgroundGradientDark = LinearGradient(
        colors: [Color(hex: "080B0A"), Color(hex: "0A1F12"), Color(hex: "080B0A")],
        startPoint: .top,
        endPoint: .bottom
    )

    // Gradients — light mode
    static let backgroundGradientLight = LinearGradient(
        colors: [Color(hex: "FAFCFB"), Color(hex: "E8F5E9"), Color(hex: "FAFCFB")],
        startPoint: .top,
        endPoint: .bottom
    )

    // Semantic colors (same in both modes — sufficient contrast on light and dark)
    static let success = Color(hex: "16C784")
    static let warning = Color(hex: "F59E0B")
    static let error   = Color(hex: "EF4444")
    static let info    = Color(hex: "3B82F6")

    // Shadow colors — adaptive (lighter shadows on light backgrounds)
    static let cardShadowColor     = Color.adaptive(light: "000000", dark: "000000")
    static let elevatedShadowColor = Color.adaptive(light: "000000", dark: "000000")

    // Glass shimmer — adaptive
    static let glassShimmer  = Color.adaptive(light: "000000", dark: "FFFFFF")
    static let glassBorder   = Color.adaptive(light: "000000", dark: "FFFFFF")
}

// MARK: - Color Hex Extension

extension UIColor {
    convenience init(hex: String) {
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
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

extension Color {
    init(hex: String) {
        self.init(uiColor: UIColor(hex: hex))
    }

    /// Creates an adaptive color that automatically switches between light and dark variants
    static func adaptive(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

// MARK: - Themed Background

/// Reusable themed background with drifting glow orbs — adapts to light/dark mode
struct ThemedBackground: View {
    var showGlow: Bool = true
    var glowIntensity: Double = 0.20

    @Environment(\.colorScheme) private var colorScheme
    @State private var driftX: CGFloat = 0
    @State private var driftY: CGFloat = 0

    private var gradient: LinearGradient {
        colorScheme == .dark ? AppTheme.backgroundGradientDark : AppTheme.backgroundGradientLight
    }

    private var effectiveGlow: Double {
        colorScheme == .dark ? glowIntensity : glowIntensity * 0.4
    }

    var body: some View {
        ZStack {
            gradient
                .ignoresSafeArea()

            if showGlow {
                Circle()
                    .fill(AppTheme.primary.opacity(effectiveGlow))
                    .blur(radius: 120)
                    .frame(width: 300, height: 300)
                    .offset(x: 150 + driftX, y: -200 + driftY)

                Circle()
                    .fill(AppTheme.primary.opacity(effectiveGlow * 0.5))
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

/// Animated gradient for auth / landing screens — adapts to light/dark mode
struct AnimatedGradientBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var animateGradient = false

    private var gradientColors: [Color] {
        colorScheme == .dark
            ? [Color(hex: "080B0A"), Color(hex: "0A1F12"), Color(hex: "080B0A"), Color(hex: "0D1A10")]
            : [Color(hex: "FAFCFB"), Color(hex: "E8F5E9"), Color(hex: "FAFCFB"), Color(hex: "EFF7F0")]
    }

    var body: some View {
        LinearGradient(
            colors: gradientColors,
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

    @Environment(\.colorScheme) private var colorScheme

    init(cornerRadius: CGFloat = 20, @ViewBuilder content: @escaping () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content
    }

    var body: some View {
        content()
            .padding()
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(AppTheme.surface2.opacity(colorScheme == .dark ? 0.92 : 0.95))
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppTheme.glassShimmer.opacity(colorScheme == .dark ? 0.06 : 0.03),
                                    Color.clear
                                ],
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
                            colors: [
                                AppTheme.glassBorder.opacity(colorScheme == .dark ? 0.10 : 0.06),
                                AppTheme.glassBorder.opacity(colorScheme == .dark ? 0.03 : 0.02)
                            ],
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

// MARK: - Motion Tokens

/// Centralized animation tokens — use these instead of inline spring values
enum MotionTokens {
    /// Standard interaction (card reveal, value change) — 0.45s, 0.82 damping
    static let primary   = Animation.spring(response: 0.45, dampingFraction: 0.82)
    /// Button press, micro-interactions — 0.25s, 0.70 damping
    static let snappy    = Animation.spring(response: 0.25, dampingFraction: 0.70)
    /// Toast pop, icon spin — 0.40s, 0.60 damping
    static let micro     = Animation.spring(response: 0.40, dampingFraction: 0.60)
    /// Form fields, toggles — 0.35s, 0.85 damping
    static let form      = Animation.spring(response: 0.35, dampingFraction: 0.85)
    /// View entrance, staggered reveals — 0.50s, 0.78 damping
    static let entrance  = Animation.spring(response: 0.50, dampingFraction: 0.78)
    /// Progress ring fill — 0.80s, 0.75 damping
    static let ring      = Animation.spring(response: 0.80, dampingFraction: 0.75)
}

// MARK: - Press Effect Button Style

/// Subtle scale-down press effect for all primary buttons
struct PressEffect: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(MotionTokens.snappy, value: configuration.isPressed)
    }
}

// MARK: - Card Shadow Modifier

private struct CardShadowModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    func body(content: Content) -> some View {
        content.shadow(
            color: .black.opacity(colorScheme == .dark ? 0.20 : 0.08),
            radius: colorScheme == .dark ? 12 : 8,
            y: colorScheme == .dark ? 4 : 2
        )
    }
}

private struct ElevatedShadowModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    func body(content: Content) -> some View {
        content.shadow(
            color: .black.opacity(colorScheme == .dark ? 0.35 : 0.15),
            radius: colorScheme == .dark ? 20 : 12,
            y: colorScheme == .dark ? 8 : 4
        )
    }
}

extension View {
    /// Level 1 shadow — base cards (adapts to light/dark)
    func cardShadow() -> some View {
        modifier(CardShadowModifier())
    }

    /// Level 2 shadow — elevated cards (adapts to light/dark)
    func elevatedShadow() -> some View {
        modifier(ElevatedShadowModifier())
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
                withAnimation(MotionTokens.micro) {
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
        withAnimation(MotionTokens.micro) {
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
        .animation(MotionTokens.micro, value: manager.isShowing)
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
                withAnimation(MotionTokens.primary) {
                    animatedValue = value
                }
            }
            .onChange(of: value) { _, newValue in
                withAnimation(MotionTokens.form) {
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
            withAnimation(MotionTokens.ring) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(MotionTokens.primary) {
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
        animation: Animation = MotionTokens.primary
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

// MARK: - Custom Tab Bar

/// Animated tab bar with spring bounce on icon selection
struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    @Environment(\.colorScheme) private var colorScheme

    private let tabs: [(tab: AppTab, icon: String, label: String)] = [
        (.dashboard, "square.grid.2x2.fill", "Dashboard"),
        (.nutrition, "fork.knife", "Nutrition"),
        (.workout, "figure.run", "Workout"),
        (.sleep, "moon.zzz.fill", "Sleep"),
        (.profile, "person.fill", "Profile"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.tab) { item in
                Button {
                    HapticsManager.shared.selection()
                    selectedTab = item.tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.system(size: 20))
                            .symbolEffect(.bounce, value: selectedTab == item.tab)

                        Text(item.label)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(selectedTab == item.tab ? AppTheme.primary : AppTheme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 2)
        .background {
            ZStack {
                Rectangle()
                    .fill(colorScheme == .dark ? AppTheme.surface2.opacity(0.95) : Color.white.opacity(0.97))
                Rectangle()
                    .fill(.ultraThinMaterial)
                // Top border
                VStack { Divider().foregroundStyle(AppTheme.border); Spacer() }
            }
            .ignoresSafeArea(edges: .bottom)
        }
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
