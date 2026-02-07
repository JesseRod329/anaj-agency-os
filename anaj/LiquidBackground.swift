//
//  LiquidBackground.swift
//  ANAJ
//
//  Created by Assistant on 12/21/25.
//

import SwiftUI
import Foundation

enum BackgroundStyle: String, CaseIterable, Identifiable {
    case classic = "Classic"
    case ocean = "Ocean"
    case sunset = "Sunset"
    case midnight = "Midnight"
    case aurora = "Aurora"
    case forest = "Forest"
    
    var id: String { rawValue }
    
    func colors(for theme: String) -> [Color] {
        let isLight = theme == "Light"
        switch self {
        case .classic:
            return isLight 
                ? [.cyan, .blue, .purple, .pink, .indigo, .mint]
                : [.cyan.opacity(0.9), .blue.opacity(0.8), .purple.opacity(0.9), .pink.opacity(0.8), .indigo.opacity(0.8), .mint.opacity(0.8)]
        case .ocean:
            return isLight
                ? [.blue, .teal, .cyan, .blue, .indigo, .teal]
                : [.blue, .teal, .cyan, .blue.opacity(0.6), .indigo, .teal.opacity(0.8)]
        case .sunset:
            return isLight
                ? [.orange, .pink, .purple, .red, .orange, .yellow]
                : [.orange, .pink, .purple, .red.opacity(0.8), .orange.opacity(0.7), .yellow.opacity(0.8)]
        case .midnight:
            return isLight
                ? [.gray, .indigo, .blue, .gray, .purple, .black]
                : [.black, .indigo.opacity(0.6), .blue.opacity(0.4), .black, .purple.opacity(0.3), .black]
        case .aurora:
            return isLight
                ? [.green, .teal, .indigo, .purple, .green, .blue]
                : [.green.opacity(0.7), .teal, .indigo, .purple, .green.opacity(0.5), .blue]
        case .forest:
            return isLight
                ? [.green, .mint, .yellow, .brown, .green, .teal]
                : [.green.opacity(0.4), .mint.opacity(0.5), .brown.opacity(0.6), .green.opacity(0.3), .black, .teal.opacity(0.4)]
        }
    }
}

struct LiquidBackground: View {
    @AppStorage("backgroundStyle") private var style: BackgroundStyle = .classic
    @AppStorage("appTheme") private var appTheme = "Dark"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // Platform-specific update interval for performance
    #if os(iOS)
    private let updateInterval: TimeInterval = 0.15  // ~7 FPS on iOS for battery
    #else
    private let updateInterval: TimeInterval = 0.05  // ~20 FPS on macOS
    #endif
    
    var body: some View {
        if reduceMotion {
            // Static background for accessibility
            staticBackground
        } else {
            // Animated background with optimized update rate
            TimelineView(.periodic(from: .now, by: updateInterval)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate / 8.0
                animatedBackground(time: time)
            }
        }
    }
    
    // MARK: - Static Background (Reduced Motion)
    @ViewBuilder
    private var staticBackground: some View {
        if #available(macOS 15.0, iOS 18.0, *) {
            MeshGradient(
                width: 3,
                height: 3,
                points: staticPoints,
                colors: style.colors(for: appTheme),
                background: appTheme == "Light" ? .white : .black
            )
            .ignoresSafeArea()
        } else {
            staticFallbackGradient
        }
    }
    
    // MARK: - Animated Background
    @ViewBuilder
    private func animatedBackground(time: Double) -> some View {
        if #available(macOS 15.0, iOS 18.0, *) {
            MeshGradient(
                width: 3,
                height: 3,
                points: animatedPoints(t: time),
                colors: style.colors(for: appTheme),
                background: appTheme == "Light" ? .white : .black
            )
            .id("\(style.rawValue)-\(appTheme)")
            .ignoresSafeArea()
        } else {
            fallbackBackground(time: time)
        }
    }
    
    // MARK: - Fallback for older OS (No blur for performance)
    @ViewBuilder
    private func fallbackBackground(time: Double) -> some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.2, blue: 0.4),
                    Color(red: 0.2, green: 0.1, blue: 0.3),
                    Color(red: 0.0, green: 0.3, blue: 0.4),
                    Color(red: 0.3, green: 0.1, blue: 0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            #if os(macOS)
            // macOS can handle more visual effects
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.cyan.opacity(0.4), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .offset(x: cos(time) * 50, y: sin(time) * 50)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.purple.opacity(0.35), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 125
                    )
                )
                .frame(width: 250, height: 250)
                .offset(x: sin(time * 0.7) * 60 + 100, y: cos(time * 0.7) * 60 + 150)
            #else
            // iOS: Simpler, lighter effects (no blur, fewer elements)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.cyan.opacity(0.3), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .offset(x: cos(time) * 30, y: sin(time) * 30)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.purple.opacity(0.25), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .offset(x: sin(time * 0.7) * 40 + 80, y: cos(time * 0.7) * 40 + 120)
            #endif
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Static Fallback Gradient
    private var staticFallbackGradient: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.2, blue: 0.4),
                    Color(red: 0.2, green: 0.1, blue: 0.3),
                    Color(red: 0.0, green: 0.3, blue: 0.4),
                    Color(red: 0.3, green: 0.1, blue: 0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.cyan.opacity(0.3), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .offset(x: 50, y: -100)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.purple.opacity(0.25), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .offset(x: -60, y: 150)
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Point Calculations
    
    // Static points for reduced motion
    private var staticPoints: [SIMD2<Float>] {
        [
            SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
            SIMD2(0.0, 0.5), SIMD2(0.5, 0.5), SIMD2(1.0, 0.5),
            SIMD2(0.0, 1.0), SIMD2(0.5, 1.0), SIMD2(1.0, 1.0)
        ]
    }
    
    // Animated points with subtle movement
    private func animatedPoints(t: Double) -> [SIMD2<Float>] {
        #if os(iOS)
        // Smaller movement on iOS for smoother appearance at lower FPS
        let amplitude: Float = 0.04
        #else
        let amplitude: Float = 0.06
        #endif
        
        func p(_ x: Float, _ y: Float, _ r: Float, _ s: Float) -> SIMD2<Float> {
            let tt = Float(t)
            return .init(
                x + cos(tt * s + r) * amplitude,
                y + sin(tt * s + r) * amplitude
            )
        }
        
        return [
            p(0.0, 0.0, 0.0, 0.9), p(0.5, 0.0, 1.2, 1.0), p(1.0, 0.0, 2.0, 1.1),
            p(0.0, 0.5, 0.8, 1.0), p(0.5, 0.5, 1.8, 1.2), p(1.0, 0.5, 2.6, 0.9),
            p(0.0, 1.0, 1.4, 1.1), p(0.5, 1.0, 2.2, 0.95), p(1.0, 1.0, 3.0, 1.05)
        ]
    }
}

#Preview {
    LiquidBackground()
}
