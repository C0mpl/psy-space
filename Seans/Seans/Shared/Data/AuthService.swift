//
//  AuthService.swift
//  Seans
//
//  Created by Claude on 24.08.2026.
//

import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import Foundation

actor AuthService {
    static let shared = AuthService()

    // MARK: - Current User

    var currentFirebaseUser: FirebaseAuth.User? {
        Auth.auth().currentUser
    }

    // MARK: - Google Sign-In

    @MainActor
    func signInWithGoogle() async throws -> AuthResult {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.configurationError
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw AuthError.noRootViewController
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.missingToken
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )

        let authResult = try await Auth.auth().signIn(with: credential)

        return AuthResult(
            userId: authResult.user.uid,
            email: authResult.user.email,
            name: authResult.user.displayName ?? "Користувач"
        )
    }

    // MARK: - Sign Out

    nonisolated func signOut() throws {
        GIDSignIn.sharedInstance.signOut()
        try Auth.auth().signOut()
    }

    // MARK: - Auth State

    func addAuthStateListener(_ listener: @escaping (FirebaseAuth.User?) -> Void) -> AuthStateDidChangeListenerHandle {
        Auth.auth().addStateDidChangeListener { _, user in
            listener(user)
        }
    }
}

// MARK: - Auth Result

struct AuthResult {
    let userId: String
    let email: String?
    let name: String
}

// MARK: - Auth Error

enum AuthError: Error, LocalizedError {
    case configurationError
    case noRootViewController
    case missingToken
    case signInFailed

    var errorDescription: String? {
        switch self {
        case .configurationError:
            return "Помилка конфігурації Firebase"
        case .noRootViewController:
            return "Не вдалося знайти вікно додатку"
        case .missingToken:
            return "Не вдалося отримати токен авторизації"
        case .signInFailed:
            return "Помилка входу"
        }
    }
}
