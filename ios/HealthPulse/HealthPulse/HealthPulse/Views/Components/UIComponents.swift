//
//  UIComponents.swift
//  HealthPulse
//
//  Reusable UI components for polished experience
//

import SwiftUI
import UIKit
import Combine

// MARK: - App Theme

/// Central theme configuration based on the HealthPulse logo colors
struct AppTheme {
    // Brand colors from logo
    static let primary = Color(hex: "4ADE80")           // Mint green
    static let primaryDark = Color(hex: "22C55E")       // Darker green
    static let primaryLight = Color(hex: "86EFAC")      // Lighter green

    // Background colors
    static let backgroundDark = Color(hex: "0A0A0A")    // Near black
    static let backgroundMedium = Color(hex: "121212")  // Slightly lighter
    static let cardBackground = Color(hex: "1A1A1A")    // Card surfaces
    static let greenTint = Color(hex: "0F1A0F")         // Dark with green tint

    // Gradients
    static let backgroundGradient = LinearGradient(
        colors: [
            Color(hex: "0A0A0A"),
            Color(hex: "0D120D"),
            Color(hex: "0A0A0A")
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    // Semantic colors
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    static let info = Color.blue
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
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

/// A reusable themed background with gradient and optional glow effects
struct ThemedBackground: View {
    var showGlow: Bool = true
    var glowIntensity: Double = 0.15

    var body: some View {
        ZStack {
            // Base gradient
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            // Optional green glow accents
            if showGlow {
                // Top-right glow
                Circle()
                    .fill(AppTheme.primary.opacity(glowIntensity))
                    .blur(radius: 120)
                    .frame(width: 300, height: 300)
                    .offset(x: 150, y: -200)

                // Bottom-left subtle glow
                Circle()
                    .fill(AppTheme.primary.opacity(glowIntensity * 0.5))
                    .blur(radius: 100)
                    .frame(width: 200, height: 200)
                    .offset(x: -150, y: 400)
            }
        }
    }
}

// MARK: - Animated Gradient Background

/// Animated gradient for landing/auth screens
struct AnimatedGradientBackground: View {
    @State private var animateGradient = false

    var body: some View {
        LinearGradient(
            colors: [
                Color(hex: "0A0A0A"),
                Color(hex: "0F1A0F"),
                Color(hex: "0A0A0A"),
                Color(hex: "0D150D")
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
    /// Applies the themed background behind the view
    func themedBackground(showGlow: Bool = true) -> some View {
        ZStack {
            ThemedBackground(showGlow: showGlow)
            self
        }
    }
}

// MARK: - Glassmorphism Card

struct GlassCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

// MARK: - Haptics Manager

class HapticsManager {
    static let shared = HapticsManager()
    private init() {}

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()

    func prepare() {
        lightImpact.prepare()
        mediumImpact.prepare()
        selectionFeedback.prepare()
    }

    func light() {
        lightImpact.impactOccurred()
    }

    func medium() {
        mediumImpact.impactOccurred()
    }

    func heavy() {
        heavyImpact.impactOccurred()
    }

    func selection() {
        selectionFeedback.selectionChanged()
    }

    func success() {
        notificationFeedback.notificationOccurred(.success)
    }

    func warning() {
        notificationFeedback.notificationOccurred(.warning)
    }

    func error() {
        notificationFeedback.notificationOccurred(.error)
    }
}

// MARK: - Skeleton View

struct SkeletonView: View {
    @State private var isAnimating = false

    var body: some View {
        LinearGradient(
            colors: [
                Color(.systemGray5),
                Color(.systemGray4),
                Color(.systemGray5)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .mask(Rectangle())
        .offset(x: isAnimating ? 200 : -200)
        .animation(
            .linear(duration: 1.5)
            .repeatForever(autoreverses: false),
            value: isAnimating
        )
        .onAppear {
            isAnimating = true
        }
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
            .fill(Color(.systemGray5))
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
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

// MARK: - Toast View

enum ToastType {
    case success
    case error
    case info
    case warning

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .info: return .blue
        case .warning: return .orange
        }
    }
}

struct ToastView: View {
    let message: String
    let type: ToastType

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .foregroundStyle(type.color)
                .font(.title3)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        .padding(.horizontal)
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
        currentToast = (message, type)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isShowing = true
        }

        // Auto dismiss
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                isShowing = false
            }
        }
    }

    func success(_ message: String) {
        HapticsManager.shared.success()
        show(message, type: .success)
    }

    func error(_ message: String) {
        HapticsManager.shared.error()
        show(message, type: .error)
    }

    func info(_ message: String) {
        show(message, type: .info)
    }

    func warning(_ message: String) {
        HapticsManager.shared.warning()
        show(message, type: .warning)
    }
}

// Toast container for app-wide toasts
struct ToastContainer: View {
    @ObservedObject var manager = ToastManager.shared

    var body: some View {
        VStack {
            if manager.isShowing, let toast = manager.currentToast {
                ToastView(message: toast.message, type: toast.type)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: manager.isShowing)
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
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) {
                    animatedValue = value
                }
            }
            .onChange(of: value) { _, newValue in
                withAnimation(.easeOut(duration: 0.5)) {
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
    var backgroundColor: Color = Color.gray.opacity(0.2)

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
            withAnimation(.easeOut(duration: 1.0)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeOut(duration: 0.5)) {
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
                withAnimation(animation.delay(Double(index) * 0.1)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func staggeredAnimation(index: Int, animation: Animation = .spring(response: 0.5, dampingFraction: 0.8)) -> some View {
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
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
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
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            if let message = message {
                                Text(message)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
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

#Preview("Skeleton") {
    VStack(spacing: 16) {
        SkeletonCard()
        SkeletonCard()
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Toast") {
    VStack {
        ToastView(message: "Workout saved successfully!", type: .success)
        ToastView(message: "Failed to load data", type: .error)
        ToastView(message: "New feature available", type: .info)
        ToastView(message: "Low battery", type: .warning)
    }
    .padding()
}

#Preview("Empty State") {
    EmptyStateView(
        icon: "dumbbell",
        title: "No Workouts Yet",
        message: "Start logging your workouts to see them here",
        actionTitle: "Log Workout",
        action: {}
    )
}
