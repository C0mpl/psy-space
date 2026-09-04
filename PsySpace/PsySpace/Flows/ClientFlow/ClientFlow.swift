//
//  ClientFlow.swift
//  PsySpace
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
        AdaptiveContainer {
            compactLayout
        } regular: {
            regularLayout
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

    // MARK: - iPhone Layout (TabView)

    private var compactLayout: some View {
        TabView(selection: $selectedTab) {
            Tab(ClientTab.booking.title, systemImage: ClientTab.booking.systemImage, value: ClientTab.booking) {
                BookingTab()
            }

            Tab(ClientTab.homework.title, systemImage: ClientTab.homework.systemImage, value: ClientTab.homework) {
                HomeworkTab()
            }

            Tab(ClientTab.journal.title, systemImage: ClientTab.journal.systemImage, value: ClientTab.journal) {
                JournalTab()
            }

            Tab(ClientTab.profile.title, systemImage: ClientTab.profile.systemImage, value: ClientTab.profile) {
                ClientProfileTab()
            }
        }
    }

    // MARK: - iPad Layout (NavigationSplitView)

    private var regularLayout: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var sidebarContent: some View {
        List {
            ForEach(ClientTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Label(tab.title, systemImage: tab.systemImage)
                }
                .listRowBackground(selectedTab == tab ? Color.psyspacePrimary.opacity(0.15) : Color.clear)
                .foregroundStyle(selectedTab == tab ? Color.psyspacePrimary : Color.psyspaceTextPrimary)
            }
        }
        .navigationTitle("PsySpace")
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedTab {
        case .booking:
            BookingTab()
        case .homework:
            HomeworkTab()
        case .journal:
            JournalTab()
        case .profile:
            ClientProfileTab()
        }
    }
}

#Preview {
    ClientFlow()
        .environment(UserRepository())
        .environment(BookingRepository())
        .environment(PrivacyPreferences())
}
