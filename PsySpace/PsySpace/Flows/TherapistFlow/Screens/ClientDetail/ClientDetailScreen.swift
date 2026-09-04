//
//  ClientDetailScreen.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 28.08.2026.
//

import SwiftUI

struct ClientDetailScreen: View {
    let clientId: String
    let clientName: String

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                clientHeader

                ClientAnamnesisSection(clientId: clientId, clientName: clientName)

                ClientHomeworkSection(clientId: clientId)

                ClientSessionNotesSection(clientId: clientId, clientName: clientName)

                ClientJournalSection(clientId: clientId, clientName: clientName)
            }
            .padding()
        }
        .background(Color.psyspaceBackground)
        .navigationTitle(clientName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            #if DEBUG
            print("ClientDetailScreen appeared for clientId: \(clientId), name: \(clientName)")
            #endif
        }
    }

    private var clientHeader: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.psyspacePrimary.opacity(0.1))
                    .frame(width: 80, height: 80)

                Text(clientName.prefix(1).uppercased())
                    .font(.title.bold())
                    .foregroundStyle(Color.psyspacePrimary)
            }

            Text(clientName)
                .font(.title2.bold())
                .foregroundStyle(Color.psyspaceTextPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
    }
}

#Preview {
    NavigationStack {
        ClientDetailScreen(clientId: "test-client", clientName: "Іван Петренко")
    }
}
