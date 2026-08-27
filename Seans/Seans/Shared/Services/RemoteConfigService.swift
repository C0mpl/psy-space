//
//  RemoteConfigService.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 25.08.2026.
//

import FirebaseFirestore
import Foundation

actor RemoteConfigService {
    static let shared = RemoteConfigService()

    private var db: Firestore { Firestore.firestore() }
    private var paymentConfigDocument: DocumentReference {
        db.collection("config").document("payment")
    }

    private var cachedConfig: PaymentConfig?

    private init() {}

    private struct PaymentConfig {
        var testMode: Bool
        var merchantToken: String?
        var webhookUrl: String?
    }

    private func fetchConfig() async -> PaymentConfig {
        do {
            let snapshot = try await paymentConfigDocument.getDocument()
            let data = snapshot.data() ?? [:]

            let config = PaymentConfig(
                testMode: data["testMode"] as? Bool ?? false,
                merchantToken: data["merchantToken"] as? String,
                webhookUrl: data["webhookUrl"] as? String
            )
            cachedConfig = config
            return config
        } catch {
            #if DEBUG
            print("❌ Failed to fetch payment config: \(error)")
            #endif
            return PaymentConfig(testMode: false, merchantToken: nil, webhookUrl: nil)
        }
    }

    private func getConfig() async -> PaymentConfig {
        if let cached = cachedConfig {
            return cached
        }
        return await fetchConfig()
    }

    func refreshConfig() async {
        cachedConfig = nil
        _ = await fetchConfig()
    }

    var isTestMode: Bool {
        get async {
            await getConfig().testMode
        }
    }

    func setTestMode(_ enabled: Bool) async {
        do {
            try await paymentConfigDocument.setData(["testMode": enabled], merge: true)
            cachedConfig?.testMode = enabled
            #if DEBUG
            print("✅ Test mode set to: \(enabled)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to set test mode: \(error)")
            #endif
        }
    }

    var monobankMerchantToken: String? {
        get async {
            await getConfig().merchantToken
        }
    }

    func setMonobankMerchantToken(_ token: String) async {
        do {
            try await paymentConfigDocument.setData(["merchantToken": token], merge: true)
            cachedConfig?.merchantToken = token
            #if DEBUG
            print("✅ Merchant token saved to Firestore")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to save merchant token: \(error)")
            #endif
        }
    }

    func clearMonobankMerchantToken() async {
        do {
            try await paymentConfigDocument.updateData(["merchantToken": FieldValue.delete()])
            cachedConfig?.merchantToken = nil
            #if DEBUG
            print("✅ Merchant token cleared")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to clear merchant token: \(error)")
            #endif
        }
    }

    var monobankWebhookUrl: String? {
        get async {
            await getConfig().webhookUrl
        }
    }

    func setMonobankWebhookUrl(_ url: String) async {
        do {
            try await paymentConfigDocument.setData(["webhookUrl": url], merge: true)
            cachedConfig?.webhookUrl = url
            #if DEBUG
            print("✅ Webhook URL saved to Firestore")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to save webhook URL: \(error)")
            #endif
        }
    }
}
