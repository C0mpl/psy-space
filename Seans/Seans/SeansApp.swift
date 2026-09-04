//
//  SeansApp.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 23.08.2026.
//

import Firebase
import FirebaseCrashlytics
import GoogleSignIn
import SwiftUI

@main
struct SeansApp: App {
    @State private var privacyPreferences = PrivacyPreferences()

    init() {
        FirebaseApp.configure()
        PushNotificationService.shared.setup()
    }

    var body: some Scene {
        WindowGroup {
            Stage()
                .environment(privacyPreferences)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .task {
                    await PushNotificationService.shared.requestPermission()
                    CrashlyticsService.shared.configure(with: privacyPreferences)
                }
        }
    }
}
