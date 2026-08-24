//
//  ClientFlow.swift
//  Seans
//
//  Created by Claude on 23.08.2026.
//

import SwiftUI

struct ClientFlow: View {
    @Environment(UserRepository.self) private var userRepo
    @State private var selectedTab: ClientTab = .booking

    var body: some View {
        TabView(selection: $selectedTab) {
            BookingTab()
                .tabItem { Label("Запис", systemImage: "calendar") }
                .tag(ClientTab.booking)

            JournalTab()
                .tabItem { Label("Щоденник", systemImage: "book.closed") }
                .tag(ClientTab.journal)

            ClientProfileTab()
                .tabItem { Label("Профіль", systemImage: "person.circle") }
                .tag(ClientTab.profile)
        }
    }
}

#Preview {
    ClientFlow()
        .environment(UserRepository())
}
