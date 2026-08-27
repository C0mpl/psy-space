//
//  Design.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 23.08.2026.
//

import SwiftUI

extension Color {
    static let seansPrimary = Color(red: 0.85, green: 0.65, blue: 0.40)

    static let seansSecondary = Color(red: 0.55, green: 0.65, blue: 0.55)

    static let seansAccent = Color(red: 0.78, green: 0.50, blue: 0.40)

    static let seansHighlight = Color(red: 0.95, green: 0.85, blue: 0.75)

    static let seansBackground = Color(light: .init(red: 0.99, green: 0.97, blue: 0.94),
                                        dark: .init(red: 0.12, green: 0.11, blue: 0.10))

    static let seansBackgroundWarm = Color(light: .init(red: 1.0, green: 0.96, blue: 0.92),
                                            dark: .init(red: 0.15, green: 0.12, blue: 0.10))

    static let seansCardBackground = Color(light: .white,
                                            dark: .init(red: 0.18, green: 0.16, blue: 0.14))

    static let seansTextPrimary = Color(light: .init(red: 0.20, green: 0.18, blue: 0.15),
                                         dark: .init(red: 0.95, green: 0.93, blue: 0.90))
    static let seansTextSecondary = Color(light: .init(red: 0.50, green: 0.45, blue: 0.40),
                                           dark: .init(red: 0.70, green: 0.65, blue: 0.60))

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

enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum CornerRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

enum SeansAnimation {
    static let quick: Animation = .easeOut(duration: 0.2)
    static let standard: Animation = .easeInOut(duration: 0.3)
    static let gentle: Animation = .easeInOut(duration: 0.5)
}

extension Color {
    static let seansSuccess = Color(light: .init(red: 0.30, green: 0.65, blue: 0.45),
                                     dark: .init(red: 0.40, green: 0.75, blue: 0.55))

    static let seansWarning = Color(light: .init(red: 0.85, green: 0.60, blue: 0.25),
                                     dark: .init(red: 0.90, green: 0.70, blue: 0.35))

    static let seansError = Color(light: .init(red: 0.80, green: 0.35, blue: 0.35),
                                   dark: .init(red: 0.90, green: 0.45, blue: 0.45))
}

enum Elevation {
    case none
    case low
    case medium
    case high
}

extension View {
    @ViewBuilder
    func elevation(_ level: Elevation) -> some View {
        switch level {
        case .none:
            self
        case .low:
            self.shadow(color: Color.seansTextPrimary.opacity(0.04), radius: 4, y: 2)
        case .medium:
            self.shadow(color: Color.seansTextPrimary.opacity(0.08), radius: 8, y: 4)
        case .high:
            self.shadow(color: Color.seansTextPrimary.opacity(0.12), radius: 16, y: 8)
        }
    }
}

struct SeansCardModifier: ViewModifier {
    var elevation: Elevation = .low
    var isInteractive: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .padding(Spacing.md)
            .background(Color.seansCardBackground)
            .clipShape(.rect(cornerRadius: CornerRadius.md))
            .elevation(elevation)
            .scaleEffect(isInteractive && isPressed && !reduceMotion ? 0.98 : 1.0)
            .animation(reduceMotion ? nil : SeansAnimation.quick, value: isPressed)
            .simultaneousGesture(
                isInteractive ?
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
                : nil
            )
    }
}

extension View {
    func seansCard(elevation: Elevation = .low, interactive: Bool = false) -> some View {
        modifier(SeansCardModifier(elevation: elevation, isInteractive: interactive))
    }
}

struct SeansPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var isLoading: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Spacing.sm) {
            if isLoading {
                ProgressView()
                    .tint(.white)
            }
            configuration.label
        }
        .font(.headline)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(
            LinearGradient(
                colors: [Color.seansPrimary, Color.seansAccent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: CornerRadius.md))
        .elevation(.medium)
        .opacity(isEnabled && !isLoading ? 1 : 0.6)
        .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1.0)
        .animation(reduceMotion ? nil : SeansAnimation.quick, value: configuration.isPressed)
        .onChange(of: configuration.isPressed) { wasPressed, isPressed in
            if wasPressed && !isPressed && !reduceMotion {
                HapticService.impact(.light)
            }
        }
    }
}

struct SeansSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var isLoading: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Spacing.sm) {
            if isLoading {
                ProgressView()
                    .tint(Color.seansTextPrimary)
            }
            configuration.label
        }
        .font(.headline)
        .foregroundStyle(Color.seansTextPrimary)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(Color.seansCardBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(Color.seansTextSecondary.opacity(0.2), lineWidth: 1)
        )
        .elevation(.low)
        .opacity(isEnabled && !isLoading ? 1 : 0.6)
        .scaleEffect(configuration.isPressed && !reduceMotion ? 0.99 : 1.0)
        .opacity(configuration.isPressed ? 0.85 : 1.0)
        .animation(reduceMotion ? nil : SeansAnimation.quick, value: configuration.isPressed)
        .onChange(of: configuration.isPressed) { wasPressed, isPressed in
            if wasPressed && !isPressed && !reduceMotion {
                HapticService.impact(.light)
            }
        }
    }
}

struct SeansIconButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(Spacing.xs)
            .background(
                Circle()
                    .fill(Color.seansTextPrimary.opacity(configuration.isPressed ? 0.08 : 0))
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1.0)
            .animation(reduceMotion ? nil : SeansAnimation.quick, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { wasPressed, isPressed in
                if wasPressed && !isPressed && !reduceMotion {
                    HapticService.impact(.light)
                }
            }
    }
}

struct SeansDestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var isLoading: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Spacing.sm) {
            if isLoading {
                ProgressView()
                    .tint(.white)
            }
            configuration.label
        }
        .font(.headline)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(Color.seansError)
        .clipShape(.rect(cornerRadius: CornerRadius.md))
        .elevation(.medium)
        .opacity(isEnabled && !isLoading ? 1 : 0.6)
        .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1.0)
        .animation(reduceMotion ? nil : SeansAnimation.quick, value: configuration.isPressed)
        .onChange(of: configuration.isPressed) { wasPressed, isPressed in
            if wasPressed && !isPressed && !reduceMotion {
                HapticService.impact(.light)
            }
        }
    }
}

struct SeansLoadingOverlay: View {
    var message: String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: Spacing.md) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(Color.seansPrimary)

                if let message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(Color.seansTextPrimary)
                }
            }
            .padding(Spacing.lg)
            .background(Color.seansCardBackground)
            .clipShape(.rect(cornerRadius: CornerRadius.lg))
            .elevation(.high)
        }
    }
}

struct SeansSlotButtonStyle: ButtonStyle {
    var isSelected: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isSelected ? .white : Color.seansTextPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(isSelected ? Color.seansPrimary : Color.seansCardBackground)
            .clipShape(.rect(cornerRadius: CornerRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .stroke(Color.seansPrimary.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
            )
            .elevation(isSelected ? .low : .none)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1.0)
            .animation(reduceMotion ? nil : SeansAnimation.quick, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { wasPressed, isPressed in
                if wasPressed && !isPressed && !reduceMotion {
                    HapticService.selection()
                }
            }
    }
}
