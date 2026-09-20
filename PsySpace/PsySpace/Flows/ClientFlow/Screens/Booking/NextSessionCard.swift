//
//  NextSessionCard.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 23.08.2026.
//

import SwiftUI

struct NextSessionCard: View {
    let booking: Booking
    let onReschedule: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.md) {
                dateCircle

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Наступний сеанс")
                        .font(.subheadline)
                        .foregroundStyle(Color.psyspaceTextSecondary)

                    Text(booking.date.formatted(.dateTime.weekday(.wide)))
                        .font(.headline)
                        .foregroundStyle(Color.psyspaceTextPrimary)

                    Text(booking.timeFormatted)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.psyspacePrimary)
                }

                Spacer()

                if !booking.hasPendingReschedule {
                    actionsMenu
                }
            }

            if booking.hasPendingReschedule {
                Divider()
                    .padding(.vertical, Spacing.sm)

                RescheduleRequestCard(
                    booking: booking,
                    isCurrentUserRequester: booking.rescheduleRequest?.requestedBy == .client
                )
            }
        }
        .psyspaceCard(elevation: .medium)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(Color.psyspacePrimary.opacity(0.2), lineWidth: 1)
        )
    }

    private var dateCircle: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.psyspacePrimary, Color.psyspaceAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)

            VStack(spacing: -2) {
                Text(booking.date.formatted(.dateTime.day()))
                    .font(.title2.weight(.bold))
                Text(booking.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(.white)
        }
    }

    private var actionsMenu: some View {
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
            Image(systemName: "ellipsis.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.psyspaceTextSecondary)
                .symbolRenderingMode(.hierarchical)
        }
    }
}
