//
//  ClientHomeworkDetailSheet.swift
//  Seans
//
//  Created by Claude on 03.09.2026.
//

import SwiftUI

struct ClientHomeworkDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HomeworkRepository.self) private var homeworkRepo

    let homework: Homework
    let clientId: String
    var existingResponse: HomeworkResponse?

    @State private var responseState = RichTextState()
    @State private var isCompleted: Bool
    @State private var isShared: Bool
    @State private var isSaving = false
    @State private var downloadingAttachment: String?
    @State private var hasChanges = false

    init(homework: Homework, clientId: String, existingResponse: HomeworkResponse?) {
        self.homework = homework
        self.clientId = clientId
        self.existingResponse = existingResponse
        self._isCompleted = State(initialValue: existingResponse?.isCompleted ?? false)
        self._isShared = State(initialValue: existingResponse?.isShared ?? false)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    instructionsSection
                    if !homework.attachments.isEmpty {
                        attachmentsSection
                    }
                    responseSection
                    sharingSection
                }
                .padding()
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

                ToolbarItem(placement: .confirmationAction) {
                    Button("Зберегти") {
                        Task { await save() }
                    }
                    .disabled(!hasChanges || isSaving)
                }
            }
            .overlay {
                if isSaving {
                    SeansLoadingOverlay(message: "Зберігаємо...")
                }
            }
        }
        .onAppear {
            loadExistingResponse()
        }
        .onChange(of: responseState.plainText) { _, _ in
            hasChanges = true
        }
        .onChange(of: isCompleted) { _, _ in
            hasChanges = true
        }
        .onChange(of: isShared) { _, _ in
            hasChanges = true
        }
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("Завдання", systemImage: "doc.text")
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
            Label("Матеріали", systemImage: "paperclip")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.seansTextPrimary)

            VStack(spacing: Spacing.xs) {
                ForEach(homework.attachments) { attachment in
                    ClientAttachmentRow(
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

    private var responseSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Label("Моя відповідь", systemImage: "text.bubble")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.seansTextPrimary)

                Spacer()

                Toggle("Виконано", isOn: $isCompleted)
                    .toggleStyle(CheckboxToggleStyle())
            }

            RichTextEditor(
                state: responseState,
                placeholder: "Ваші думки, враження, результати виконання...",
                minHeight: 150
            )
        }
    }

    private var sharingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Toggle(isOn: $isShared) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Поділитися з терапевтом")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.seansTextPrimary)

                    Text("Терапевт зможе бачити вашу відповідь")
                        .font(.caption)
                        .foregroundStyle(Color.seansTextSecondary)
                }
            }
            .tint(Color.seansSecondary)
            .padding(Spacing.sm)
            .background(Color.seansCardBackground)
            .clipShape(.rect(cornerRadius: CornerRadius.sm))
        }
    }

    private func loadExistingResponse() {
        guard let response = existingResponse else { return }
        responseState.load(serialized: response.content)
        isCompleted = response.isCompleted
        isShared = response.isShared
        hasChanges = false
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let content = responseState.serialized
        let plainTextContent = responseState.plainText.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try await homeworkRepo.createOrUpdateResponse(
                homeworkId: homework.homeworkId,
                clientId: clientId,
                content: content,
                plainTextContent: plainTextContent,
                isCompleted: isCompleted,
                isShared: isShared
            )

            HapticService.notification(.success)
            dismiss()
        } catch {
            HapticService.notification(.error)
            #if DEBUG
            print("ClientHomeworkDetailSheet: Failed to save response: \(error)")
            #endif
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
            print("ClientHomeworkDetailSheet: Failed to download PDF: \(error)")
            #endif
            HapticService.notification(.error)
        }
    }
}

private struct ClientAttachmentRow: View {
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

private struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(configuration.isOn ? Color.seansSuccess : Color.seansTextSecondary)

                configuration.label
                    .font(.caption.weight(.medium))
                    .foregroundStyle(configuration.isOn ? Color.seansSuccess : Color.seansTextSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ClientHomeworkDetailSheet(
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
        clientId: "client-1",
        existingResponse: nil
    )
    .environment(HomeworkRepository())
}
