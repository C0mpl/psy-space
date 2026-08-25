//
//  TherapistProfileTab.swift
//  Seans
//
//  Created by Claude on 23.08.2026.
//

import SwiftUI

struct TherapistProfileTab: View {
    @Environment(UserRepository.self) private var userRepo

    var body: some View {
        NavigationStack {
            List {
                if let user = userRepo.currentUser {
                    profileHeader(for: user)
                }

                Section {
                    NavigationLink {
                        Text("Налаштування доступності")
                    } label: {
                        Label("Доступність", systemImage: "clock")
                    }

                    NavigationLink {
                        Text("Налаштування оплати")
                    } label: {
                        Label("Оплата", systemImage: "creditcard")
                    }

                    NavigationLink {
                        Text("Сповіщення")
                    } label: {
                        Label("Сповіщення", systemImage: "bell")
                    }
                }

                Section {
                    Button("Вийти", role: .destructive, action: signOut)
                }

                #if DEBUG
                Section("Debug") {
                    Button("Перемкнути на клієнта") {
                        userRepo.debugSwitchRole()
                    }
                }
                #endif
            }
            .scrollContentBackground(.hidden)
            .background(Color.seansBackground)
            .navigationTitle("Профіль")
        }
    }

    private func profileHeader(for user: User) -> some View {
        Section {
            HStack(spacing: Spacing.md) {
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        Circle()
                            .fill(Color.seansPrimary.opacity(0.15))
                            .frame(width: 64, height: 64)

                        Image(systemName: "person.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.seansPrimary)
                    }

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.seansAccent)
                        .background(Circle().fill(Color.seansCardBackground).padding(-3))
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(user.name)
                        .font(.title3.bold())
                        .foregroundStyle(Color.seansTextPrimary)

                    if let email = user.email {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(Color.seansTextSecondary)
                    }

                    Text("Терапевт")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.seansAccent)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.xxs)
                        .background(Color.seansAccent.opacity(0.12))
                        .clipShape(.rect(cornerRadius: CornerRadius.sm))
                }

                Spacer()
            }
            .padding(.vertical, Spacing.xs)
        }
    }

    private func signOut() {
        userRepo.signOut()
    }
}

#Preview {
    TherapistProfileTab()
        .environment(UserRepository())
}
