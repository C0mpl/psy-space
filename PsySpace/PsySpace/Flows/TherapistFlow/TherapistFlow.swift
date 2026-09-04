//
//  TherapistFlow.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 23.08.2026.
//

import SwiftUI

struct TherapistFlow: View {
    @Environment(UserRepository.self) private var userRepo
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedTab: TherapistTab = .schedule
    @State private var notificationPrefs = NotificationPreferences()

    var body: some View {
        AdaptiveContainer {
            compactLayout
        } regular: {
            regularLayout
        }
        .environment(notificationPrefs)
    }

    // MARK: - iPhone Layout (TabView)

    private var compactLayout: some View {
        TabView(selection: $selectedTab) {
            Tab(TherapistTab.schedule.title, systemImage: TherapistTab.schedule.systemImage, value: TherapistTab.schedule) {
                ScheduleTab()
            }

            Tab(TherapistTab.clients.title, systemImage: TherapistTab.clients.systemImage, value: TherapistTab.clients) {
                ClientsTab()
            }

            Tab(TherapistTab.profile.title, systemImage: TherapistTab.profile.systemImage, value: TherapistTab.profile) {
                TherapistProfileTab()
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
            ForEach(TherapistTab.allCases) { tab in
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
        case .schedule:
            ScheduleTab()
        case .clients:
            ClientsTab()
        case .profile:
            TherapistProfileTab()
        }
    }
}

#Preview {
    TherapistFlow()
        .environment(UserRepository())
}
