//
//  HomeworkEditor.swift
//  PsySpace
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
                    HomeworkTitleSection(title: $title)
                    HomeworkInstructionsSection(state: instructionsState)
                    HomeworkAttachmentsSection(
                        attachments: $attachments,
                        pendingPDFs: $pendingPDFs,
                        onAddPDF: { showPDFPicker = true },
                        onAddLink: { showLinkSheet = true }
                    )
                }
                .padding()
                .adaptiveReadableWidth()
            }
            .background(Color.psyspaceBackground)
            .navigationTitle(isEditing ? "Редагувати завдання" : "Нове завдання")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
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
                    PsySpaceLoadingOverlay(message: "Зберігаємо...")
                }
            }
        }
        .onAppear {
            loadExistingHomework()
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Скасувати") { dismiss() }
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
                        .foregroundStyle(Color.psyspaceTextSecondary)
                }
            }
        }
    }

    // MARK: - Actions

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

#Preview {
    HomeworkEditor(clientId: "client-1")
        .environment(HomeworkRepository())
}
