//
//  CalendarSettingsView.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 26.08.2026.
//

import SwiftUI

struct CalendarSettingsView: View {
    @Environment(UserRepository.self) private var userRepo

    @State private var isEnabled = false
    @State private var isRequesting = false
    @State private var availableCalendar: CalendarType?

    private let calendarService = CalendarService.shared

    var body: some View {
        List {
            Section {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "calendar")
                        .font(.title2)
                        .foregroundStyle(Color.seansPrimary)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Google Calendar")
                            .foregroundStyle(Color.seansTextPrimary)

                        if isEnabled {
                            Text("Підключено")
                                .font(.caption)
                                .foregroundStyle(Color.green)
                        } else {
                            Text("Не підключено")
                                .font(.caption)
                                .foregroundStyle(Color.seansTextSecondary)
                        }
                    }

                    Spacer()

                    if isRequesting {
                        ProgressView()
                    } else {
                        Toggle("", isOn: $isEnabled)
                            .labelsHidden()
                    }
                }
                .onChange(of: isEnabled) { _, newValue in
                    Task { await handleToggle(newValue) }
                }
            } header: {
                Text("Календар")
            } footer: {
                if isEnabled {
                    Text("Нові сеанси автоматично додаються до Google Calendar з посиланням на Google Meet. Клієнти отримують запрошення на email.")
                } else {
                    Text("Підключіть Google Calendar, щоб автоматично створювати події для нових сеансів з посиланням на Google Meet.")
                }
            }
        }
        .navigationTitle("Календар")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            isEnabled = userRepo.currentUser?.calendarSyncEnabled ?? false
        }
    }

    private func handleToggle(_ enabled: Bool) async {
        if enabled {
            isRequesting = true

            let granted = await calendarService.requestAccess()

            if granted {
                await userRepo.setCalendarSyncEnabled(true)
            } else {
                isEnabled = false
            }

            isRequesting = false
        } else {
            await userRepo.setCalendarSyncEnabled(false)
        }
    }
}

#Preview {
    NavigationStack {
        CalendarSettingsView()
            .environment(UserRepository())
    }
}
