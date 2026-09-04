//
//  NotificationsSettingsView.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 04.09.2026.
//

import SwiftUI
import UserNotifications

struct NotificationsSettingsView: View {
    @Environment(NotificationPreferences.self) private var preferences
    @Environment(UserRepository.self) private var userRepo

    @State private var systemStatus: UNAuthorizationStatus = .notDetermined
    @State private var isCheckingStatus = true

    private var isTherapist: Bool {
        userRepo.currentUser?.isTherapist ?? false
    }

    var body: some View {
        List {
            systemStatusSection

            if systemStatus == .authorized {
                sessionsSection
                remindersSection

                if isTherapist {
                    newBookingsSection
                }
            }
        }
        .navigationTitle("Сповіщення")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await checkSystemStatus()
        }
    }

    // MARK: - System Status Section

    @ViewBuilder
    private var systemStatusSection: some View {
        Section {
            HStack(spacing: Spacing.md) {
                Image(systemName: systemStatusIcon)
                    .font(.title2)
                    .foregroundStyle(systemStatusColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Системні сповіщення")
                        .foregroundStyle(Color.seansTextPrimary)

                    if isCheckingStatus {
                        Text("Перевірка...")
                            .font(.caption)
                            .foregroundStyle(Color.seansTextSecondary)
                    } else {
                        Text(systemStatusText)
                            .font(.caption)
                            .foregroundStyle(systemStatusColor)
                    }
                }

                Spacer()

                if isCheckingStatus {
                    ProgressView()
                } else if systemStatus == .denied {
                    Button("Відкрити налаштування") {
                        openSystemSettings()
                    }
                    .font(.caption)
                    .foregroundStyle(Color.seansPrimary)
                } else if systemStatus == .notDetermined {
                    Button("Увімкнути") {
                        Task { await requestPermission() }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.seansPrimary)
                }
            }
        } header: {
            Text("Статус")
        } footer: {
            if systemStatus == .denied {
                Text("Сповіщення вимкнені на рівні системи. Відкрийте налаштування iOS, щоб увімкнути їх.")
            } else if systemStatus == .notDetermined {
                Text("Дозвольте сповіщення, щоб отримувати нагадування про сеанси та інші важливі події.")
            }
        }
    }

    private var systemStatusIcon: String {
        switch systemStatus {
        case .authorized, .provisional, .ephemeral:
            "bell.badge.fill"
        case .denied:
            "bell.slash.fill"
        case .notDetermined:
            "bell"
        @unknown default:
            "bell"
        }
    }

    private var systemStatusColor: Color {
        switch systemStatus {
        case .authorized, .provisional, .ephemeral:
            .green
        case .denied:
            Color.seansError
        case .notDetermined:
            Color.seansTextSecondary
        @unknown default:
            Color.seansTextSecondary
        }
    }

    private var systemStatusText: String {
        switch systemStatus {
        case .authorized, .provisional, .ephemeral:
            "Увімкнено"
        case .denied:
            "Вимкнено"
        case .notDetermined:
            "Не налаштовано"
        @unknown default:
            "Невідомо"
        }
    }

    // MARK: - Sessions Section

    @ViewBuilder
    private var sessionsSection: some View {
        @Bindable var prefs = preferences

        Section {
            Toggle(isOn: $prefs.bookingConfirmations) {
                Label {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Підтвердження запису")
                        Text("Сповіщення про підтверджені сеанси")
                            .font(.caption)
                            .foregroundStyle(Color.seansTextSecondary)
                    }
                } icon: {
                    Image(systemName: "checkmark.circle")
                }
            }
            .tint(Color.seansSecondary)

            Toggle(isOn: $prefs.cancellationAlerts) {
                Label {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Скасування")
                        Text("Сповіщення про скасовані сеанси")
                            .font(.caption)
                            .foregroundStyle(Color.seansTextSecondary)
                    }
                } icon: {
                    Image(systemName: "xmark.circle")
                }
            }
            .tint(Color.seansSecondary)
        } header: {
            Text("Сеанси")
        }
    }

    // MARK: - Reminders Section

    @ViewBuilder
    private var remindersSection: some View {
        @Bindable var prefs = preferences

        Section {
            Toggle(isOn: $prefs.sessionReminders) {
                Label {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Нагадування про сеанси")
                        Text("Нагадування перед початком сеансу")
                            .font(.caption)
                            .foregroundStyle(Color.seansTextSecondary)
                    }
                } icon: {
                    Image(systemName: "clock")
                }
            }
            .tint(Color.seansSecondary)

            if preferences.sessionReminders {
                Picker(selection: $prefs.reminderTiming) {
                    ForEach(ReminderTiming.allCases) { timing in
                        Text(timing.displayName).tag(timing)
                    }
                } label: {
                    Label {
                        Text("Нагадати за")
                    } icon: {
                        Image(systemName: "timer")
                    }
                }
            }
        } header: {
            Text("Нагадування")
        }
    }

    // MARK: - New Bookings Section (Therapist Only)

    @ViewBuilder
    private var newBookingsSection: some View {
        @Bindable var prefs = preferences

        Section {
            Toggle(isOn: $prefs.newBookingAlerts) {
                Label {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Нові записи")
                        Text("Сповіщення коли клієнт записується")
                            .font(.caption)
                            .foregroundStyle(Color.seansTextSecondary)
                    }
                } icon: {
                    Image(systemName: "person.badge.plus")
                }
            }
            .tint(Color.seansSecondary)
        } header: {
            Text("Нові записи")
        }
    }

    // MARK: - Actions

    private func checkSystemStatus() async {
        isCheckingStatus = true
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        systemStatus = settings.authorizationStatus
        isCheckingStatus = false
    }

    private func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            await checkSystemStatus()
            if granted {
                preferences.isEnabled = true
            }
        } catch {
            #if DEBUG
            print("Failed to request notification permission: \(error)")
            #endif
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    NavigationStack {
        NotificationsSettingsView()
            .environment(NotificationPreferences())
            .environment(UserRepository())
    }
}
