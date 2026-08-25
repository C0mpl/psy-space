//
//  CancelBookingSheet.swift
//  Seans
//
//  Created by Claude on 24.08.2026.
//

import SwiftUI

struct CancelBookingSheet: View {
    @Environment(\.dismiss) private var dismiss

    let booking: Booking
    @Binding var reason: String
    let title: String
    let message: String
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "calendar.badge.minus")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.red.opacity(0.8))

                        Text(title)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.seansTextPrimary)

                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(Color.seansTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, Spacing.md)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Причина (необов'язково)")
                            .font(.subheadline)
                            .foregroundStyle(Color.seansTextSecondary)

                        TextField("Напишіть причину скасування...", text: $reason, axis: .vertical)
                            .textFieldStyle(.plain)
                            .padding(Spacing.md)
                            .background(Color.seansCardBackground)
                            .clipShape(.rect(cornerRadius: CornerRadius.md))
                            .lineLimit(3...6)
                    }

                    VStack(spacing: Spacing.sm) {
                        Button(role: .destructive) {
                            onConfirm()
                        } label: {
                            Text("Скасувати запис")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.md)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)

                        Button {
                            dismiss()
                        } label: {
                            Text("Назад")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.md)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color.seansBackground)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    CancelBookingSheet(
        booking: Booking(
            clientId: "1",
            clientName: "Тест",
            date: .now,
            startTime: .now,
            endTime: .now
        ),
        reason: .constant(""),
        title: "Скасувати сеанс",
        message: "Сеанс з Тест на 24 серп. о 10:00"
    ) {}
}
