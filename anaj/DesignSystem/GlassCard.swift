//
//  GlassCard.swift
//  ANAJ
//
//  Reusable Glassmorphism Card Component
//

import SwiftUI

struct GlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let padding: CGFloat
    let content: Content
    
    init(
        cornerRadius: CGFloat = AppRadius.lg,
        padding: CGFloat = AppSpacing.md,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppColors.borderSubtle, lineWidth: 1)
            )
    }
}

extension View {
    func glassCardStyle(cornerRadius: CGFloat = AppRadius.lg, padding: CGFloat = AppSpacing.md) -> some View {
        GlassCard(cornerRadius: cornerRadius, padding: padding) {
            self
        }
    }
}
