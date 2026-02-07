//
//  EmptyStateView.swift
//  ANAJ
//
//  Unified Empty State Component
//

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String?
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(AppColors.textQuaternary)
            
            VStack(spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppFonts.title())
                    .foregroundStyle(AppColors.textSecondary)
                
                if let message = message {
                    Text(message)
                        .font(AppFonts.body())
                        .foregroundStyle(AppColors.textTertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(AppFonts.body().weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.xl)
                        .padding(.vertical, AppSpacing.sm)
                        .background(AppColors.accentBlue.opacity(0.8))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, AppSpacing.sm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.xl)
    }
}
