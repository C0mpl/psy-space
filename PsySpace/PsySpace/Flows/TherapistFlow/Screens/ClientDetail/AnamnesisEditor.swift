//
//  AnamnesisEditor.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 28.08.2026.
//

import SwiftUI

struct AnamnesisEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionNoteRepository.self) private var noteRepo

    let clientId: String
    let clientName: String
    var existingAnamnesis: ClientAnamnesis?

    @State private var selectedSection: AnamnesisSection = .background
    @State private var backgroundState = RichTextState()
    @State private var issuesState = RichTextState()
    @State private var goalsState = RichTextState()
    @State private var isSaving = false

    private var isEditing: Bool { existingAnamnesis != nil }

    private var canSave: Bool {
        let hasBackground = !backgroundState.plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasIssues = !issuesState.plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasGoals = !goalsState.plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return !isSaving && (hasBackground || hasIssues || hasGoals)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                clientHeader
                sectionPicker
                editorContent
            }
            .adaptiveReadableWidth()
            .background(Color.psyspaceBackground)
            .navigationTitle(isEditing ? "Редагувати анамнез" : "Анамнез клієнта")
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
            }
            .overlay {
                if isSaving {
                    PsySpaceLoadingOverlay(message: "Зберігаємо...")
                }
            }
        }
        .onAppear {
            loadExistingAnamnesis()
        }
    }

    private var clientHeader: some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.psyspacePrimary.opacity(0.1))
                    .frame(width: 32, height: 32)

                Text(clientName.prefix(1).uppercased())
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.psyspacePrimary)
            }

            Text(clientName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.psyspaceTextPrimary)

            Spacer()

            if let anamnesis = existingAnamnesis {
                Text("Оновлено: \(anamnesis.updatedAtFormatted)")
                    .font(.caption)
                    .foregroundStyle(Color.psyspaceTextSecondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, Spacing.sm)
        .background(Color.psyspaceCardBackground)
    }

    private var sectionPicker: some View {
        Picker("Розділ", selection: $selectedSection) {
            ForEach(AnamnesisSection.allCases, id: \.self) { section in
                Text(section.shortTitle).tag(section)
            }
        }
        .pickerStyle(.segmented)
        .padding()
    }

    @ViewBuilder
    private var editorContent: some View {
        switch selectedSection {
        case .background:
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Сімейна історія, медичний анамнез, важливі події")
                    .font(.caption)
                    .foregroundStyle(Color.psyspaceTextSecondary)
                    .padding(.horizontal)

                RichTextEditor(
                    state: backgroundState,
                    placeholder: "Сімейний стан, освіта, робота, медичні діагнози, попередня терапія...",
                    minHeight: 250
                )
                .padding(.horizontal)
            }

        case .issues:
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Поточні проблеми та скарги клієнта")
                    .font(.caption)
                    .foregroundStyle(Color.psyspaceTextSecondary)
                    .padding(.horizontal)

                RichTextEditor(
                    state: issuesState,
                    placeholder: "Причини звернення, симптоми, тривалість, що погіршує/покращує стан...",
                    minHeight: 250
                )
                .padding(.horizontal)
            }

        case .goals:
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Цілі терапії та очікувані результати")
                    .font(.caption)
                    .foregroundStyle(Color.psyspaceTextSecondary)
                    .padding(.horizontal)

                RichTextEditor(
                    state: goalsState,
                    placeholder: "Чого клієнт хоче досягти, короткострокові та довгострокові цілі...",
                    minHeight: 250
                )
                .padding(.horizontal)
            }
        }

        Spacer()
    }

    private func loadExistingAnamnesis() {
        guard let anamnesis = existingAnamnesis else { return }

        backgroundState.load(serialized: anamnesis.background)
        issuesState.load(serialized: anamnesis.presentingIssues)
        goalsState.load(serialized: anamnesis.treatmentGoals)
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let background = backgroundState.serialized
        let issues = issuesState.serialized
        let goals = goalsState.serialized

        let plainBackground = backgroundState.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        let plainIssues = issuesState.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        let plainGoals = goalsState.plainText.trimmingCharacters(in: .whitespacesAndNewlines)

        let plainTextSummary = [
            plainBackground.isEmpty ? nil : "Анамнез: \(plainBackground)",
            plainIssues.isEmpty ? nil : "Проблеми: \(plainIssues)",
            plainGoals.isEmpty ? nil : "Цілі: \(plainGoals)"
        ]
        .compactMap { $0 }
        .joined(separator: "\n\n")

        do {
            try await noteRepo.createOrUpdateAnamnesis(
                clientId: clientId,
                background: background,
                presentingIssues: issues,
                treatmentGoals: goals,
                plainTextSummary: plainTextSummary
            )

            HapticService.notification(.success)
            dismiss()
        } catch {
            HapticService.notification(.error)
            #if DEBUG
            print("AnamnesisEditor: Failed to save anamnesis: \(error)")
            #endif
        }
    }
}

private enum AnamnesisSection: CaseIterable {
    case background
    case issues
    case goals

    var shortTitle: String {
        switch self {
        case .background: "Анамнез"
        case .issues: "Проблеми"
        case .goals: "Цілі"
        }
    }

    var fullTitle: String {
        switch self {
        case .background: "Сімейна/медична історія"
        case .issues: "Поточні проблеми"
        case .goals: "Цілі терапії"
        }
    }
}

#Preview {
    AnamnesisEditor(
        clientId: "client-1",
        clientName: "Іван Петренко"
    )
    .environment(SessionNoteRepository())
}
