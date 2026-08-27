//
//  TherapistFlow.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 23.08.2026.
//

import SwiftUI

struct TherapistFlow: View {
    @Environment(UserRepository.self) private var userRepo
    @State private var selectedTab: TherapistTab = .schedule

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Розклад", systemImage: "calendar", value: TherapistTab.schedule) {
                ScheduleTab()
            }

            Tab("Клієнти", systemImage: "person.2", value: TherapistTab.clients) {
                ClientsTab()
            }

            Tab("Профіль", systemImage: "person.circle", value: TherapistTab.profile) {
                TherapistProfileTab()
            }
        }
    }
}

#Preview {
    TherapistFlow()
        .environment(UserRepository())
}
