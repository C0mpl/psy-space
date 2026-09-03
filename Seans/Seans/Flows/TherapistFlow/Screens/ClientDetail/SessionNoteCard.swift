//
//  SessionNoteCard.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 28.08.2026.
//

import SwiftUI

struct SessionNoteCard: View {
    let note: SessionNote
    let sessionDate: Date
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.sm) {
                noteIcon

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(sessionDateFormatted)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.seansTextPrimary)

                    if !note.preview.isEmpty {
                        Text(note.preview)
                            .font(.caption)
                            .foregroundStyle(Color.seansTextSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    Text(note.updatedAtFormatted)
                        .font(.caption2)
                        .foregroundStyle(Color.seansTextSecondary)

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(Color.seansTextSecondary.opacity(0.5))
                }
            }
            .padding(Spacing.sm)
            .background(Color.seansCardBackground)
            .clipShape(.rect(cornerRadius: CornerRadius.sm))
        }
        .buttonStyle(.plain)
    }

    private var noteIcon: some View {
        ZStack {
            Circle()
                .fill(Color.seansSecondary.opacity(0.15))
                .frame(width: 36, height: 36)

            Image(systemName: "note.text")
                .font(.system(size: 14))
                .foregroundStyle(Color.seansSecondary)
        }
    }

    private var sessionDateFormatted: String {
        sessionDate.formatted(date: .abbreviated, time: .shortened)
    }
}

struct SessionWithoutNoteCard: View {
    let booking: Booking
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.sm) {
                addIcon

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(sessionDateFormatted)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.seansTextPrimary)

                    Text("Додати нотатку")
                        .font(.caption)
                        .foregroundStyle(Color.seansSecondary)
                }

                Spacer()

                Image(systemName: "plus")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.seansSecondary)
            }
            .padding(Spacing.sm)
            .background(Color.seansCardBackground)
            .clipShape(.rect(cornerRadius: CornerRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 1, dash: [6])
                    )
                    .foregroundStyle(Color.seansSecondary.opacity(0.3))
            )
        }
        .buttonStyle(.plain)
    }

    private var addIcon: some View {
        ZStack {
            Circle()
                .fill(Color.seansSecondary.opacity(0.1))
                .frame(width: 36, height: 36)

            Image(systemName: "doc.badge.plus")
                .font(.system(size: 14))
                .foregroundStyle(Color.seansSecondary.opacity(0.6))
        }
    }

    private var sessionDateFormatted: String {
        booking.startTime.formatted(date: .abbreviated, time: .shortened)
    }
}

#Preview("With Note") {
    SessionNoteCard(
        note: SessionNote(
            bookingId: "booking-1",
            clientId: "client-1",
            hypotheses: "Test hypothesis content",
            observations: "Test observations",
            plainTextContent: "Test hypothesis content. Test observations."
        ),
        sessionDate: .now
    ) {}
    .padding()
    .background(Color.seansBackground)
}

#Preview("Without Note") {
    SessionWithoutNoteCard(
        booking: Booking(
            clientId: "client-1",
            clientName: "Test Client",
            date: .now,
            startTime: .now,
            endTime: .now.addingTimeInterval(3600),
            status: .completed
        )
    ) {}
    .padding()
    .background(Color.seansBackground)
}
