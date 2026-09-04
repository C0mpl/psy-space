//
//  ClientHomeworkCard.swift
//  PsySpace
//
//  Created by Claude on 03.09.2026.
//

import SwiftUI

struct ClientHomeworkCard: View {
    let homework: Homework
    let response: HomeworkResponse?
    var onTap: () -> Void

    private var isCompleted: Bool {
        response?.isCompleted ?? false
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                header

                Text(homework.title)
                    .font(.headline)
                    .foregroundStyle(Color.psyspaceTextPrimary)
                    .lineLimit(1)

                if !homework.preview.isEmpty {
                    Text(homework.preview)
                        .font(.subheadline)
                        .foregroundStyle(Color.psyspaceTextSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                footer
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .psyspaceCard(elevation: .low)
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.psyspaceSuccess.opacity(0.15) : Color.psyspacePrimary.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: isCompleted ? "checkmark.circle.fill" : "doc.text.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(isCompleted ? Color.psyspaceSuccess : Color.psyspacePrimary)
            }

            Spacer()

            HStack(spacing: Spacing.xs) {
                if homework.hasAttachments {
                    Label("\(homework.attachments.count)", systemImage: "paperclip")
                        .font(.caption2)
                        .foregroundStyle(Color.psyspaceTextSecondary)
                }

                if response?.isShared == true {
                    Image(systemName: "eye.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.psyspaceSecondary)
                }

                Text(homework.createdAtFormatted)
                    .font(.caption)
                    .foregroundStyle(Color.psyspaceTextSecondary)
            }
        }
    }

    private var footer: some View {
        HStack {
            if isCompleted {
                Text("Виконано")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.psyspaceSuccess)
            } else {
                Text("В процесі")
                    .font(.caption)
                    .foregroundStyle(Color.psyspaceTextSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.psyspaceTextSecondary.opacity(0.5))
        }
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        ClientHomeworkCard(
            homework: Homework(
                clientId: "client-1",
                title: "Вправа на релаксацію",
                instructions: "Практикувати глибоке дихання 10 хвилин щодня",
                plainTextInstructions: "Практикувати глибоке дихання 10 хвилин щодня",
                attachments: [
                    HomeworkAttachment(
                        attachmentId: "1",
                        type: .pdf,
                        name: "breathing.pdf",
                        url: "https://example.com/file.pdf",
                        sizeInBytes: 1024000
                    )
                ],
                status: .active,
                createdAt: .now,
                updatedAt: .now
            ),
            response: nil
        ) {}

        ClientHomeworkCard(
            homework: Homework(
                clientId: "client-1",
                title: "Щоденник емоцій",
                instructions: "Записувати емоції тричі на день",
                plainTextInstructions: "Записувати емоції тричі на день",
                attachments: [],
                status: .active,
                createdAt: .now,
                updatedAt: .now
            ),
            response: HomeworkResponse(
                homeworkId: "hw-1",
                clientId: "client-1",
                content: "Мої записи",
                plainTextContent: "Мої записи",
                isCompleted: true,
                isShared: true,
                createdAt: .now,
                updatedAt: .now
            )
        ) {}
    }
    .padding()
    .background(Color.psyspaceBackground)
}
