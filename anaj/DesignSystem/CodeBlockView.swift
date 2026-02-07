//
//  CodeBlockView.swift
//  ANAJ
//
//  Reusable Code Block Component
//

import SwiftUI

struct CodeBlockView: View {
    let language: String
    let code: String
    @State private var isCopied = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(language.isEmpty ? "CODE" : language.uppercased())
                    .font(AppFonts.code(10).weight(.bold))
                    .foregroundStyle(AppColors.textTertiary)
                
                Spacer()
                
                Button(action: copyToClipboard) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        Text(isCopied ? "Copied" : "Copy")
                    }
                    .font(AppFonts.caption(10))
                    .foregroundStyle(isCopied ? AppColors.accentGreen : AppColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.bgPrimary)
            
            Divider().overlay(AppColors.borderSubtle)
            
            // Code Content
            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(AppFonts.code(13))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(AppSpacing.md)
                    .textSelection(.enabled)
            }
        }
        .background(AppColors.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.borderSubtle, lineWidth: 1)
        )
    }
    
    private func copyToClipboard() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        #else
        UIPasteboard.general.string = code
        #endif
        
        withAnimation { isCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCopied = false
        }
    }
}
