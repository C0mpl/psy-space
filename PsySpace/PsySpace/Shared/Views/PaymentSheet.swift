//
//  PaymentSheet.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 25.08.2026.
//

import SwiftUI

struct PaymentSheet: View {
    let slot: TimeSlot
    let date: Date
    let priceUAH: Int
    let clientId: String
    let clientName: String
    let userCredit: Int
    let onComplete: (Payment, Int?) -> Void
    let onCancel: () -> Void

    @Environment(PaymentRepository.self) private var paymentRepo
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var payment: Payment?
    @State private var showingError = false
    @State private var errorMessage: String?
    @State private var isTestMode = false
    @State private var useCredit = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: Spacing.md) {
                    bookingInfoCard

                    if hasCredit && payment == nil {
                        creditToggleRow
                    }

                    priceCard
                }
                .padding(Spacing.md)

                Spacer(minLength: Spacing.md)

                VStack(spacing: Spacing.sm) {
                    statusIndicator
                    actionButtons
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.md)
            }
            .background(Color.psyspaceBackground)
            .navigationTitle(isTestMode ? "Оплата (тест)" : "Оплата")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") {
                        paymentRepo.reset()
                        onCancel()
                    }
                    .disabled(paymentRepo.isProcessing || isWaitingForPayment)
                }
            }
            .alert("Помилка", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Не вдалося створити платіж")
            }
            .onChange(of: paymentRepo.currentPayment?.status) { _, newStatus in
                handleStatusChange(newStatus)
            }
            .onDisappear {
                paymentRepo.stopPolling()
            }
            .task {
                isTestMode = await paymentRepo.isTestMode
            }
        }
    }

    private var isWaitingForPayment: Bool {
        payment != nil && payment?.status.isTerminal == false
    }

    private var priceKopiykas: Int {
        priceUAH * 100
    }

    private var userCreditUAH: Int {
        userCredit / 100
    }

    private var hasCredit: Bool {
        userCredit > 0
    }

    private var creditToUse: Int {
        guard useCredit, hasCredit else { return 0 }
        return min(userCredit, priceKopiykas)
    }

    private var creditToUseUAH: Int {
        creditToUse / 100
    }

    private var amountToPay: Int {
        max(0, priceKopiykas - creditToUse)
    }

    private var amountToPayUAH: Int {
        amountToPay / 100
    }

    private var isPaidInFull: Bool {
        amountToPay == 0 && useCredit
    }

    private var bookingInfoCard: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Сеанс")
                    .font(.caption)
                    .foregroundStyle(Color.psyspaceTextSecondary)

                Text(date.formatted(.dateTime.day().month(.wide)))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.psyspaceTextPrimary)

                Text(slot.startTimeFormatted)
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

    private var creditToggleRow: some View {
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

    private var priceCard: some View {
        VStack(spacing: Spacing.sm) {
            if hasCredit && useCredit && creditToUse > 0 {
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

    @ViewBuilder
    private var statusIndicator: some View {
        if isWaitingForPayment {
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

        if payment?.status == .success {
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

        if payment?.status == .failure || payment?.status == .expired {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.circle.fill")
                Text(payment?.status == .expired ? "Час вичерпано" : "Оплата не вдалася")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(Color.psyspaceError)
            .frame(maxWidth: .infinity)
            .padding(Spacing.sm)
            .background(Color.psyspaceError.opacity(0.1))
            .clipShape(.rect(cornerRadius: CornerRadius.md))
        }
    }

    private var actionButtons: some View {
        VStack(spacing: Spacing.sm) {
            if payment == nil {
                if isPaidInFull {
                    Button {
                        confirmWithCreditOnly()
                    } label: {
                        Label("Записатися", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(PsySpacePrimaryButtonStyle())
                } else {
                    Button {
                        initiatePayment()
                    } label: {
                        Label("Оплатити \(amountToPayUAH) \u{20B4}", systemImage: "creditcard.fill")
                    }
                    .buttonStyle(PsySpacePrimaryButtonStyle(isLoading: paymentRepo.isProcessing))
                    .disabled(paymentRepo.isProcessing)
                }

                #if DEBUG
                Button {
                    skipPayment()
                } label: {
                    Text("Пропустити (debug)")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.psyspaceTextSecondary)
                #endif
            } else if let payment, !payment.status.isTerminal {
                if isTestMode {
                    testModeButtons
                } else {
                    Button {
                        openPaymentPage()
                    } label: {
                        Label("Перейти до оплати", systemImage: "arrow.up.right.square.fill")
                    }
                    .buttonStyle(PsySpacePrimaryButtonStyle())
                }
            } else if payment?.status == .success {
                Button {
                    if let payment {
                        onComplete(payment, useCredit ? creditToUse : nil)
                    }
                } label: {
                    Label("Готово", systemImage: "checkmark")
                }
                .buttonStyle(PsySpacePrimaryButtonStyle())
            } else if payment?.status == .failure || payment?.status == .expired {
                Button {
                    retryPayment()
                } label: {
                    Label("Спробувати ще", systemImage: "arrow.clockwise")
                }
                .buttonStyle(PsySpacePrimaryButtonStyle())
            }
        }
    }

    @ViewBuilder
    private var testModeButtons: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                paymentRepo.simulatePaymentSuccess()
                payment?.status = .success
                payment?.paidAt = .now
                HapticService.notification(.success)
            } label: {
                Label("Успіх", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PsySpacePrimaryButtonStyle())

            Button {
                paymentRepo.simulatePaymentFailure()
                payment?.status = .failure
                HapticService.notification(.error)
            } label: {
                Label("Помилка", systemImage: "xmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PsySpaceDestructiveButtonStyle())
        }
    }

    private func confirmWithCreditOnly() {
        let creditPayment = Payment(
            invoiceId: "credit_\(UUID().uuidString.prefix(8))",
            bookingReference: UUID().uuidString,
            amount: 0,
            pageUrl: "",
            status: .success,
            createdAt: .now,
            paidAt: .now
        )
        HapticService.notification(.success)
        onComplete(creditPayment, creditToUse)
    }

    private func initiatePayment() {
        Task {
            do {
                let newPayment = try await paymentRepo.initiatePayment(
                    for: slot,
                    date: date,
                    clientName: clientName,
                    sessionPriceUAH: amountToPayUAH
                )
                payment = newPayment
                HapticService.notification(.success)
                openPaymentPage()
            } catch let paymentError as PaymentError {
                HapticService.notification(.error)
                errorMessage = mapErrorMessage(paymentError)
                showingError = true
            } catch {
                HapticService.notification(.error)
                errorMessage = "Не вдалося створити платіж"
                showingError = true
            }
        }
    }

    private func openPaymentPage() {
        guard let payment, let url = URL(string: payment.pageUrl) else { return }
        paymentRepo.startPolling()
        openURL(url)
    }

    private func retryPayment() {
        paymentRepo.reset()
        payment = nil
        initiatePayment()
    }

    #if DEBUG
    private func skipPayment() {
        let fakePayment = Payment(
            invoiceId: "debug_\(UUID().uuidString.prefix(8))",
            bookingReference: UUID().uuidString,
            amount: priceUAH * 100,
            pageUrl: "",
            status: .success,
            createdAt: .now,
            paidAt: .now
        )
        payment = fakePayment
        paymentRepo.currentPayment = fakePayment
        HapticService.notification(.success)
    }
    #endif

    private func handleStatusChange(_ status: PaymentStatus?) {
        guard let status else { return }

        switch status {
        case .success:
            HapticService.notification(.success)
            payment?.status = .success
        case .failure, .expired:
            HapticService.notification(.error)
            payment?.status = status
        default:
            break
        }
    }

    private func mapErrorMessage(_ error: PaymentError) -> String {
        switch error {
        case .invalidResponse:
            return "Некоректна відповідь від платіжної системи"
        case .networkError:
            return "Помилка мережі. Перевірте підключення до інтернету"
        case .apiError(let message):
            return message
        case .timeout:
            return "Час очікування оплати вичерпано"
        case .cancelled:
            return "Оплату скасовано"
        }
    }
}

#Preview("No Credit") {
    PaymentSheet(
        slot: TimeSlot(
            id: "1",
            date: .now,
            startTime: .now,
            endTime: .now.addingTimeInterval(3600),
            isBooked: false
        ),
        date: .now,
        priceUAH: 1500,
        clientId: "user-1",
        clientName: "Test User",
        userCredit: 0,
        onComplete: { _, _ in },
        onCancel: {}
    )
    .environment(PaymentRepository())
}

#Preview("With Credit") {
    PaymentSheet(
        slot: TimeSlot(
            id: "1",
            date: .now,
            startTime: .now,
            endTime: .now.addingTimeInterval(3600),
            isBooked: false
        ),
        date: .now,
        priceUAH: 1500,
        clientId: "user-1",
        clientName: "Test User",
        userCredit: 100000,
        onComplete: { _, _ in },
        onCancel: {}
    )
    .environment(PaymentRepository())
}

#Preview("Full Credit") {
    PaymentSheet(
        slot: TimeSlot(
            id: "1",
            date: .now,
            startTime: .now,
            endTime: .now.addingTimeInterval(3600),
            isBooked: false
        ),
        date: .now,
        priceUAH: 1500,
        clientId: "user-1",
        clientName: "Test User",
        userCredit: 200000,
        onComplete: { _, _ in },
        onCancel: {}
    )
    .environment(PaymentRepository())
}
