//
//  PrivacyPreferences.swift
//  PsySpace
//
//  Created by Claude on 04.09.2026.
//

import Foundation

@Observable
@MainActor
final class PrivacyPreferences {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let crashReportsEnabled = "privacy.crashReportsEnabled"
    }

    var crashReportsEnabled: Bool {
        didSet {
            defaults.set(crashReportsEnabled, forKey: Keys.crashReportsEnabled)
            CrashlyticsService.shared.setEnabled(crashReportsEnabled)
        }
    }

    init() {
        // Default to enabled for crash reports (important for stability)
        self.crashReportsEnabled = defaults.object(forKey: Keys.crashReportsEnabled) as? Bool ?? true
    }
}
