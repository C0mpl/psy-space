//
//  JournalPreferences.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 27.08.2026.
//

import Foundation

@Observable
@MainActor
final class JournalPreferences {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let biometricLockEnabled = "journal.biometricLockEnabled"
        static let autoLockOnBackground = "journal.autoLockOnBackground"
        static let defaultShareWithTherapist = "journal.defaultShareWithTherapist"
    }

    var isBiometricLockEnabled: Bool {
        didSet {
            defaults.set(isBiometricLockEnabled, forKey: Keys.biometricLockEnabled)
            if isBiometricLockEnabled {
                isUnlocked = false
            }
        }
    }

    var autoLockOnBackground: Bool {
        didSet {
            defaults.set(autoLockOnBackground, forKey: Keys.autoLockOnBackground)
        }
    }

    var defaultShareWithTherapist: Bool {
        didSet {
            defaults.set(defaultShareWithTherapist, forKey: Keys.defaultShareWithTherapist)
        }
    }

    var isUnlocked = false

    var isLocked: Bool {
        isBiometricLockEnabled && !isUnlocked
    }

    init() {
        self.isBiometricLockEnabled = defaults.bool(forKey: Keys.biometricLockEnabled)
        self.autoLockOnBackground = defaults.bool(forKey: Keys.autoLockOnBackground)
        self.defaultShareWithTherapist = defaults.bool(forKey: Keys.defaultShareWithTherapist)
    }

    func unlock() async -> Bool {
        guard isBiometricLockEnabled else {
            isUnlocked = true
            return true
        }

        let result = await BiometricService.shared.authenticate(
            reason: "Розблокуйте щоденник"
        )

        if result.isSuccess {
            isUnlocked = true
            return true
        }

        return false
    }

    func lock() {
        if isBiometricLockEnabled {
            isUnlocked = false
        }
    }

    func lockIfNeeded() {
        if autoLockOnBackground && isBiometricLockEnabled {
            isUnlocked = false
        }
    }
}
