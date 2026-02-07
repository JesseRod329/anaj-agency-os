//
//  ActionButton.swift
//  ANAJ
//
//  Standardized Action Button
//

import SwiftUI

struct ActionButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isProminent: Bool = false
    var isDisabled: Bool = false
    
    @State private var isHovered = false
    
    init(_ title: String, icon: String? = nil, isProminent: Bool = false, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isProminent = isProminent
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(AppFonts.caption())
            .foregroundStyle(isDisabled ? AppColors.textTertiary : (isProminent ? .white : AppColors.textSecondary))
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(isProminent ? Color.clear : AppColors.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { isHovered = $0 }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        if isDisabled {
            AppColors.surface
        } else if isProminent {
            AppColors.accentBlue.opacity(isHovered ? 0.8 : 1.0)
        } else {
            isHovered ? AppColors.surfaceHighlight : AppColors.surface
        }
    }
}

struct IconButton: View {
    let icon: String
    let action: () -> Void
    var tooltip: String? = nil
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(isHovered ? AppColors.textPrimary : AppColors.textSecondary)
                .padding(AppSpacing.sm)
                .background(isHovered ? AppColors.surfaceHighlight : Color.clear)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .if(tooltip != nil) { view in
            view.help(tooltip!)
        }
    }
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
