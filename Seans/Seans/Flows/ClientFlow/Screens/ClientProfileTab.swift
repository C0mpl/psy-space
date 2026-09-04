//
//  ClientProfileTab.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 23.08.2026.
//

import SwiftUI

struct ClientProfileTab: View {
    @Environment(UserRepository.self) private var userRepo
    @Environment(BookingRepository.self) private var bookingRepo
    @Environment(JournalPreferences.self) private var journalPreferences

    var body: some View {
        NavigationStack {
            List {
                if let user = userRepo.currentUser {
                    profileHeader(for: user)
                }

                journalSection

                Section {
                    NavigationLink {
                        Text("Налаштування")
                    } label: {
                        Label("Налаштування", systemImage: "gearshape")
                    }

                    NavigationLink {
                        NotificationsSettingsView()
                    } label: {
                        Label("Сповіщення", systemImage: "bell")
                    }

                    NavigationLink {
                        PrivacySettingsView()
                    } label: {
                        Label("Конфіденційність", systemImage: "lock.shield")
                    }
                }

                Section {
                    Button("Вийти", role: .destructive, action: signOut)
                }

                #if DEBUG
                Section("Debug") {
                    Button("Перемкнути на терапевта") {
                        userRepo.debugSwitchRole()
                    }
                }
                #endif
            }
            .scrollContentBackground(.hidden)
            .background(Color.seansBackground)
            .navigationTitle("Профіль")
        }
    }

    private func profileHeader(for user: User) -> some View {
        Section {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.seansPrimary.opacity(0.15))
                        .frame(width: 64, height: 64)

                    Image(systemName: "person.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.seansPrimary)
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(user.name)
                        .font(.title3.bold())
                        .foregroundStyle(Color.seansTextPrimary)

                    if let email = user.email {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(Color.seansTextSecondary)
                    }
                }

                Spacer()
            }
            .padding(.vertical, Spacing.xs)
        }
    }

    @ViewBuilder
    private var journalSection: some View {
        @Bindable var prefs = journalPreferences

        Section {
            if BiometricService.shared.isBiometricAvailable {
                Toggle(isOn: $prefs.isBiometricLockEnabled) {
                    Label {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("Захист щоденника")
                            Text("Використовувати \(BiometricService.shared.biometricName)")
                                .font(.caption)
                                .foregroundStyle(Color.seansTextSecondary)
                        }
                    } icon: {
                        Image(systemName: BiometricService.shared.biometricIcon)
                    }
                }
                .tint(Color.seansSecondary)

                if journalPreferences.isBiometricLockEnabled {
                    Toggle(isOn: $prefs.autoLockOnBackground) {
                        Label {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text("Автоблокування")
                                Text("Блокувати при згортанні")
                                    .font(.caption)
                                    .foregroundStyle(Color.seansTextSecondary)
                            }
                        } icon: {
                            Image(systemName: "lock.rotation")
                        }
                    }
                    .tint(Color.seansSecondary)
                }
            }

            Toggle(isOn: $prefs.defaultShareWithTherapist) {
                Label {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Ділитися за замовчуванням")
                        Text("Нові записи будуть видимі терапевту")
                            .font(.caption)
                            .foregroundStyle(Color.seansTextSecondary)
                    }
                } icon: {
                    Image(systemName: "person.2")
                }
            }
            .tint(Color.seansSecondary)
        } header: {
            Text("Щоденник")
        }
    }

    private func signOut() {
        userRepo.signOut()
    }
}

#Preview {
    ClientProfileTab()
        .environment(UserRepository())
        .environment(BookingRepository())
        .environment(JournalPreferences())
        .environment(NotificationPreferences())
        .environment(PrivacyPreferences())
}
