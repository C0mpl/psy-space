//
//  HomeworkEditor.swift
//  Seans
//
//  Created by Claude on 03.09.2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct HomeworkEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HomeworkRepository.self) private var homeworkRepo

    let clientId: String
    var existingHomework: Homework?

    @State private var title = ""
    @State private var instructionsState = RichTextState()
    @State private var attachments: [HomeworkAttachment] = []
    @State private var pendingPDFs: [PendingPDF] = []
    @State private var linkURL = ""
    @State private var linkName = ""
    @State private var showLinkSheet = false
    @State private var showPDFPicker = false
    @State private var isSaving = false
    @State private var showDeleteConfirmation = false
    @State private var showArchiveConfirmation = false

    private var isEditing: Bool { existingHomework != nil }

    private var canSave: Bool {
        let hasTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasInstructions = !instructionsState.plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return !isSaving && hasTitle && hasInstructions
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    titleSection
                    instructionsSection
                    attachmentsSection
                }
                .padding()
            }
            .background(Color.seansBackground)
            .navigationTitle(isEditing ? "Редагувати завдання" : "Нове завдання")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Зберегти") {
                        Task { await save() }
                    }
                    .disabled(!canSave)
                }

                if isEditing {
                    ToolbarItem(placement: .destructiveAction) {
                        Menu {
                            Button(role: .destructive) {
                                showArchiveConfirmation = true
                            } label: {
                                Label("Архівувати", systemImage: "archivebox")
                            }

                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label("Видалити", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(Color.seansTextSecondary)
                        }
                    }
                }
            }
            .confirmationDialog(
                "Архівувати завдання?",
                isPresented: $showArchiveConfirmation,
                titleVisibility: .visible
            ) {
                Button("Архівувати", role: .destructive) {
                    Task { await archiveHomework() }
                }
                Button("Скасувати", role: .cancel) {}
            } message: {
                Text("Клієнт більше не бачитиме це завдання.")
            }
            .confirmationDialog(
                "Видалити завдання?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Видалити", role: .destructive) {
                    Task { await deleteHomework() }
                }
                Button("Скасувати", role: .cancel) {}
            } message: {
                Text("Цю дію неможливо скасувати. Усі вкладення також буде видалено.")
            }
            .sheet(isPresented: $showLinkSheet) {
                AddLinkSheet(url: $linkURL, name: $linkName) {
                    addLink()
                }
            }
            .fileImporter(
                isPresented: $showPDFPicker,
                allowedContentTypes: [UTType.pdf],
                allowsMultipleSelection: false
            ) { result in
                handlePDFSelection(result)
            }
            .overlay {
                if isSaving {
                    SeansLoadingOverlay(message: "Зберігаємо...")
                }
            }
        }
        .onAppear {
            loadExistingHomework()
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Назва завдання")
                .font(.caption)
                .foregroundStyle(Color.seansTextSecondary)

            TextField("Наприклад: Вправа на релаксацію", text: $title)
                .textFieldStyle(.plain)
                .padding(Spacing.sm)
                .background(Color.seansCardBackground)
                .clipShape(.rect(cornerRadius: CornerRadius.sm))
        }
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Інструкції")
                .font(.caption)
                .foregroundStyle(Color.seansTextSecondary)

            RichTextEditor(
                state: instructionsState,
                placeholder: "Опишіть завдання детально...",
                minHeight: 200
            )
        }
    }

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Вкладення")
                    .font(.caption)
                    .foregroundStyle(Color.seansTextSecondary)

                Spacer()

                Menu {
                    Button {
                        showPDFPicker = true
                    } label: {
                        Label("PDF файл", systemImage: "doc.fill")
                    }

                    Button {
                        showLinkSheet = true
                    } label: {
                        Label("Посилання", systemImage: "link")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.seansPrimary)
                }
            }

            if attachments.isEmpty && pendingPDFs.isEmpty {
                Text("Немає вкладень")
                    .font(.caption)
                    .foregroundStyle(Color.seansTextSecondary.opacity(0.7))
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
        .background(Color.seansCardBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.sm))
    }

    private func loadExistingHomework() {
        guard let hw = existingHomework else { return }

        title = hw.title
        instructionsState.load(serialized: hw.instructions)
        attachments = hw.attachments
    }

    private func addLink() {
        guard !linkURL.isEmpty else { return }

        var validURL = linkURL
        if !validURL.hasPrefix("http://") && !validURL.hasPrefix("https://") {
            validURL = "https://" + validURL
        }

        let name = linkName.isEmpty ? validURL : linkName

        let attachment = HomeworkAttachment(
            attachmentId: UUID().uuidString,
            type: .link,
            name: name,
            url: validURL,
            sizeInBytes: nil
        )

        attachments.append(attachment)
        linkURL = ""
        linkName = ""
    }

    private func handlePDFSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("pdf")

            do {
                try FileManager.default.copyItem(at: url, to: tempURL)
                let pending = PendingPDF(
                    id: UUID().uuidString,
                    name: url.lastPathComponent,
                    localURL: tempURL
                )
                pendingPDFs.append(pending)
            } catch {
                #if DEBUG
                print("HomeworkEditor: Failed to copy PDF: \(error)")
                #endif
            }

        case .failure(let error):
            #if DEBUG
            print("HomeworkEditor: PDF picker error: \(error)")
            #endif
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let instructions = instructionsState.serialized
        let plainTextInstructions = instructionsState.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        // Upload pending PDFs
        var finalAttachments = attachments
        let homeworkId = existingHomework?.homeworkId ?? UUID().uuidString

        for pdf in pendingPDFs {
            do {
                let attachment = try await homeworkRepo.uploadAttachment(
                    clientId: clientId,
                    homeworkId: homeworkId,
                    localURL: pdf.localURL,
                    name: pdf.name
                )
                finalAttachments.append(attachment)
            } catch {
                #if DEBUG
                print("HomeworkEditor: Failed to upload PDF: \(error)")
                #endif
                HapticService.notification(.error)
                return
            }
        }

        do {
            if var hw = existingHomework {
                hw.title = trimmedTitle
                hw.instructions = instructions
                hw.plainTextInstructions = plainTextInstructions
                hw.attachments = finalAttachments
                try await homeworkRepo.updateHomework(hw)
            } else {
                try await homeworkRepo.createHomework(
                    clientId: clientId,
                    title: trimmedTitle,
                    instructions: instructions,
                    plainTextInstructions: plainTextInstructions,
                    attachments: finalAttachments
                )
            }

            HapticService.notification(.success)
            dismiss()
        } catch {
            HapticService.notification(.error)
            #if DEBUG
            print("HomeworkEditor: Failed to save homework: \(error)")
            #endif
        }
    }

    private func archiveHomework() async {
        guard let hw = existingHomework else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            try await homeworkRepo.archiveHomework(hw.homeworkId)
            HapticService.notification(.success)
            dismiss()
        } catch {
            HapticService.notification(.error)
            #if DEBUG
            print("HomeworkEditor: Failed to archive homework: \(error)")
            #endif
        }
    }

    private func deleteHomework() async {
        guard let hw = existingHomework else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            try await homeworkRepo.deleteHomework(hw.homeworkId)
            HapticService.notification(.success)
            dismiss()
        } catch {
            HapticService.notification(.error)
            #if DEBUG
            print("HomeworkEditor: Failed to delete homework: \(error)")
            #endif
        }
    }
}

private struct PendingPDF: Identifiable {
    let id: String
    let name: String
    let localURL: URL
}

private struct AttachmentRow: View {
    let attachment: HomeworkAttachment
    var onDelete: () -> Void

    var body: some View {
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

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.seansTextSecondary)
            }
        }
        .padding(Spacing.xs)
        .background(Color.seansBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.sm))
    }
}

private struct PendingPDFRow: View {
    let pdf: PendingPDF
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "doc.fill")
                .foregroundStyle(Color.seansSecondary)

            Text(pdf.name)
                .font(.subheadline)
                .foregroundStyle(Color.seansTextPrimary)
                .lineLimit(1)

            Text("(очікує)")
                .font(.caption2)
                .foregroundStyle(Color.seansTextSecondary)

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.seansTextSecondary)
            }
        }
        .padding(Spacing.xs)
        .background(Color.seansBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.sm))
    }
}

private struct AddLinkSheet: View {
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
                        .foregroundStyle(Color.seansTextSecondary)

                    TextField("https://...", text: $url)
                        .textFieldStyle(.plain)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .padding(Spacing.sm)
                        .background(Color.seansCardBackground)
                        .clipShape(.rect(cornerRadius: CornerRadius.sm))
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Назва (необов'язково)")
                        .font(.caption)
                        .foregroundStyle(Color.seansTextSecondary)

                    TextField("Опис посилання", text: $name)
                        .textFieldStyle(.plain)
                        .padding(Spacing.sm)
                        .background(Color.seansCardBackground)
                        .clipShape(.rect(cornerRadius: CornerRadius.sm))
                }

                Spacer()
            }
            .padding()
            .background(Color.seansBackground)
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

#Preview {
    HomeworkEditor(clientId: "client-1")
        .environment(HomeworkRepository())
}
