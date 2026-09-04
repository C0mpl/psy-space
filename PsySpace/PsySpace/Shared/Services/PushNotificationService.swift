//
//  PushNotificationService.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 24.08.2026.
//

import FirebaseFirestore
import Foundation
import UserNotifications

@MainActor
final class PushNotificationService: NSObject, Sendable {
    static let shared = PushNotificationService()

    private let db = Firestore.firestore()

    private override init() {
        super.init()
    }

    func setup() {
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])

            if granted {
                await registerForRemoteNotifications()
            }

            return granted
        } catch {
            #if DEBUG
            print("❌ Push notification permission error: \(error)")
            #endif
            return false
        }
    }

    @MainActor
    private func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    func saveToken(for userId: String) async {
    }

    func removeToken(for userId: String) async {
        do {
            try await db.collection("userTokens").document(userId).delete()
            #if DEBUG
            print("✅ FCM token removed for user \(userId)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to remove FCM token: \(error)")
            #endif
        }
    }
}

extension PushNotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .badge, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        #if DEBUG
        let userInfo = response.notification.request.content.userInfo
        print("📱 Notification tapped: \(userInfo)")
        #endif
    }
}
