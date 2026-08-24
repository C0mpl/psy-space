//
//  TherapistFlow.swift
//  Seans
//
//  Created by Claude on 23.08.2026.
//

import SwiftUI

struct TherapistFlow: View {
    @Environment(UserRepository.self) private var userRepo
    @State private var selectedTab: TherapistTab = .schedule

    var body: some View {
        TabView(selection: $selectedTab) {
            ScheduleTab()
                .tabItem { Label("Розклад", systemImage: "calendar") }
                .tag(TherapistTab.schedule)

            ClientsTab()
                .tabItem { Label("Клієнти", systemImage: "person.2") }
                .tag(TherapistTab.clients)

            TherapistProfileTab()
                .tabItem { Label("Профіль", systemImage: "person.circle") }
                .tag(TherapistTab.profile)
        }
    }
}

#Preview {
    TherapistFlow()
        .environment(UserRepository())
}
