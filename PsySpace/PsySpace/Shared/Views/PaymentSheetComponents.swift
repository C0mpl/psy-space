//
//  PaymentSheetComponents.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 25.08.2026.
//

import SwiftUI

struct PaymentBookingInfoCard: View {
    let date: Date
    let slotTime: String
    let priceUAH: Int

    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Сеанс")
                    .font(.caption)
                    .foregroundStyle(Color.psyspaceTextSecondary)

                Text(date.formatted(.dateTime.day().month(.wide)))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.psyspaceTextPrimary)

                Text(slotTime)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.psyspacePrimary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text("Вартість")
                    .font(.caption)
                    .foregroundStyle(Color.psyspaceTextSecondary)

                Text("\(priceUAH) \u{20B4}")
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color.psyspaceTextPrimary)
            }
        }
        .padding(Spacing.md)
        .background(Color.psyspaceCardBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(Color.psyspacePrimary.opacity(0.2), lineWidth: 1)
        }
    }
}

struct PaymentCreditToggleRow: View {
    let userCreditUAH: Int
    @Binding var useCredit: Bool

    var body: some View {
        HStack {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "wallet.bifold.fill")
                    .foregroundStyle(Color.psyspaceSuccess)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Кредит")
                        .font(.subheadline.weight(.medium))
                    Text("\(userCreditUAH) \u{20B4} доступно")
                        .font(.caption)
                        .foregroundStyle(Color.psyspaceTextSecondary)
                }
            }

            Spacer()

            Toggle("Використати кредит", isOn: $useCredit)
                .labelsHidden()
                .tint(Color.psyspaceSuccess)
                .accessibilityLabel("Використати кредит \(userCreditUAH) гривень")
        }
        .padding(Spacing.sm)
        .background(Color.psyspaceSuccess.opacity(0.08))
        .clipShape(.rect(cornerRadius: CornerRadius.md))
    }
}

struct PaymentPriceCard: View {
    let hasCredit: Bool
    let useCredit: Bool
    let creditToUseUAH: Int
    let amountToPayUAH: Int
    let isPaidInFull: Bool

    var body: some View {
        VStack(spacing: Spacing.sm) {
            if hasCredit && useCredit && creditToUseUAH > 0 {
                HStack {
                    Text("Кредит")
                    Spacer()
                    Text("-\(creditToUseUAH) \u{20B4}")
                        .foregroundStyle(Color.psyspaceSuccess)
                }
                .font(.subheadline)
                .foregroundStyle(Color.psyspaceTextSecondary)

                Divider()
            }

            HStack {
                Text(isPaidInFull ? "Оплачено кредитом" : "До сплати")
                    .font(.subheadline)
                    .foregroundStyle(Color.psyspaceTextSecondary)

                Spacer()

                Text("\(amountToPayUAH) \u{20B4}")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(isPaidInFull ? Color.psyspaceSuccess : Color.psyspacePrimary)
            }
        }
        .padding(Spacing.md)
        .background(Color.psyspaceCardBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.lg))
    }
}

struct PaymentStatusIndicator: View {
    let isWaiting: Bool
    let status: PaymentStatus?

    var body: some View {
        Group {
            if isWaiting {
                waitingView
            }

            if status == .success {
                successView
            }

            if status == .failure || status == .expired {
                failureView
            }
        }
    }

    private var waitingView: some View {
        HStack(spacing: Spacing.sm) {
            ProgressView()
                .tint(Color.psyspacePrimary)
            Text("Очікуємо підтвердження...")
                .font(.subheadline)
                .foregroundStyle(Color.psyspaceTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.sm)
        .background(Color.psyspacePrimary.opacity(0.1))
        .clipShape(.rect(cornerRadius: CornerRadius.md))
    }

    private var successView: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
            Text("Оплата успішна")
                .font(.subheadline.weight(.medium))
        }
        .foregroundStyle(Color.psyspaceSuccess)
        .frame(maxWidth: .infinity)
        .padding(Spacing.sm)
        .background(Color.psyspaceSuccess.opacity(0.1))
        .clipShape(.rect(cornerRadius: CornerRadius.md))
    }

    private var failureView: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
            Text(status == .expired ? "Час вичерпано" : "Оплата не вдалася")
                .font(.subheadline.weight(.medium))
        }
        .foregroundStyle(Color.psyspaceError)
        .frame(maxWidth: .infinity)
        .padding(Spacing.sm)
        .background(Color.psyspaceError.opacity(0.1))
        .clipShape(.rect(cornerRadius: CornerRadius.md))
    }
}

struct PaymentTestModeButtons: View {
    let onSuccess: () -> Void
    let onFailure: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                onSuccess()
            } label: {
                Label("Успіх", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PsySpacePrimaryButtonStyle())

            Button {
                onFailure()
            } label: {
                Label("Помилка", systemImage: "xmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PsySpaceDestructiveButtonStyle())
        }
    }
}
