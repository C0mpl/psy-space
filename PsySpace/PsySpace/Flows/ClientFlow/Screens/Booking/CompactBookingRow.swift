//
//  CompactBookingRow.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 23.08.2026.
//

import SwiftUI

struct CompactBookingRow: View {
    let booking: Booking
    let onReschedule: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.psyspacePrimary)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(booking.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.psyspaceTextPrimary)

                Text(booking.timeFormatted)
                    .font(.caption)
                    .foregroundStyle(Color.psyspaceTextSecondary)
            }

            Spacer()

            if booking.hasPendingReschedule {
                Text("Перенос")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.psyspaceWarning)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 2)
                    .background(Color.psyspaceWarning.opacity(0.15))
                    .clipShape(Capsule())
            } else {
                Menu {
                    Button {
                        onReschedule()
                    } label: {
                        Label("Перенести", systemImage: "calendar.badge.clock")
                    }

                    Button(role: .destructive) {
                        onCancel()
                    } label: {
                        Label("Скасувати", systemImage: "xmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.psyspaceTextSecondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(Color.psyspaceCardBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.sm))
    }
}
