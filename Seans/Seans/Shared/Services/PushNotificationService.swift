//
//  PushNotificationService.swift
//  Seans
//
//  Created by Claude on 24.08.2026.
//

import FirebaseFirestore
import Foundation
import UserNotifications

// TODO: Add FirebaseMessaging package when Apple Developer account is ready
// import FirebaseMessaging

@MainActor
final class PushNotificationService: NSObject, Sendable {
    static let shared = PushNotificationService()

    private let db = Firestore.firestore()

    private override init() {
        super.init()
    }

    // MARK: - Setup

    func setup() {
        UNUserNotificationCenter.current().delegate = self
        // TODO: Enable when FirebaseMessaging is added
        // Messaging.messaging().delegate = self
    }

    // MARK: - Request Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])

            if granted {
                await registerForRemoteNotifications()
            }

            return granted
        } catch {
            print("❌ Push notification permission error: \(error)")
            return false
        }
    }

    @MainActor
    private func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    // MARK: - Token Storage

    func saveToken(for userId: String) async {
        // TODO: Enable when FirebaseMessaging is added
        // guard let token = Messaging.messaging().fcmToken else {
        //     print("⚠️ No FCM token available")
        //     return
        // }
        //
        // do {
        //     try await db.collection("userTokens").document(userId).setData([
        //         "fcmToken": token,
        //         "updatedAt": FieldValue.serverTimestamp()
        //     ], merge: true)
        //     print("✅ FCM token saved for user \(userId)")
        // } catch {
        //     print("❌ Failed to save FCM token: \(error)")
        // }
    }

    func removeToken(for userId: String) async {
        do {
            try await db.collection("userTokens").document(userId).delete()
            print("✅ FCM token removed for user \(userId)")
        } catch {
            print("❌ Failed to remove FCM token: \(error)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show notification even when app is in foreground
        return [.banner, .badge, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        print("📱 Notification tapped: \(userInfo)")
    }
}
