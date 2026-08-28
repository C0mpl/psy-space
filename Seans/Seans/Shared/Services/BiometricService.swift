//
//  BiometricService.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 27.08.2026.
//

import Foundation
import LocalAuthentication

@MainActor
final class BiometricService {
    static let shared = BiometricService()

    private init() {}

    var biometricType: BiometricType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .opticID
        case .none:
            return .none
        @unknown default:
            return .none
        }
    }

    var isBiometricAvailable: Bool {
        biometricType != .none
    }

    var biometricName: String {
        switch biometricType {
        case .faceID:
            "Face ID"
        case .touchID:
            "Touch ID"
        case .opticID:
            "Optic ID"
        case .none:
            "Біометрія"
        }
    }

    var biometricIcon: String {
        switch biometricType {
        case .faceID:
            "faceid"
        case .touchID:
            "touchid"
        case .opticID:
            "opticid"
        case .none:
            "lock"
        }
    }

    func authenticate(reason: String) async -> BiometricResult {
        let context = LAContext()
        context.localizedCancelTitle = "Скасувати"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error {
                return mapError(error)
            }
            return .unavailable
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return success ? .success : .failed
        } catch let error as NSError {
            return mapError(error)
        }
    }

    private func mapError(_ error: NSError) -> BiometricResult {
        switch error.code {
        case LAError.biometryNotAvailable.rawValue:
            return .unavailable
        case LAError.biometryNotEnrolled.rawValue:
            return .notEnrolled
        case LAError.biometryLockout.rawValue:
            return .lockedOut
        case LAError.userCancel.rawValue:
            return .cancelled
        case LAError.userFallback.rawValue:
            return .fallbackRequested
        case LAError.authenticationFailed.rawValue:
            return .failed
        default:
            return .error(error)
        }
    }
}

enum BiometricType {
    case none
    case touchID
    case faceID
    case opticID
}

enum BiometricResult {
    case success
    case failed
    case cancelled
    case unavailable
    case notEnrolled
    case lockedOut
    case fallbackRequested
    case error(Error)

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
