//
//  ClientAnamnesisSection.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 28.08.2026.
//

import SwiftUI

struct ClientAnamnesisSection: View {
    let clientId: String
    let clientName: String

    @State private var noteRepo = SessionNoteRepository()
    @State private var isExpanded = true
    @State private var showEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader

            if isExpanded {
                anamnesisContent
            }
        }
        .animation(SeansAnimation.standard, value: isExpanded)
        .onAppear {
            noteRepo.startListening(forClientId: clientId)
        }
        .onDisappear {
            noteRepo.stopListening()
        }
        .sheet(isPresented: $showEditor) {
            AnamnesisEditor(
                clientId: clientId,
                clientName: clientName,
                existingAnamnesis: noteRepo.anamnesis
            )
            .environment(noteRepo)
        }
    }

    private var sectionHeader: some View {
        Button {
            withAnimation(SeansAnimation.standard) {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                Label("Анамнез", systemImage: "doc.text")
                    .font(.headline)
                    .foregroundStyle(Color.seansTextPrimary)

                Spacer()

                if let anamnesis = noteRepo.anamnesis, !anamnesis.isEmpty {
                    Text("Оновлено: \(anamnesis.updatedAtFormatted)")
                        .font(.caption)
                        .foregroundStyle(Color.seansTextSecondary)
                }

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(Color.seansTextSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var anamnesisContent: some View {
        if let anamnesis = noteRepo.anamnesis, !anamnesis.isEmpty {
            existingAnamnesisView(anamnesis)
        } else {
            emptyAnamnesisView
        }
    }

    private func existingAnamnesisView(_ anamnesis: ClientAnamnesis) -> some View {
        Button {
            showEditor = true
        } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if !extractPlainText(from: anamnesis.background).isEmpty {
                    anamnesisField(title: "Анамнез", content: extractPlainText(from: anamnesis.background))
                }

                if !extractPlainText(from: anamnesis.presentingIssues).isEmpty {
                    anamnesisField(title: "Проблеми", content: extractPlainText(from: anamnesis.presentingIssues))
                }

                if !extractPlainText(from: anamnesis.treatmentGoals).isEmpty {
                    anamnesisField(title: "Цілі", content: extractPlainText(from: anamnesis.treatmentGoals))
                }

                HStack {
                    Spacer()
                    Label("Редагувати", systemImage: "pencil")
                        .font(.caption)
                        .foregroundStyle(Color.seansSecondary)
                }
            }
            .padding(Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.seansCardBackground)
            .clipShape(.rect(cornerRadius: CornerRadius.sm))
        }
        .buttonStyle(.plain)
    }

    private func anamnesisField(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.seansSecondary)

            Text(content)
                .font(.subheadline)
                .foregroundStyle(Color.seansTextPrimary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
    }

    private var emptyAnamnesisView: some View {
        Button {
            showEditor = true
        } label: {
            HStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(Color.seansSecondary.opacity(0.1))
                        .frame(width: 40, height: 40)

                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.seansSecondary)
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Додати анамнез")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.seansTextPrimary)

                    Text("Сімейна історія, проблеми, цілі терапії")
                        .font(.caption)
                        .foregroundStyle(Color.seansTextSecondary)
                }

                Spacer()

                Image(systemName: "plus")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.seansSecondary)
            }
            .padding(Spacing.sm)
            .background(Color.seansCardBackground)
            .clipShape(.rect(cornerRadius: CornerRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 1, dash: [6])
                    )
                    .foregroundStyle(Color.seansSecondary.opacity(0.3))
            )
        }
        .buttonStyle(.plain)
    }

    private func extractPlainText(from serialized: String) -> String {
        if let data = Data(base64Encoded: serialized),
           let decoded = try? NSAttributedString(
               data: data,
               options: [.documentType: NSAttributedString.DocumentType.rtf],
               documentAttributes: nil
           ) {
            return decoded.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return serialized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    ClientAnamnesisSection(clientId: "test-client", clientName: "Іван Петренко")
        .padding()
        .background(Color.seansBackground)
}
