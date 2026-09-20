//
//  HomeworkAttachmentComponents.swift
//  PsySpace
//
//  Created by Claude on 03.09.2026.
//

import SwiftUI

struct PendingPDF: Identifiable {
    let id: String
    let name: String
    let localURL: URL
}

struct AttachmentRow: View {
    let attachment: HomeworkAttachment
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: attachment.type == .pdf ? "doc.fill" : "link")
                .foregroundStyle(Color.psyspacePrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.name)
                    .font(.subheadline)
                    .foregroundStyle(Color.psyspaceTextPrimary)
                    .lineLimit(1)

                if let size = attachment.formattedSize {
                    Text(size)
                        .font(.caption2)
                        .foregroundStyle(Color.psyspaceTextSecondary)
                }
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.psyspaceTextSecondary)
            }
        }
        .padding(Spacing.xs)
        .background(Color.psyspaceBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.sm))
    }
}

struct PendingPDFRow: View {
    let pdf: PendingPDF
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "doc.fill")
                .foregroundStyle(Color.psyspaceSecondary)

            Text(pdf.name)
                .font(.subheadline)
                .foregroundStyle(Color.psyspaceTextPrimary)
                .lineLimit(1)

            Text("(очікує)")
                .font(.caption2)
                .foregroundStyle(Color.psyspaceTextSecondary)

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.psyspaceTextSecondary)
            }
        }
        .padding(Spacing.xs)
        .background(Color.psyspaceBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.sm))
    }
}

struct AddLinkSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var url: String
    @Binding var name: String
    var onAdd: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("URL посилання")
                        .font(.caption)
                        .foregroundStyle(Color.psyspaceTextSecondary)

                    TextField("https://...", text: $url)
                        .textFieldStyle(.plain)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .padding(Spacing.sm)
                        .background(Color.psyspaceCardBackground)
                        .clipShape(.rect(cornerRadius: CornerRadius.sm))
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Назва (необов'язково)")
                        .font(.caption)
                        .foregroundStyle(Color.psyspaceTextSecondary)

                    TextField("Опис посилання", text: $name)
                        .textFieldStyle(.plain)
                        .padding(Spacing.sm)
                        .background(Color.psyspaceCardBackground)
                        .clipShape(.rect(cornerRadius: CornerRadius.sm))
                }

                Spacer()
            }
            .padding()
            .background(Color.psyspaceBackground)
            .navigationTitle("Додати посилання")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Додати") {
                        onAdd()
                        dismiss()
                    }
                    .disabled(url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
