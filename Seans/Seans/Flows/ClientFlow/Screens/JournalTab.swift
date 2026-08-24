//
//  JournalTab.swift
//  Seans
//
//  Created by Claude on 23.08.2026.
//

import SwiftUI

struct JournalTab: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    Spacer(minLength: Spacing.xxl)

                    ZStack {
                        Circle()
                            .fill(Color.seansSecondary.opacity(0.1))
                            .frame(width: 140, height: 140)

                        Circle()
                            .fill(Color.seansSecondary.opacity(0.2))
                            .frame(width: 100, height: 100)

                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.seansSecondary)
                    }

                    VStack(spacing: Spacing.sm) {
                        Text("Ваш щоденник")
                            .font(.title2.bold())
                            .foregroundStyle(Color.seansTextPrimary)

                        Text("Приватний простір для рефлексії,\nусвідомлення та зростання")
                            .font(.body)
                            .foregroundStyle(Color.seansTextSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }

                    Button {
                        // TODO: Create new entry
                    } label: {
                        Label("Новий запис", systemImage: "plus")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(Color.seansSecondary)
                            .clipShape(.rect(cornerRadius: CornerRadius.md))
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.md)

                    Spacer(minLength: Spacing.xxl)
                }
                .frame(maxWidth: .infinity)
            }
            .background(Color.seansBackground)
            .navigationTitle("Щоденник")
        }
    }
}

#Preview {
    JournalTab()
}
