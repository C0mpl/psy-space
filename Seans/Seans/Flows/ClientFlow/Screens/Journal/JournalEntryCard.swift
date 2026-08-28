//
//  JournalEntryCard.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 27.08.2026.
//

import SwiftUI

struct JournalEntryCard: View {
    let entry: JournalEntry
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                header

                if !entry.title.isEmpty {
                    Text(entry.title)
                        .font(.headline)
                        .foregroundStyle(Color.seansTextPrimary)
                        .lineLimit(1)
                }

                if !entry.preview.isEmpty {
                    Text(entry.preview)
                        .font(.subheadline)
                        .foregroundStyle(Color.seansTextSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                footer
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .seansCard(elevation: .low)
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        HStack {
            if let mood = entry.mood {
                Text(mood.emoji)
                    .font(.title2)
            }

            Spacer()

            HStack(spacing: Spacing.xs) {
                if entry.hasAudio {
                    Image(systemName: "waveform")
                        .font(.caption2)
                        .foregroundStyle(Color.seansSecondary)
                }

                if entry.isShared {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.seansSecondary)
                }

                Text(entry.createdAtFormatted)
                    .font(.caption)
                    .foregroundStyle(Color.seansTextSecondary)
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.seansTextSecondary.opacity(0.5))
        }
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        JournalEntryCard(
            entry: JournalEntry(
                clientId: "test",
                title: "Сьогодні був хороший день",
                content: "",
                plainTextContent: "Я відчуваю себе набагато краще після нашого останнього сеансу. Вправи на дихання дійсно допомагають.",
                mood: .good,
                isShared: true
            ),
            onTap: {}
        )

        JournalEntryCard(
            entry: JournalEntry(
                clientId: "test",
                title: "Тривожний ранок",
                content: "",
                plainTextContent: "Прокинувся з тривогою. Спробував застосувати техніки, які ми обговорювали.",
                mood: .bad,
                isShared: false
            ),
            onTap: {}
        )

        JournalEntryCard(
            entry: JournalEntry(
                clientId: "test",
                title: "",
                content: "",
                plainTextContent: "Просто хотів записати свої думки сьогодні без особливої теми...",
                mood: nil,
                isShared: false
            ),
            onTap: {}
        )
    }
    .padding()
    .background(Color.seansBackground)
}
