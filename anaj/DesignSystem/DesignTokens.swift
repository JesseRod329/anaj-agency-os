//
//  DesignTokens.swift
//  ANAJ
//
//  Centralized Design Tokens
//

import SwiftUI

enum AppColors {
    // Backgrounds
    static let bgPrimary = Color.black.opacity(0.2)
    static let bgSecondary = Color.black.opacity(0.1)
    static let surface = Color.white.opacity(0.05)
    static let surfaceHighlight = Color.white.opacity(0.1)
    static let surfaceStrong = Color.white.opacity(0.15)
    
    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.5)
    static let textQuaternary = Color.white.opacity(0.3)
    
    // Accents
    static let accentBlue = Color.blue
    static let accentGreen = Color.green
    static let accentOrange = Color.orange
    static let accentRed = Color.red
    static let accentYellow = Color.yellow
    
    // Borders
    static let borderSubtle = Color.white.opacity(0.1)
    static let borderStrong = Color.white.opacity(0.2)
}

enum AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let section: CGFloat = 32
}

enum AppRadius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
    static let xxl: CGFloat = 24
}

enum AppFonts {
    static func display(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    
    static func title(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }
    
    static func titleRounded(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
    
    static func body(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
    
    static func caption(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }
    
    static func code(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }
}
