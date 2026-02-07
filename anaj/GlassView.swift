//
//  GlassView.swift
//  ANAJ
//
//  Optimized glass effect using solid colors for M4 performance
//

import SwiftUI

struct GlassView<Content: View>: View {
    let cornerRadius: CGFloat
    let content: () -> Content
    
    @AppStorage("glassOpacity") private var glassOpacity = 0.3

    init(cornerRadius: CGFloat = 16, @ViewBuilder content: @escaping () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(glassOpacity * 0.3)) // Lightweight solid color
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 5) // Reduced shadow
            .overlay(
                content()
                    .padding()
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}

struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    @AppStorage("glassOpacity") private var glassOpacity = 0.3
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(glassOpacity * 0.3)) // Lightweight solid color
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 5) // Reduced shadow
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
        GlassView {
            VStack(alignment: .leading, spacing: 8) {
                Text("GlassView Preview")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Optimized solid colors, reduced shadow")
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(width: 420, height: 180)
    }
}
