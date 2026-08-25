//
//  SeansApp.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 23.08.2026.
//

import Firebase
import GoogleSignIn
import SwiftUI

@main
struct SeansApp: App {
    init() {
        FirebaseApp.configure()
        PushNotificationService.shared.setup()
    }

    var body: some Scene {
        WindowGroup {
            Stage()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .task {
                    await PushNotificationService.shared.requestPermission()
                }
        }
    }
}
