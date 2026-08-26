//
//  PaymentRepository.swift
//  Seans
//
//  Created by Claude on 25.08.2026.
//

import Foundation

@Observable
@MainActor
final class PaymentRepository {
    // MARK: - State

    var currentPayment: Payment?
    var isProcessing = false
    var error: PaymentError?

    // MARK: - Private

    private let monobank = MonobankService.shared
    private let remoteConfig = RemoteConfigService.shared
    private var pollingTask: Task<Void, Never>?
    private let maxPollingDuration: TimeInterval = 300  // 5 minutes
    private let pollingInterval: TimeInterval = 2  // 2 seconds

    // MARK: - Init

    init() {}

    // MARK: - Test Mode

    var isTestMode: Bool {
        get async { await remoteConfig.isTestMode }
    }

    // MARK: - Payment Flow

    func initiatePayment(
        for slot: TimeSlot,
        date: Date,
        clientName: String,
        sessionPriceUAH: Int
    ) async throws(PaymentError) -> Payment {
        // Check if test mode is enabled (our simulated mode)
        if await remoteConfig.isTestMode {
            #if DEBUG
            print("💳 Payment: Using APP SIMULATED test mode (no API calls)")
            #endif
            return await initiateTestPayment(
                for: slot,
                date: date,
                sessionPriceUAH: sessionPriceUAH
            )
        }

        guard let token = await remoteConfig.monobankMerchantToken else {
            throw .apiError("Merchant token not configured")
        }

        #if DEBUG
        // Check if token looks like test token (starts with certain pattern)
        let isLikelyTestToken = token.hasPrefix("u") && token.count < 50
        print("💳 Payment: Using REAL Monobank API")
        print("   Token type: \(isLikelyTestToken ? "⚠️ Likely TEST token" : "🔴 Likely PRODUCTION token")")
        print("   Token prefix: \(String(token.prefix(8)))...")
        #endif

        isProcessing = true
        error = nil

        let reference = UUID().uuidString
        let amountKopiykas = sessionPriceUAH * 100
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "uk_UA")
        dateFormatter.dateFormat = "dd.MM.yyyy"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        let description = "Сеанс психотерапії \(dateFormatter.string(from: date)) о \(timeFormatter.string(from: slot.startTime))"
        let webhookUrl = await remoteConfig.monobankWebhookUrl

        do {
            let (invoiceId, pageUrl) = try await monobank.createInvoice(
                amount: amountKopiykas,
                reference: reference,
                description: description,
                webhookUrl: webhookUrl,
                token: token
            )

            let payment = Payment(
                invoiceId: invoiceId,
                bookingReference: reference,
                amount: amountKopiykas,
                pageUrl: pageUrl,
                status: .pending,
                createdAt: .now
            )

            currentPayment = payment
            isProcessing = false
            return payment
        } catch {
            isProcessing = false
            self.error = error
            throw error
        }
    }

    /// Creates a simulated payment for test mode
    private func initiateTestPayment(
        for slot: TimeSlot,
        date: Date,
        sessionPriceUAH: Int
    ) async -> Payment {
        isProcessing = true
        error = nil

        // Simulate network delay
        try? await Task.sleep(for: .milliseconds(500))

        let reference = UUID().uuidString
        let amountKopiykas = sessionPriceUAH * 100

        let payment = Payment(
            invoiceId: "test_\(reference.prefix(8))",
            bookingReference: reference,
            amount: amountKopiykas,
            pageUrl: "seans://test-payment?reference=\(reference)",
            status: .pending,
            createdAt: .now
        )

        currentPayment = payment
        isProcessing = false
        return payment
    }

    /// Simulates successful payment (for test mode)
    func simulatePaymentSuccess() {
        guard currentPayment != nil else { return }
        currentPayment?.status = .success
        currentPayment?.paidAt = .now
    }

    /// Simulates failed payment (for test mode)
    func simulatePaymentFailure() {
        guard currentPayment != nil else { return }
        currentPayment?.status = .failure
    }

    // MARK: - Polling

    func startPolling() {
        guard let payment = currentPayment, !payment.status.isTerminal else { return }

        stopPolling()

        pollingTask = Task { [weak self] in
            let startTime = Date.now

            while !Task.isCancelled {
                guard let self else { return }

                // Check timeout
                if Date.now.timeIntervalSince(startTime) > maxPollingDuration {
                    await MainActor.run {
                        self.currentPayment?.status = .expired
                        self.error = .timeout
                    }
                    return
                }

                // Poll status
                await self.checkPaymentStatus()

                // Exit if terminal
                let isTerminal = await MainActor.run { self.currentPayment?.status.isTerminal == true }
                if isTerminal {
                    return
                }

                // Wait before next poll
                try? await Task.sleep(for: .seconds(pollingInterval))
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func checkPaymentStatus() async {
        guard let payment = currentPayment,
              let token = await remoteConfig.monobankMerchantToken else { return }

        do {
            let status = try await monobank.checkStatus(invoiceId: payment.invoiceId, token: token)

            await MainActor.run {
                self.currentPayment?.status = status
                if status == .success {
                    self.currentPayment?.paidAt = .now
                }
            }
        } catch {
            #if DEBUG
            print("❌ Payment status check failed: \(error)")
            #endif
        }
    }

    // MARK: - Deep Link Handling

    func handlePaymentCallback(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.host == "payment-callback" else { return }

        let reference = components.queryItems?.first { $0.name == "reference" }?.value

        // If we have a matching payment, start polling to get final status
        if let payment = currentPayment, payment.bookingReference == reference {
            startPolling()
        }
    }

    // MARK: - Refund

    /// Refunds a payment. Returns true if successful.
    /// In test mode, simulates refund without API call.
    func refundPayment(
        invoiceId: String,
        reference: String?,
        amount: Int?  // nil = full refund
    ) async throws(PaymentError) -> Bool {
        // Test mode: simulate refund
        if await remoteConfig.isTestMode {
            #if DEBUG
            print("🧪 Test mode: Simulating refund for invoice \(invoiceId)")
            #endif
            try? await Task.sleep(for: .milliseconds(300))
            return true
        }

        guard let token = await remoteConfig.monobankMerchantToken else {
            throw .apiError("Merchant token not configured")
        }

        return try await monobank.cancelInvoice(
            invoiceId: invoiceId,
            reference: reference,
            amount: amount,
            token: token
        )
    }

    // MARK: - Cleanup

    func reset() {
        stopPolling()
        currentPayment = nil
        isProcessing = false
        error = nil
    }
}
