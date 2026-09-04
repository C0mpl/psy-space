//
//  HomeworkCard.swift
//  PsySpace
//
//  Created by Claude on 03.09.2026.
//

import SwiftUI

struct HomeworkCard: View {
    let homework: Homework
    let response: HomeworkResponse?
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.sm) {
                homeworkIcon

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(homework.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.psyspaceTextPrimary)
                        .lineLimit(1)

                    if !homework.preview.isEmpty {
                        Text(homework.preview)
                            .font(.caption)
                            .foregroundStyle(Color.psyspaceTextSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    statusRow
                }

                Spacer()

                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    Text(homework.createdAtFormatted)
                        .font(.caption2)
                        .foregroundStyle(Color.psyspaceTextSecondary)

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(Color.psyspaceTextSecondary.opacity(0.5))
                }
            }
            .padding(Spacing.sm)
            .background(Color.psyspaceCardBackground)
            .clipShape(.rect(cornerRadius: CornerRadius.sm))
        }
        .buttonStyle(.plain)
    }

    private var homeworkIcon: some View {
        ZStack {
            Circle()
                .fill(iconBackgroundColor)
                .frame(width: 36, height: 36)

            Image(systemName: iconName)
                .font(.system(size: 14))
                .foregroundStyle(iconColor)
        }
    }

    private var iconBackgroundColor: Color {
        if response?.isCompleted == true {
            return Color.psyspaceSuccess.opacity(0.15)
        }
        return Color.psyspacePrimary.opacity(0.15)
    }

    private var iconColor: Color {
        if response?.isCompleted == true {
            return Color.psyspaceSuccess
        }
        return Color.psyspacePrimary
    }

    private var iconName: String {
        if response?.isCompleted == true {
            return "checkmark.circle.fill"
        }
        return "doc.text.fill"
    }

    private var statusRow: some View {
        HStack(spacing: Spacing.xs) {
            if homework.hasAttachments {
                Label("\(homework.attachments.count)", systemImage: "paperclip")
                    .font(.caption2)
                    .foregroundStyle(Color.psyspaceTextSecondary)
            }

            if response?.isCompleted == true {
                Text("Виконано")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.psyspaceSuccess)
            }

            if response?.isShared == true {
                Image(systemName: "eye.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.psyspaceSecondary)
            }
        }
    }
}

struct AddHomeworkCard: View {
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.sm) {
                addIcon

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Нове завдання")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.psyspaceTextPrimary)

                    Text("Додати домашнє завдання клієнту")
                        .font(.caption)
                        .foregroundStyle(Color.psyspacePrimary)
                }

                Spacer()

                Image(systemName: "plus")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.psyspacePrimary)
            }
            .padding(Spacing.sm)
            .background(Color.psyspaceCardBackground)
            .clipShape(.rect(cornerRadius: CornerRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 1, dash: [6])
                    )
                    .foregroundStyle(Color.psyspacePrimary.opacity(0.3))
            )
        }
        .buttonStyle(.plain)
    }

    private var addIcon: some View {
        ZStack {
            Circle()
                .fill(Color.psyspacePrimary.opacity(0.1))
                .frame(width: 36, height: 36)

            Image(systemName: "doc.badge.plus")
                .font(.system(size: 14))
                .foregroundStyle(Color.psyspacePrimary.opacity(0.6))
        }
    }
}

#Preview("Homework Card") {
    VStack(spacing: Spacing.sm) {
        HomeworkCard(
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

        HomeworkCard(
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

        AddHomeworkCard {}
    }
    .padding()
    .background(Color.psyspaceBackground)
}
