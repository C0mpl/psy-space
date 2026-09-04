//
//  PrivacySettingsView.swift
//  Seans
//
//  Created by Claude on 04.09.2026.
//

import SwiftUI

struct PrivacySettingsView: View {
    @Environment(PrivacyPreferences.self) private var preferences
    @Environment(UserRepository.self) private var userRepo

    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteSecondConfirmation = false
    @State private var isDeleting = false

    var body: some View {
        List {
            crashReportsSection
            dataStorageSection
            accountSection
        }
        .navigationTitle("Конфіденційність")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Видалити акаунт?", isPresented: $showingDeleteConfirmation) {
            Button("Скасувати", role: .cancel) {}
            Button("Продовжити", role: .destructive) {
                showingDeleteSecondConfirmation = true
            }
        } message: {
            Text("Усі ваші дані буде видалено назавжди. Цю дію неможливо скасувати.")
        }
        .alert("Ви впевнені?", isPresented: $showingDeleteSecondConfirmation) {
            Button("Скасувати", role: .cancel) {}
            Button("Видалити назавжди", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("Це остаточне видалення. Усі записи в щоденнику, історія сеансів та персональні дані будуть втрачені.")
        }
    }

    // MARK: - Crash Reports Section

    @ViewBuilder
    private var crashReportsSection: some View {
        @Bindable var prefs = preferences

        Section {
            Toggle(isOn: $prefs.crashReportsEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Звіти про збої")
                        Text("Допоможіть покращити стабільність додатку")
                            .font(.caption)
                            .foregroundStyle(Color.seansTextSecondary)
                    }
                } icon: {
                    Image(systemName: "ladybug")
                }
            }
            .tint(Color.seansSecondary)
        } header: {
            Text("Діагностика")
        } footer: {
            Text("Звіти про збої допомагають виявляти та виправляти помилки. Персональні дані не збираються.")
        }
    }

    // MARK: - Data Storage Section

    @ViewBuilder
    private var dataStorageSection: some View {
        Section {
            HStack {
                Label {
                    Text("Зберігання даних")
                } icon: {
                    Image(systemName: "externaldrive")
                }

                Spacer()

                Text("Firebase")
                    .foregroundStyle(Color.seansTextSecondary)
            }

            HStack {
                Label {
                    Text("Шифрування")
                } icon: {
                    Image(systemName: "lock.shield")
                }

                Spacer()

                Text("TLS 1.3")
                    .foregroundStyle(Color.seansTextSecondary)
            }

            HStack {
                Label {
                    Text("Регіон")
                } icon: {
                    Image(systemName: "globe.europe.africa")
                }

                Spacer()

                Text("Європа")
                    .foregroundStyle(Color.seansTextSecondary)
            }
        } header: {
            Text("Зберігання та безпека")
        } footer: {
            Text("Ваші дані зберігаються на серверах Google Firebase в Європі з шифруванням при передачі та в спокої.")
        }
    }

    // MARK: - Account Section

    @ViewBuilder
    private var accountSection: some View {
        Section {
            NavigationLink {
                DataExportView()
            } label: {
                Label {
                    Text("Експорт даних")
                } icon: {
                    Image(systemName: "square.and.arrow.up")
                }
            }

            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Label {
                        Text("Видалити акаунт")
                    } icon: {
                        Image(systemName: "trash")
                    }

                    Spacer()

                    if isDeleting {
                        ProgressView()
                    }
                }
            }
            .disabled(isDeleting)
        } header: {
            Text("Керування даними")
        } footer: {
            Text("Видалення акаунту призведе до безповоротної втрати всіх даних, включаючи записи щоденника, історію сеансів та налаштування.")
        }
    }

    // MARK: - Actions

    private func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }

        // TODO: Implement actual account deletion via UserRepository
        // This should:
        // 1. Delete all user data from Firestore
        // 2. Delete user from Firebase Auth
        // 3. Clear local storage
        // 4. Sign out

        try? await Task.sleep(for: .seconds(1))
        userRepo.signOut()
    }
}

// MARK: - Data Export View

private struct DataExportView: View {
    @State private var isExporting = false
    @State private var exportComplete = false

    var body: some View {
        List {
            Section {
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("Записи щоденника")
                            Text("Усі записи з настроєм та нотатками")
                                .font(.caption)
                                .foregroundStyle(Color.seansTextSecondary)
                        }
                    } icon: {
                        Image(systemName: "book.closed")
                    }

                    Spacer()

                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.seansSecondary)
                }

                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("Історія сеансів")
                            Text("Дати та деталі записів")
                                .font(.caption)
                                .foregroundStyle(Color.seansTextSecondary)
                        }
                    } icon: {
                        Image(systemName: "calendar")
                    }

                    Spacer()

                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.seansSecondary)
                }

                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("Домашні завдання")
                            Text("Завдання та ваші відповіді")
                                .font(.caption)
                                .foregroundStyle(Color.seansTextSecondary)
                        }
                    } icon: {
                        Image(systemName: "doc.text")
                    }

                    Spacer()

                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.seansSecondary)
                }
            } header: {
                Text("Дані для експорту")
            }

            Section {
                Button {
                    exportData()
                } label: {
                    HStack {
                        Spacer()
                        if isExporting {
                            ProgressView()
                                .padding(.trailing, Spacing.xs)
                            Text("Експортуємо...")
                        } else if exportComplete {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.seansSuccess)
                                .padding(.trailing, Spacing.xs)
                            Text("Готово")
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .padding(.trailing, Spacing.xs)
                            Text("Експортувати як JSON")
                        }
                        Spacer()
                    }
                }
                .disabled(isExporting)
            } footer: {
                Text("Дані будуть збережені у форматі JSON, який можна відкрити в будь-якому текстовому редакторі.")
            }
        }
        .navigationTitle("Експорт даних")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func exportData() {
        isExporting = true

        // TODO: Implement actual data export
        // This should collect all user data and create a shareable JSON file

        Task {
            try? await Task.sleep(for: .seconds(2))
            isExporting = false
            exportComplete = true
        }
    }
}

#Preview {
    NavigationStack {
        PrivacySettingsView()
            .environment(PrivacyPreferences())
            .environment(UserRepository())
    }
}
