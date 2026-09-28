//
//  QuickBookCTA.swift
//  PsySpace
//
//  Created by Claude on 27.09.2026.
//

import SwiftUI

struct QuickBookCTA: View {
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Не хочете обирати?")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.7))

                    Text("Найближчий час")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.psyspaceSecondary)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.7))
                    .clipShape(Circle())
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(Color.psyspaceSecondary)
            .clipShape(.rect(cornerRadius: CornerRadius.lg))
            .shadow(
                color: Color.psyspaceSecondary.opacity(0.3),
                radius: 12,
                y: 6
            )
        }
        .buttonStyle(QuickBookButtonStyle(reduceMotion: reduceMotion))
    }
}

private struct QuickBookButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1.0)
            .animation(reduceMotion ? nil : PsySpaceAnimation.quick, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { wasPressed, isPressed in
                if wasPressed && !isPressed && !reduceMotion {
                    HapticService.impact(.light)
                }
            }
    }
}

#Preview {
    QuickBookCTA {}
        .padding()
        .background(Color.psyspaceBackground)
}
