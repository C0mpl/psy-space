//
//  Design.swift
//  Seans
//
//  Created by Claude on 23.08.2026.
//

import SwiftUI

// MARK: - Colors

extension Color {
    /// Primary brand color - warm amber/honey
    static let seansPrimary = Color(red: 0.85, green: 0.65, blue: 0.40)

    /// Secondary - soft sage for balance
    static let seansSecondary = Color(red: 0.55, green: 0.65, blue: 0.55)

    /// Accent - deeper terracotta for emphasis
    static let seansAccent = Color(red: 0.78, green: 0.50, blue: 0.40)

    /// Soft highlight - peachy cream
    static let seansHighlight = Color(red: 0.95, green: 0.85, blue: 0.75)

    /// Background - warm cream (light) / warm charcoal (dark)
    static let seansBackground = Color(light: .init(red: 0.99, green: 0.97, blue: 0.94),
                                        dark: .init(red: 0.12, green: 0.11, blue: 0.10))

    /// Background warm - subtle peachy tint
    static let seansBackgroundWarm = Color(light: .init(red: 1.0, green: 0.96, blue: 0.92),
                                            dark: .init(red: 0.15, green: 0.12, blue: 0.10))

    /// Card background - slightly elevated surface
    static let seansCardBackground = Color(light: .white,
                                            dark: .init(red: 0.18, green: 0.16, blue: 0.14))

    /// Text colors
    static let seansTextPrimary = Color(light: .init(red: 0.20, green: 0.18, blue: 0.15),
                                         dark: .init(red: 0.95, green: 0.93, blue: 0.90))
    static let seansTextSecondary = Color(light: .init(red: 0.50, green: 0.45, blue: 0.40),
                                           dark: .init(red: 0.70, green: 0.65, blue: 0.60))

    /// Decorative - muted warm tones for shapes
    static let seansDecorative1 = Color(red: 0.92, green: 0.82, blue: 0.70).opacity(0.6)
    static let seansDecorative2 = Color(red: 0.85, green: 0.75, blue: 0.65).opacity(0.4)
    static let seansDecorative3 = Color(red: 0.78, green: 0.68, blue: 0.58).opacity(0.3)
}

extension Color {
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

// MARK: - Spacing

enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius

enum CornerRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

// MARK: - Animation

enum SeansAnimation {
    static let quick: Animation = .easeOut(duration: 0.2)
    static let standard: Animation = .easeInOut(duration: 0.3)
    static let gentle: Animation = .easeInOut(duration: 0.5)
}
