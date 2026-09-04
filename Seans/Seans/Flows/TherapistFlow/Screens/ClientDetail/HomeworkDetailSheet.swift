//
//  HomeworkDetailSheet.swift
//  Seans
//
//  Created by Claude on 03.09.2026.
//

import SwiftUI

struct HomeworkDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let homework: Homework
    let response: HomeworkResponse?
    var onEdit: () -> Void

    @State private var downloadingAttachment: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    statusBadge
                    instructionsSection
                    if !homework.attachments.isEmpty {
                        attachmentsSection
                    }
                    if let response, response.isShared {
                        responseSection(response)
                    }
                }
                .padding()
                .adaptiveReadableWidth()
            }
            .background(Color.seansBackground)
            .navigationTitle(homework.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрити") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        dismiss()
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                    }
                }
            }
        }
    }

    private var statusBadge: some View {
        HStack(spacing: Spacing.sm) {
            if response?.isCompleted == true {
                Label("Виконано", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.seansSuccess)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(Color.seansSuccess.opacity(0.15))
                    .clipShape(.capsule)
            } else {
                Label("Активне", systemImage: "clock.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.seansPrimary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(Color.seansPrimary.opacity(0.15))
                    .clipShape(.capsule)
            }

            if response?.isShared == true {
                Label("Поділився", systemImage: "eye.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.seansSecondary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(Color.seansSecondary.opacity(0.15))
                    .clipShape(.capsule)
            }

            Spacer()

            Text(homework.createdAtFormatted)
                .font(.caption)
                .foregroundStyle(Color.seansTextSecondary)
        }
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("Інструкції", systemImage: "doc.text")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.seansTextPrimary)

            RichTextDisplay(serialized: homework.instructions)
                .padding(Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.seansCardBackground)
                .clipShape(.rect(cornerRadius: CornerRadius.sm))
        }
    }

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("Вкладення", systemImage: "paperclip")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.seansTextPrimary)

            VStack(spacing: Spacing.xs) {
                ForEach(homework.attachments) { attachment in
                    AttachmentViewRow(
                        attachment: attachment,
                        isDownloading: downloadingAttachment == attachment.attachmentId
                    ) {
                        openAttachment(attachment)
                    }
                }
            }
            .padding(Spacing.sm)
            .background(Color.seansCardBackground)
            .clipShape(.rect(cornerRadius: CornerRadius.sm))
        }
    }

    private func responseSection(_ response: HomeworkResponse) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Label("Відповідь клієнта", systemImage: "text.bubble")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.seansTextPrimary)

                Spacer()

                Text(response.updatedAtFormatted)
                    .font(.caption2)
                    .foregroundStyle(Color.seansTextSecondary)
            }

            if response.hasContent {
                RichTextDisplay(serialized: response.content)
                    .padding(Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.seansCardBackground)
                    .clipShape(.rect(cornerRadius: CornerRadius.sm))
            } else {
                Text("Клієнт позначив завдання виконаним, але не додав коментар.")
                    .font(.caption)
                    .foregroundStyle(Color.seansTextSecondary)
                    .padding(Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.seansCardBackground)
                    .clipShape(.rect(cornerRadius: CornerRadius.sm))
            }
        }
    }

    private func openAttachment(_ attachment: HomeworkAttachment) {
        if attachment.type == .link {
            if let url = URL(string: attachment.url) {
                UIApplication.shared.open(url)
            }
        } else {
            Task {
                await downloadAndOpenPDF(attachment)
            }
        }
    }

    private func downloadAndOpenPDF(_ attachment: HomeworkAttachment) async {
        downloadingAttachment = attachment.attachmentId
        defer { downloadingAttachment = nil }

        do {
            let localURL = try await StorageService.shared.downloadHomeworkAttachment(from: attachment.url)

            await MainActor.run {
                let activityVC = UIActivityViewController(
                    activityItems: [localURL],
                    applicationActivities: nil
                )

                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    var presentingVC = rootVC
                    while let presented = presentingVC.presentedViewController {
                        presentingVC = presented
                    }
                    activityVC.popoverPresentationController?.sourceView = presentingVC.view
                    presentingVC.present(activityVC, animated: true)
                }
            }
        } catch {
            #if DEBUG
            print("HomeworkDetailSheet: Failed to download PDF: \(error)")
            #endif
            HapticService.notification(.error)
        }
    }
}

private struct AttachmentViewRow: View {
    let attachment: HomeworkAttachment
    let isDownloading: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: attachment.type == .pdf ? "doc.fill" : "link")
                    .foregroundStyle(Color.seansPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.name)
                        .font(.subheadline)
                        .foregroundStyle(Color.seansTextPrimary)
                        .lineLimit(1)

                    if let size = attachment.formattedSize {
                        Text(size)
                            .font(.caption2)
                            .foregroundStyle(Color.seansTextSecondary)
                    }
                }

                Spacer()

                if isDownloading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: attachment.type == .pdf ? "arrow.down.circle" : "arrow.up.right.square")
                        .foregroundStyle(Color.seansPrimary)
                }
            }
            .padding(Spacing.xs)
            .background(Color.seansBackground)
            .clipShape(.rect(cornerRadius: CornerRadius.sm))
        }
        .buttonStyle(.plain)
        .disabled(isDownloading)
    }
}

struct RichTextDisplay: View {
    let serialized: String

    var body: some View {
        if let data = Data(base64Encoded: serialized),
           let attrString = try? NSAttributedString(
               data: data,
               options: [.documentType: NSAttributedString.DocumentType.rtf],
               documentAttributes: nil
           ) {
            Text(AttributedString(attrString))
                .font(.body)
                .foregroundStyle(Color.seansTextPrimary)
        } else {
            Text(serialized)
                .font(.body)
                .foregroundStyle(Color.seansTextPrimary)
        }
    }
}

#Preview {
    HomeworkDetailSheet(
        homework: Homework(
            clientId: "client-1",
            title: "Вправа на релаксацію",
            instructions: "Практикувати глибоке дихання 10 хвилин щодня",
            plainTextInstructions: "Практикувати глибоке дихання 10 хвилин щодня",
            attachments: [
                HomeworkAttachment(
                    attachmentId: "1",
                    type: .pdf,
                    name: "breathing_exercises.pdf",
                    url: "https://example.com/file.pdf",
                    sizeInBytes: 1024000
                ),
                HomeworkAttachment(
                    attachmentId: "2",
                    type: .link,
                    name: "Відео з інструкціями",
                    url: "https://youtube.com/watch?v=123",
                    sizeInBytes: nil
                )
            ],
            status: .active,
            createdAt: .now,
            updatedAt: .now
        ),
        response: HomeworkResponse(
            homeworkId: "hw-1",
            clientId: "client-1",
            content: "Я виконав вправу сьогодні і відчув себе набагато краще.",
            plainTextContent: "Я виконав вправу сьогодні і відчув себе набагато краще.",
            isCompleted: true,
            isShared: true,
            createdAt: .now,
            updatedAt: .now
        )
    ) {}
}
