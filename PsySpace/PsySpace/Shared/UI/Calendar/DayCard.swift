//
//  DayCard.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 23.08.2026.
//

import SwiftUI

struct DayCard: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isAvailable: Bool
    let showMonth: Bool
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let calendar = Calendar.current

    private var dayNumber: String {
        "\(calendar.component(.day, from: date))"
    }

    private var weekdayShort: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.dateFormat = "EE"
        return formatter.string(from: date).uppercased()
    }

    private var monthShort: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.dateFormat = "MMM"
        return formatter.string(from: date).uppercased()
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Spacing.xxs) {
                if showMonth {
                    Text(monthShort)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : Color.psyspacePrimary)
                } else {
                    Text(weekdayShort)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : Color.psyspaceTextSecondary)
                }

                Text(dayNumber)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(textColor)

                availabilityIndicator
            }
            .frame(width: 56, height: 76)
            .background(backgroundView)
            .clipShape(.rect(cornerRadius: CornerRadius.md))
            .overlay(borderOverlay)
            .scaleEffect(isSelected && !reduceMotion ? 1.05 : 1.0)
            .animation(reduceMotion ? nil : PsySpaceAnimation.quick, value: isSelected)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var availabilityIndicator: some View {
        if isAvailable && !isSelected {
            Circle()
                .fill(Color.psyspaceSecondary)
                .frame(width: 6, height: 6)
        } else if isSelected && isAvailable {
            Circle()
                .fill(Color.white.opacity(0.6))
                .frame(width: 6, height: 6)
        } else {
            Circle()
                .fill(Color.clear)
                .frame(width: 6, height: 6)
        }
    }

    private var textColor: Color {
        if isSelected {
            return .white
        } else if !isAvailable {
            return Color.psyspaceTextSecondary.opacity(0.5)
        } else {
            return Color.psyspaceTextPrimary
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        if isSelected {
            LinearGradient(
                colors: [Color.psyspacePrimary, Color.psyspaceAccent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isToday {
            Color.psyspaceHighlight.opacity(0.5)
        } else {
            Color.psyspaceBackground
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        if isToday && !isSelected {
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(Color.psyspacePrimary, lineWidth: 2)
        }
    }
}
