//
//  DashboardSkeletonView.swift
//  HealthPulse
//
//  Shimmer loading skeleton shown while dashboard data loads.
//

import SwiftUI

struct DashboardSkeletonView: View {
    @State private var shimmer = false

    var body: some View {
        VStack(spacing: 20) {
            // Greeting placeholder
            SkeletonRect(width: 200, height: 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            // Readiness header placeholder
            SkeletonRect(height: 80)
                .padding(.horizontal)

            // Commitment strip placeholder
            HStack(spacing: 12) {
                SkeletonRect(height: 64)
                SkeletonRect(height: 64)
                SkeletonRect(height: 64)
            }
            .padding(.horizontal)

            // Workout card placeholder
            SkeletonRect(height: 100)
                .padding(.horizontal)

            // Nutrition card placeholder
            SkeletonRect(height: 140)
                .padding(.horizontal)

            // Last workout placeholder
            SkeletonRect(height: 90)
                .padding(.horizontal)

            // Sleep placeholder
            SkeletonRect(height: 80)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.top)
        .onAppear { shimmer = true }
        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: shimmer)
        .opacity(shimmer ? 0.6 : 0.3)
    }
}

struct SkeletonRect: View {
    var width: CGFloat? = nil
    var height: CGFloat = 60

    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(AppTheme.surface2)
            .frame(width: width, height: height)
    }
}
