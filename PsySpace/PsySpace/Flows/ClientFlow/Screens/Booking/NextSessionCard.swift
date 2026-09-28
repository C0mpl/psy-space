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
            // Header
            HStack {
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(Color.psyspacePrimary)
                        .frame(width: 8, height: 8)

                    Text("НАСТУПНА СЕСІЯ")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(Color.psyspaceTextSecondary)
                }

                Spacer()

                if !booking.hasPendingReschedule {
                    actionsMenu
                }
            }
            .padding(.bottom, Spacing.md)

            // Content
            HStack(spacing: Spacing.md) {
                dateCircle

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(weekdayFormatted)
                        .font(.headline)
                        .foregroundStyle(Color.psyspaceTextPrimary)

                    Text(booking.timeFormatted)
                        .font(.subheadline)
                        .foregroundStyle(Color.psyspaceTextSecondary)

                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "video")
                            .font(.caption)
                        Text("Онлайн-сесія")
                            .font(.caption)
                    }
                    .foregroundStyle(Color.psyspaceSecondary)
                    .padding(.top, Spacing.xxs)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundStyle(Color.psyspaceTextSecondary)
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
        .padding(Spacing.lg)
        .background(Color.psyspaceCardBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.lg))
        .shadow(color: Color.psyspaceTextPrimary.opacity(0.08), radius: 16, y: 8)
    }

    private var weekdayFormatted: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: booking.date).capitalized
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
                .frame(width: 74, height: 74)
                .shadow(color: Color.psyspacePrimary.opacity(0.2), radius: 4, y: 2)

            VStack(spacing: -2) {
                Text(monthFormatted)
                    .font(.caption2.weight(.semibold))
                    .tracking(0.8)
                Text(booking.date.formatted(.dateTime.day()))
                    .font(.title.weight(.bold))
            }
            .foregroundStyle(Color(red: 0.25, green: 0.18, blue: 0.11))
        }
    }

    private var monthFormatted: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.dateFormat = "MMMM"
        return formatter.string(from: booking.date).uppercased()
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
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.psyspaceTextSecondary)
                .frame(width: 32, height: 32)
                .background(Color.psyspaceBackground)
                .clipShape(Circle())
        }
    }
}
