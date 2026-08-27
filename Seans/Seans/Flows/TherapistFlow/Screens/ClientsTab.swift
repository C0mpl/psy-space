//
//  ClientsTab.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 23.08.2026.
//

import SwiftUI

struct ClientsTab: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    Spacer(minLength: Spacing.xxl)

                    ZStack {
                        Circle()
                            .fill(Color.seansAccent.opacity(0.1))
                            .frame(width: 140, height: 140)

                        Circle()
                            .fill(Color.seansAccent.opacity(0.2))
                            .frame(width: 100, height: 100)

                        Image(systemName: "person.2.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.seansAccent)
                    }

                    VStack(spacing: Spacing.sm) {
                        Text("Ваші клієнти")
                            .font(.title2.bold())
                            .foregroundStyle(Color.seansTextPrimary)

                        Text("Переглядайте профілі, нотатки\nта історію сеансів")
                            .font(.body)
                            .foregroundStyle(Color.seansTextSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }

                    Spacer(minLength: Spacing.xxl)
                }
                .frame(maxWidth: .infinity)
            }
            .background(Color.seansBackground)
            .navigationTitle("Клієнти")
        }
    }
}

#Preview {
    ClientsTab()
}
