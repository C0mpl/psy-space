//
//  ClientHomeworkSection.swift
//  Seans
//
//  Created by Claude on 03.09.2026.
//

import SwiftUI

struct ClientHomeworkSection: View {
    let clientId: String

    @State private var homeworkRepo = HomeworkRepository()
    @State private var selectedHomeworkId: String?
    @State private var editingHomeworkId: String?
    @State private var showNewHomeworkEditor = false

    private var activeHomework: [Homework] {
        homeworkRepo.homework.filter { $0.status == .active }
    }

    private var selectedHomework: Homework? {
        guard let id = selectedHomeworkId else { return nil }
        return homeworkRepo.homework(withId: id)
    }

    private var editingHomework: Homework? {
        guard let id = editingHomeworkId else { return nil }
        return homeworkRepo.homework(withId: id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader

            if activeHomework.isEmpty {
                emptyState
            } else {
                homeworkList
            }

            AddHomeworkCard {
                showNewHomeworkEditor = true
            }
        }
        .onAppear {
            homeworkRepo.startListeningToHomework(forClientId: clientId)
            homeworkRepo.startListeningToSharedResponses(forClientId: clientId)
        }
        .onDisappear {
            homeworkRepo.stopListening()
        }
        .sheet(isPresented: Binding(
            get: { selectedHomeworkId != nil },
            set: { if !$0 { selectedHomeworkId = nil } }
        )) {
            if let homework = selectedHomework {
                HomeworkDetailSheet(
                    homework: homework,
                    response: homeworkRepo.response(forHomeworkId: homework.homeworkId)
                ) {
                    editingHomeworkId = homework.homeworkId
                }
                .environment(homeworkRepo)
            }
        }
        .sheet(isPresented: Binding(
            get: { editingHomeworkId != nil },
            set: { if !$0 { editingHomeworkId = nil } }
        )) {
            if let homework = editingHomework {
                HomeworkEditor(
                    clientId: clientId,
                    existingHomework: homework
                )
                .environment(homeworkRepo)
            }
        }
        .sheet(isPresented: $showNewHomeworkEditor) {
            HomeworkEditor(clientId: clientId)
                .environment(homeworkRepo)
        }
    }

    private var sectionHeader: some View {
        HStack {
            Label("Домашні завдання", systemImage: "doc.text.fill")
                .font(.headline)
                .foregroundStyle(Color.seansTextPrimary)

            Spacer()

            let activeCount = activeHomework.count
            let completedCount = homeworkRepo.responses.filter { $0.isCompleted }.count
            if activeCount > 0 {
                Text("\(completedCount)/\(activeCount)")
                    .font(.caption)
                    .foregroundStyle(Color.seansTextSecondary)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color.seansTextSecondary.opacity(0.5))

            Text("Немає активних завдань")
                .font(.subheadline)
                .foregroundStyle(Color.seansTextSecondary)

            Text("Додайте домашнє завдання для клієнта")
                .font(.caption)
                .foregroundStyle(Color.seansTextSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
    }

    private var homeworkList: some View {
        LazyVStack(spacing: Spacing.sm) {
            ForEach(activeHomework) { homework in
                HomeworkCard(
                    homework: homework,
                    response: homeworkRepo.response(forHomeworkId: homework.homeworkId)
                ) {
                    selectedHomeworkId = homework.homeworkId
                }
            }
        }
    }
}

#Preview {
    ClientHomeworkSection(clientId: "test-client")
        .padding()
        .background(Color.seansBackground)
}
