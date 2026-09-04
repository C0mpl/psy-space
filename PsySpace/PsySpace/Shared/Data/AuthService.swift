//
//  AuthService.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 24.08.2026.
//

import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import Foundation

actor AuthService {
    static let shared = AuthService()

    private static let calendarScope = "https://www.googleapis.com/auth/calendar.events"

    private static let webClientID = "32187929458-cvrav65h7efdghs36qopjdji163pfr5f.apps.googleusercontent.com"

    var currentFirebaseUser: FirebaseAuth.User? {
        Auth.auth().currentUser
    }

    @MainActor
    var currentGoogleUser: GIDGoogleUser? {
        GIDSignIn.sharedInstance.currentUser
    }

    @MainActor
    var hasCalendarAccess: Bool {
        guard let user = GIDSignIn.sharedInstance.currentUser else { return false }
        return user.grantedScopes?.contains(Self.calendarScope) ?? false
    }

    @MainActor
    func signInWithGoogle() async throws -> AuthResult {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.configurationError
        }

        let config = GIDConfiguration(
            clientID: clientID,
            serverClientID: Self.webClientID
        )
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

    @MainActor
    func requestCalendarAccess() async throws -> Bool {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.configurationError
        }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw AuthError.noRootViewController
        }

        let config = GIDConfiguration(
            clientID: clientID,
            serverClientID: Self.webClientID
        )
        GIDSignIn.sharedInstance.configuration = config

        let hint = GIDSignIn.sharedInstance.currentUser?.profile?.email

        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: rootViewController,
            hint: hint,
            additionalScopes: [Self.calendarScope]
        )

        let granted = result.user.grantedScopes?.contains(Self.calendarScope) ?? false

        #if DEBUG
        print("📅 Calendar scope \(granted ? "granted" : "denied")")
        print("📅 Server auth code: \(result.serverAuthCode ?? "nil")")
        #endif

        if granted {
            await saveServerAuthCode(result.serverAuthCode)
        }

        return granted
    }

    @MainActor
    private func saveServerAuthCode(_ authCode: String?) async {
        guard let authCode, !authCode.isEmpty else {
            #if DEBUG
            print("❌ No server auth code available")
            #endif
            return
        }

        do {
            try await FirestoreService.shared.saveTherapistAuthCode(authCode)
            #if DEBUG
            print("✅ Server auth code saved for token exchange")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to save server auth code: \(error)")
            #endif
        }
    }

    @MainActor
    func getValidAccessToken() async throws -> String {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw AuthError.notSignedIn
        }

        try await user.refreshTokensIfNeeded()

        guard let accessToken = user.accessToken.tokenString as String? else {
            throw AuthError.missingToken
        }

        return accessToken
    }

    nonisolated func signOut() throws {
        GIDSignIn.sharedInstance.signOut()
        try Auth.auth().signOut()
    }

    func addAuthStateListener(_ listener: @escaping (FirebaseAuth.User?) -> Void) -> AuthStateDidChangeListenerHandle {
        Auth.auth().addStateDidChangeListener { _, user in
            listener(user)
        }
    }
}

struct AuthResult {
    let userId: String
    let email: String?
    let name: String
}

enum AuthError: Error, LocalizedError {
    case configurationError
    case noRootViewController
    case missingToken
    case signInFailed
    case notSignedIn

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
        case .notSignedIn:
            return "Користувач не увійшов"
        }
    }
}
