//
//  ClientFlow.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 23.08.2026.
//

import SwiftUI

struct ClientFlow: View {
    @Environment(UserRepository.self) private var userRepo
    @State private var selectedTab: ClientTab = .booking

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Запис", systemImage: "calendar", value: ClientTab.booking) {
                BookingTab()
            }

            Tab("Щоденник", systemImage: "book.closed", value: ClientTab.journal) {
                JournalTab()
            }

            Tab("Профіль", systemImage: "person.circle", value: ClientTab.profile) {
                ClientProfileTab()
            }
        }
    }
}

#Preview {
    ClientFlow()
        .environment(UserRepository())
}
