//
//  JournalTab.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 23.08.2026.
//

import SwiftUI

struct JournalTab: View {
    @Environment(UserRepository.self) private var userRepo
    @Environment(JournalRepository.self) private var journalRepo
    @Environment(JournalPreferences.self) private var preferences

    @State private var sheetPresentation: SheetPresentation?
    @State private var isAuthenticating = false

    private var clientId: String? { userRepo.currentUser?.id }

    var body: some View {
        NavigationStack {
            Group {
                if preferences.isLocked {
                    lockedView
                } else if journalRepo.entries.isEmpty {
                    emptyView
                } else {
                    entriesList
                }
            }
            .background(Color.seansBackground)
            .navigationTitle("Щоденник")
            .toolbar {
                if !preferences.isLocked {
                    ToolbarItem(placement: .topBarLeading) {
                        if preferences.isBiometricLockEnabled {
                            Button {
                                preferences.lock()
                            } label: {
                                Image(systemName: "lock")
                                    .foregroundStyle(Color.seansTextSecondary)
                            }
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            sheetPresentation = .newEntry
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(Color.seansPrimary)
                        }
                    }
                }
            }
            .sheet(item: $sheetPresentation) { presentation in
                if let clientId {
                    switch presentation {
                    case .newEntry:
                        JournalEntryEditor(clientId: clientId)
                    case .editEntry(let entry):
                        JournalEntryEditor(clientId: clientId, existingEntry: entry)
                    }
                }
            }
            .onAppear {
                startListeningIfNeeded()
            }
        }
    }

    private var lockedView: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                Spacer(minLength: Spacing.xxl)

                ZStack {
                    Circle()
                        .fill(Color.seansSecondary.opacity(0.1))
                        .frame(width: 140, height: 140)

                    Circle()
                        .fill(Color.seansSecondary.opacity(0.2))
                        .frame(width: 100, height: 100)

                    Image(systemName: BiometricService.shared.biometricIcon)
                        .font(.system(size: 44))
                        .foregroundStyle(Color.seansSecondary)
                }

                VStack(spacing: Spacing.sm) {
                    Text("Щоденник захищено")
                        .font(.title2.bold())
                        .foregroundStyle(Color.seansTextPrimary)

                    Text("Використайте \(BiometricService.shared.biometricName)\nдля розблокування")
                        .font(.body)
                        .foregroundStyle(Color.seansTextSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                Button {
                    Task { await unlock() }
                } label: {
                    Label("Розблокувати", systemImage: BiometricService.shared.biometricIcon)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(Color.seansSecondary)
                        .clipShape(.rect(cornerRadius: CornerRadius.md))
                }
                .disabled(isAuthenticating)
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.md)

                Spacer(minLength: Spacing.xxl)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var emptyView: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                Spacer(minLength: Spacing.xxl)

                ZStack {
                    Circle()
                        .fill(Color.seansSecondary.opacity(0.1))
                        .frame(width: 140, height: 140)

                    Circle()
                        .fill(Color.seansSecondary.opacity(0.2))
                        .frame(width: 100, height: 100)

                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.seansSecondary)
                }

                VStack(spacing: Spacing.sm) {
                    Text("Ваш щоденник")
                        .font(.title2.bold())
                        .foregroundStyle(Color.seansTextPrimary)

                    Text("Приватний простір для рефлексії,\nусвідомлення та зростання")
                        .font(.body)
                        .foregroundStyle(Color.seansTextSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                Button {
                    sheetPresentation = .newEntry
                } label: {
                    Label("Новий запис", systemImage: "plus")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(Color.seansSecondary)
                        .clipShape(.rect(cornerRadius: CornerRadius.md))
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.md)

                Spacer(minLength: Spacing.xxl)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var entriesList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.md) {
                ForEach(journalRepo.entries) { entry in
                    JournalEntryCard(entry: entry) {
                        sheetPresentation = .editEntry(entry)
                    }
                }
            }
            .padding()
        }
    }

    private func startListeningIfNeeded() {
        guard let clientId, !preferences.isLocked else { return }
        journalRepo.startListening(forClientId: clientId)
    }

    private func unlock() async {
        isAuthenticating = true
        defer { isAuthenticating = false }

        let success = await preferences.unlock()
        if success, let clientId {
            journalRepo.startListening(forClientId: clientId)
        }
    }
}

private enum SheetPresentation: Identifiable {
    case newEntry
    case editEntry(JournalEntry)

    var id: String {
        switch self {
        case .newEntry:
            return "new-entry"
        case .editEntry(let entry):
            return "edit-\(entry.entryId)"
        }
    }
}

#Preview {
    JournalTab()
        .environment(UserRepository())
        .environment(JournalRepository())
        .environment(JournalPreferences())
}
