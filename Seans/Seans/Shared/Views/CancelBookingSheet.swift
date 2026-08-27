//
//  CancelBookingSheet.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 24.08.2026.
//

import SwiftUI

struct CancelBookingSheet: View {
    @Environment(\.dismiss) private var dismiss

    let booking: Booking
    @Binding var reason: String
    let title: String
    let message: String
    let isTherapist: Bool
    let onConfirm: (_ refund: Bool) -> Void

    @State private var shouldRefund = true

    private var monobankPaidAmount: Int {
        booking.paidAmount ?? 0
    }

    private var usedCreditAmount: Int {
        booking.usedCreditAmount ?? 0
    }

    private var hasAnyPayment: Bool {
        monobankPaidAmount > 0 || usedCreditAmount > 0
    }

    private var willGetCredit: Bool {
        booking.canCancelWithCredit && hasAnyPayment
    }

    private var hoursRemaining: Int {
        max(0, Int(booking.hoursUntilSession))
    }

    private var paidAmountUAH: Int {
        monobankPaidAmount / 100
    }

    private var usedCreditUAH: Int {
        usedCreditAmount / 100
    }

    private var totalAmountUAH: Int {
        paidAmountUAH + usedCreditUAH
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "calendar.badge.minus")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.seansError)

                        Text(title)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.seansTextPrimary)

                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(Color.seansTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, Spacing.md)

                    if hasAnyPayment {
                        if isTherapist {
                            therapistRefundCard
                        } else {
                            clientCreditPolicyCard
                        }
                    }

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
                        Button {
                            HapticService.notification(.warning)
                            onConfirm(isTherapist && shouldRefund)
                        } label: {
                            Text("Скасувати запис")
                        }
                        .buttonStyle(SeansDestructiveButtonStyle())

                        Button {
                            dismiss()
                        } label: {
                            Text("Назад")
                        }
                        .buttonStyle(SeansSecondaryButtonStyle())
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

    @ViewBuilder
    private var therapistRefundCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "creditcard.fill")
                    .foregroundStyle(Color.seansPrimary)

                Text("Повернення оплати")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.seansTextPrimary)

                Spacer()

                Text("\(totalAmountUAH) ₴")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.seansTextPrimary)
            }

            if monobankPaidAmount > 0 && usedCreditAmount > 0 {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text("Картка:")
                            .foregroundStyle(Color.seansTextSecondary)
                        Spacer()
                        Text("\(paidAmountUAH) ₴")
                    }
                    HStack {
                        Text("Кредит:")
                            .foregroundStyle(Color.seansTextSecondary)
                        Spacer()
                        Text("\(usedCreditUAH) ₴")
                    }
                }
                .font(.caption)
            }

            if monobankPaidAmount > 0 {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Toggle(isOn: $shouldRefund) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Повернути на картку")
                                .font(.subheadline)
                                .foregroundStyle(Color.seansTextPrimary)

                            if usedCreditAmount > 0 {
                                Text("Картка: \(paidAmountUAH) ₴ + кредит: \(usedCreditUAH) ₴")
                                    .font(.caption)
                                    .foregroundStyle(Color.seansTextSecondary)
                            } else {
                                Text("Кошти повернуться на картку клієнта")
                                    .font(.caption)
                                    .foregroundStyle(Color.seansTextSecondary)
                            }
                        }
                    }
                    .tint(Color.seansPrimary)

                    if !shouldRefund {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "info.circle.fill")
                                .font(.caption)
                            Text("Все збережеться як кредит клієнта")
                                .font(.caption)
                        }
                        .foregroundStyle(Color.seansTextSecondary)
                    }
                }
            } else {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.seansSuccess)
                    Text("Кредит \(usedCreditUAH) ₴ буде відновлено")
                        .font(.subheadline)
                        .foregroundStyle(Color.seansTextPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Color.seansPrimary.opacity(0.1))
        .clipShape(.rect(cornerRadius: CornerRadius.md))
    }

    @ViewBuilder
    private var clientCreditPolicyCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: willGetCredit ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(willGetCredit ? Color.seansSuccess : Color.seansWarning)

                Text(willGetCredit ? "Кредит буде збережено" : "Кредит не буде збережено")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.seansTextPrimary)

                Spacer()

                Text("\(totalAmountUAH) ₴")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.seansTextPrimary)
            }

            if willGetCredit {
                Text("До сеансу залишилось більше 24 годин (\(hoursRemaining) год.). Оплата буде збережена як кредит для наступного бронювання.")
                    .font(.caption)
                    .foregroundStyle(Color.seansTextSecondary)
            } else {
                Text("До сеансу залишилось менше 24 годин (\(hoursRemaining) год.). Відповідно до політики скасування, оплата не повертається.")
                    .font(.caption)
                    .foregroundStyle(Color.seansTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(willGetCredit ? Color.seansSuccess.opacity(0.1) : Color.seansWarning.opacity(0.1))
        .clipShape(.rect(cornerRadius: CornerRadius.md))
    }
}

#Preview("Client - Credit") {
    CancelBookingSheet(
        booking: Booking(
            clientId: "1",
            clientName: "Тест",
            date: .now.addingTimeInterval(86400 * 2),
            startTime: .now.addingTimeInterval(86400 * 2),
            endTime: .now.addingTimeInterval(86400 * 2 + 3600),
            paidAmount: 150000
        ),
        reason: .constant(""),
        title: "Скасувати запис",
        message: "Сеанс з Тест на 24 серп. о 10:00",
        isTherapist: false
    ) { _ in }
}

#Preview("Therapist - Refund") {
    CancelBookingSheet(
        booking: Booking(
            clientId: "1",
            clientName: "Тест",
            date: .now.addingTimeInterval(86400 * 2),
            startTime: .now.addingTimeInterval(86400 * 2),
            endTime: .now.addingTimeInterval(86400 * 2 + 3600),
            paidAmount: 150000
        ),
        reason: .constant(""),
        title: "Скасувати сеанс",
        message: "Сеанс з Тест на 24 серп. о 10:00",
        isTherapist: true
    ) { _ in }
}
