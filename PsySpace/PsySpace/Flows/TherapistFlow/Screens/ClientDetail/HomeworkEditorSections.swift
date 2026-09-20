//
//  HomeworkEditorSections.swift
//  PsySpace
//
//  Created by Claude on 03.09.2026.
//

import SwiftUI

struct HomeworkTitleSection: View {
    @Binding var title: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Назва завдання")
                .font(.caption)
                .foregroundStyle(Color.psyspaceTextSecondary)

            TextField("Наприклад: Вправа на релаксацію", text: $title)
                .textFieldStyle(.plain)
                .padding(Spacing.sm)
                .background(Color.psyspaceCardBackground)
                .clipShape(.rect(cornerRadius: CornerRadius.sm))
        }
    }
}

struct HomeworkInstructionsSection: View {
    let state: RichTextState

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Інструкції")
                .font(.caption)
                .foregroundStyle(Color.psyspaceTextSecondary)

            RichTextEditor(
                state: state,
                placeholder: "Опишіть завдання детально...",
                minHeight: 200
            )
        }
    }
}

struct HomeworkAttachmentsSection: View {
    @Binding var attachments: [HomeworkAttachment]
    @Binding var pendingPDFs: [PendingPDF]
    let onAddPDF: () -> Void
    let onAddLink: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Вкладення")
                    .font(.caption)
                    .foregroundStyle(Color.psyspaceTextSecondary)

                Spacer()

                Menu {
                    Button {
                        onAddPDF()
                    } label: {
                        Label("PDF файл", systemImage: "doc.fill")
                    }

                    Button {
                        onAddLink()
                    } label: {
                        Label("Посилання", systemImage: "link")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.psyspacePrimary)
                }
            }

            if attachments.isEmpty && pendingPDFs.isEmpty {
                Text("Немає вкладень")
                    .font(.caption)
                    .foregroundStyle(Color.psyspaceTextSecondary.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Spacing.md)
            } else {
                VStack(spacing: Spacing.xs) {
                    ForEach(attachments) { attachment in
                        AttachmentRow(attachment: attachment) {
                            attachments.removeAll { $0.attachmentId == attachment.attachmentId }
                        }
                    }

                    ForEach(pendingPDFs) { pdf in
                        PendingPDFRow(pdf: pdf) {
                            pendingPDFs.removeAll { $0.id == pdf.id }
                        }
                    }
                }
            }
        }
        .padding(Spacing.sm)
        .background(Color.psyspaceCardBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.sm))
    }
}
