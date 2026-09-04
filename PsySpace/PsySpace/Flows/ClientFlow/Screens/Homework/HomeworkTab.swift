//
//  HomeworkTab.swift
//  PsySpace
//
//  Created by Claude on 03.09.2026.
//

import SwiftUI

struct HomeworkTab: View {
    @Environment(UserRepository.self) private var userRepo
    @Environment(HomeworkRepository.self) private var homeworkRepo

    @State private var selectedHomework: Homework?

    private var clientId: String? { userRepo.currentUser?.id }

    private var pendingHomework: [Homework] {
        homeworkRepo.homework.filter { hw in
            let response = homeworkRepo.response(forHomeworkId: hw.homeworkId)
            return response?.isCompleted != true
        }
    }

    private var completedHomework: [Homework] {
        homeworkRepo.homework.filter { hw in
            let response = homeworkRepo.response(forHomeworkId: hw.homeworkId)
            return response?.isCompleted == true
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if homeworkRepo.homework.isEmpty {
                    emptyView
                } else {
                    homeworkList
                }
            }
            .background(Color.psyspaceBackground)
            .navigationTitle("Завдання")
            .adaptiveSheet(item: $selectedHomework, detents: [.large]) { homework in
                if let clientId {
                    ClientHomeworkDetailSheet(
                        homework: homework,
                        clientId: clientId,
                        existingResponse: homeworkRepo.response(forHomeworkId: homework.homeworkId)
                    )
                }
            }
            .onAppear {
                startListeningIfNeeded()
            }
        }
    }

    private var emptyView: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                Spacer(minLength: Spacing.xxl)

                ZStack {
                    Circle()
                        .fill(Color.psyspacePrimary.opacity(0.1))
                        .frame(width: 140, height: 140)

                    Circle()
                        .fill(Color.psyspacePrimary.opacity(0.2))
                        .frame(width: 100, height: 100)

                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.psyspacePrimary)
                }

                VStack(spacing: Spacing.sm) {
                    Text("Немає завдань")
                        .font(.title2.bold())
                        .foregroundStyle(Color.psyspaceTextPrimary)

                    Text("Коли терапевт призначить\nдомашнє завдання, воно з'явиться тут")
                        .font(.body)
                        .foregroundStyle(Color.psyspaceTextSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                Spacer(minLength: Spacing.xxl)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var homeworkList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.lg) {
                if !pendingHomework.isEmpty {
                    pendingSection
                }

                if !completedHomework.isEmpty {
                    completedSection
                }
            }
            .padding()
        }
    }

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Активні")
                    .font(.headline)
                    .foregroundStyle(Color.psyspaceTextPrimary)

                Spacer()

                Text("\(pendingHomework.count)")
                    .font(.caption)
                    .foregroundStyle(Color.psyspaceTextSecondary)
            }

            LazyVGrid(columns: AdaptiveGridConfig.cards.columns, spacing: AdaptiveGridConfig.cards.spacing) {
                ForEach(pendingHomework) { homework in
                    ClientHomeworkCard(
                        homework: homework,
                        response: homeworkRepo.response(forHomeworkId: homework.homeworkId)
                    ) {
                        selectedHomework = homework
                    }
                }
            }
        }
    }

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Виконані")
                    .font(.headline)
                    .foregroundStyle(Color.psyspaceTextPrimary)

                Spacer()

                Text("\(completedHomework.count)")
                    .font(.caption)
                    .foregroundStyle(Color.psyspaceTextSecondary)
            }

            LazyVGrid(columns: AdaptiveGridConfig.cards.columns, spacing: AdaptiveGridConfig.cards.spacing) {
                ForEach(completedHomework) { homework in
                    ClientHomeworkCard(
                        homework: homework,
                        response: homeworkRepo.response(forHomeworkId: homework.homeworkId)
                    ) {
                        selectedHomework = homework
                    }
                }
            }
        }
    }

    private func startListeningIfNeeded() {
        guard let clientId else { return }
        homeworkRepo.startListeningToMyHomework(clientId: clientId)
        homeworkRepo.startListeningToMyResponses(clientId: clientId)
    }
}

#Preview {
    HomeworkTab()
        .environment(UserRepository())
        .environment(HomeworkRepository())
}
