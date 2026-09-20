//
//  TimeSlotGrid.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 23.08.2026.
//

import SwiftUI

struct TimeSlotGrid: View {
    let slots: [TimeSlot]
    let selectedSlotId: String?
    let reduceMotion: Bool
    let onSelect: (TimeSlot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ForEach(groupedSlots, id: \.period) { group in
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: group.period.icon)
                            .font(.caption)
                            .foregroundStyle(Color.psyspaceTextSecondary)

                        Text(group.period.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.psyspaceTextSecondary)
                    }

                    LazyVGrid(columns: AdaptiveGridConfig.timeSlots.columns, spacing: AdaptiveGridConfig.timeSlots.spacing) {
                        ForEach(group.slots) { slot in
                            Button {
                                withAnimation(reduceMotion ? nil : PsySpaceAnimation.quick) {
                                    onSelect(slot)
                                }
                            } label: {
                                Text(slot.startTimeFormatted)
                            }
                            .buttonStyle(PsySpaceSlotButtonStyle(isSelected: selectedSlotId == slot.id))
                        }
                    }
                }
            }
        }
    }

    private var groupedSlots: [SlotGroup] {
        var morning: [TimeSlot] = []
        var afternoon: [TimeSlot] = []
        var evening: [TimeSlot] = []

        for slot in slots {
            let hour = Calendar.current.component(.hour, from: slot.startTime)
            if hour < 12 {
                morning.append(slot)
            } else if hour < 17 {
                afternoon.append(slot)
            } else {
                evening.append(slot)
            }
        }

        var groups: [SlotGroup] = []
        if !morning.isEmpty { groups.append(SlotGroup(period: .morning, slots: morning)) }
        if !afternoon.isEmpty { groups.append(SlotGroup(period: .afternoon, slots: afternoon)) }
        if !evening.isEmpty { groups.append(SlotGroup(period: .evening, slots: evening)) }
        return groups
    }
}
