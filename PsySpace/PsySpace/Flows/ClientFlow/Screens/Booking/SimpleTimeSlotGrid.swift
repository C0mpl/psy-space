//
//  SimpleTimeSlotGrid.swift
//  PsySpace
//
//  Created by Claude on 27.09.2026.
//

import SwiftUI

struct SimpleTimeSlotGrid: View {
    let slots: [TimeSlot]
    let selectedSlotId: String?
    let selectedDate: Date
    let reduceMotion: Bool
    let onSelect: (TimeSlot) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.sm), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            header
            slotsGrid
        }
    }

    private var header: some View {
        HStack {
            Text("Доступний час")
                .font(.headline)
                .foregroundStyle(Color.psyspaceTextPrimary)

            Spacer()

            Text(formattedDate)
                .font(.caption)
                .foregroundStyle(Color.psyspaceTextSecondary)
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: selectedDate)
    }

    private var slotsGrid: some View {
        LazyVGrid(columns: columns, spacing: Spacing.sm) {
            ForEach(slots) { slot in
                TimeSlotPillButton(
                    time: slot.startTimeFormatted,
                    isSelected: selectedSlotId == slot.id,
                    reduceMotion: reduceMotion
                ) {
                    onSelect(slot)
                }
            }
        }
    }
}

// MARK: - Pill Button

struct TimeSlotPillButton: View {
    let time: String
    let isSelected: Bool
    let reduceMotion: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(time)
                .font(.subheadline.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.psyspaceTextPrimary : Color.psyspaceTextPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(background)
                .clipShape(Capsule())
                .overlay(border)
        }
        .buttonStyle(TimeSlotPillButtonStyle(reduceMotion: reduceMotion))
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            Color.psyspacePrimary.opacity(0.1)
        } else {
            Color.psyspaceCardBackground
        }
    }

    @ViewBuilder
    private var border: some View {
        if isSelected {
            Capsule()
                .stroke(Color.psyspacePrimary, lineWidth: 1)
        } else {
            Capsule()
                .stroke(Color.psyspaceTextSecondary.opacity(0.2), lineWidth: 1)
        }
    }
}

struct TimeSlotPillButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1.0)
            .animation(reduceMotion ? nil : PsySpaceAnimation.quick, value: configuration.isPressed)
            .shadow(
                color: Color.psyspaceTextPrimary.opacity(configuration.isPressed ? 0 : 0.04),
                radius: 4,
                y: 2
            )
            .onChange(of: configuration.isPressed) { wasPressed, isPressed in
                if wasPressed && !isPressed && !reduceMotion {
                    HapticService.selection()
                }
            }
    }
}

#Preview {
    let slots = [
        TimeSlot(id: "1", date: .now, startTime: .now, endTime: .now, isBooked: false),
        TimeSlot(id: "2", date: .now, startTime: .now, endTime: .now, isBooked: false),
        TimeSlot(id: "3", date: .now, startTime: .now, endTime: .now, isBooked: false),
        TimeSlot(id: "4", date: .now, startTime: .now, endTime: .now, isBooked: false),
        TimeSlot(id: "5", date: .now, startTime: .now, endTime: .now, isBooked: false),
        TimeSlot(id: "6", date: .now, startTime: .now, endTime: .now, isBooked: false)
    ]

    SimpleTimeSlotGrid(
        slots: slots,
        selectedSlotId: "1",
        selectedDate: .now,
        reduceMotion: false
    ) { _ in }
    .padding()
    .background(Color.psyspaceBackground)
}
