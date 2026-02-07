//
//  InputField.swift
//  ANAJ
//
//  Standardized Text Input
//

import SwiftUI

struct InputField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundStyle(AppColors.textTertiary)
                    .font(.system(size: 12))
            }
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(AppFonts.body())
                .foregroundStyle(AppColors.textPrimary)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.bgPrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.borderSubtle, lineWidth: 1)
        )
    }
}

struct SearchField: View {
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.textTertiary)
            
            TextField("Search...", text: $text)
                .textFieldStyle(.plain)
                .font(AppFonts.code())
                .foregroundStyle(AppColors.textPrimary)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.bgPrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }
}
