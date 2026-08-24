//
//  UserRepository.swift
//  Seans
//
//  Created by Claude on 23.08.2026.
//

import FirebaseAuth
import Foundation

@Observable
@MainActor
final class UserRepository {
    // MARK: - Configuration

    /// The therapist's email. Sign-ins matching this email get therapist role.
    private let therapistEmail = "therapist@example.com" // TODO: Replace with actual email

    // MARK: - Dependencies

    private let authService = AuthService.shared
    private let storage: UserStorage?
    private var authListener: AuthStateDidChangeListenerHandle?

    // MARK: - State

    var currentUser: User?
    var isLoading = false
    var error: UserError?

    var isAuthenticated: Bool { currentUser != nil }

    // MARK: - Init

    init() {
        self.storage = try? UserStorage()
        setupAuthListener()
    }

    // MARK: - Auth Listener

    private func setupAuthListener() {
        Task {
            authListener = await authService.addAuthStateListener { [weak self] firebaseUser in
                Task { @MainActor in
                    if let firebaseUser {
                        self?.handleFirebaseUser(firebaseUser)
                    } else {
                        self?.currentUser = nil
                    }
                }
            }
        }
    }

    private func handleFirebaseUser(_ firebaseUser: FirebaseAuth.User) {
        // Check if we have stored user data
        if let storedUser = storage?.loadUser(), storedUser.id == firebaseUser.uid {
            currentUser = storedUser
            return
        }

        // Create new user from Firebase data
        let isTherapist = firebaseUser.email?.lowercased() == therapistEmail.lowercased()

        let user = User(
            id: firebaseUser.uid,
            email: firebaseUser.email,
            name: firebaseUser.displayName ?? "Користувач",
            isTherapist: isTherapist
        )

        storage?.saveUser(user)
        currentUser = user
    }

    // MARK: - Sign In

    func signInWithGoogle() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let result = try await authService.signInWithGoogle()

            let isTherapist = result.email?.lowercased() == therapistEmail.lowercased()

            let user = User(
                id: result.userId,
                email: result.email,
                name: result.name,
                isTherapist: isTherapist
            )

            storage?.saveUser(user)
            currentUser = user
        } catch {
            self.error = .signInFailed
        }
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try authService.signOut()
            storage?.deleteUser()
            currentUser = nil
        } catch {
            self.error = .unknown
        }
    }
}

enum UserError: Error {
    case signInFailed
    case networkError
    case unknown
}
