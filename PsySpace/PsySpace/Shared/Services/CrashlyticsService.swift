//
//  CrashlyticsService.swift
//  PsySpace
//
//  Created by Claude on 04.09.2026.
//

import FirebaseCrashlytics
import Foundation

@MainActor
final class CrashlyticsService {
    static let shared = CrashlyticsService()

    private init() {}

    func configure(with preferences: PrivacyPreferences) {
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(preferences.crashReportsEnabled)

        #if DEBUG
        print("[Crashlytics] Collection enabled: \(preferences.crashReportsEnabled)")
        #endif
    }

    func setEnabled(_ enabled: Bool) {
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(enabled)
        #if DEBUG
        print("[Crashlytics] Collection updated: \(enabled)")
        #endif
    }

    func setUserId(_ userId: String?) {
        if let userId {
            Crashlytics.crashlytics().setUserID(userId)
        }
    }

    func log(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }

    func recordError(_ error: Error, userInfo: [String: Any]? = nil) {
        Crashlytics.crashlytics().record(error: error, userInfo: userInfo)
    }

    func setCustomValue(_ value: Any?, forKey key: String) {
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }
}
