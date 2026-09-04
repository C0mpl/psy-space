//
//  ClientFlow.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 23.08.2026.
//

import SwiftUI

struct ClientFlow: View {
    @Environment(UserRepository.self) private var userRepo
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab: ClientTab = .booking
    @State private var journalRepo = JournalRepository()
    @State private var journalPreferences = JournalPreferences()
    @State private var homeworkRepo = HomeworkRepository()
    @State private var notificationPrefs = NotificationPreferences()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Запис", systemImage: "calendar", value: ClientTab.booking) {
                BookingTab()
            }

            Tab("Завдання", systemImage: "doc.text.fill", value: ClientTab.homework) {
                HomeworkTab()
            }

            Tab("Щоденник", systemImage: "book.closed", value: ClientTab.journal) {
                JournalTab()
            }

            Tab("Профіль", systemImage: "person.circle", value: ClientTab.profile) {
                ClientProfileTab()
            }
        }
        .environment(journalRepo)
        .environment(journalPreferences)
        .environment(homeworkRepo)
        .environment(notificationPrefs)
        .onChange(of: selectedTab) { oldValue, newValue in
            if oldValue == .journal && newValue != .journal {
                journalPreferences.lockIfNeeded()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                journalPreferences.lockIfNeeded()
            }
        }
    }
}

#Preview {
    ClientFlow()
        .environment(UserRepository())
        .environment(BookingRepository())
        .environment(PrivacyPreferences())
}
