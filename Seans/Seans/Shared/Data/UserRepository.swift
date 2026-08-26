//
//  UserRepository.swift
//  Seans
//
//  Created by Claude on 23.08.2026.
//

import FirebaseAuth
import FirebaseFirestore
import Foundation

@Observable
@MainActor
final class UserRepository {
    // MARK: - Dependencies

    private let authService = AuthService.shared
    private let firestore = FirestoreService.shared
    private let storage: UserStorage?
    private var authListener: AuthStateDidChangeListenerHandle?
    private var userListener: ListenerRegistration?

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
                        self?.stopUserListener()
                        self?.currentUser = nil
                    }
                }
            }
        }
    }

    private func handleFirebaseUser(_ firebaseUser: FirebaseAuth.User) {
        // Check if we have stored user data locally
        if let storedUser = storage?.loadUser(), storedUser.id == firebaseUser.uid {
            currentUser = storedUser
            // Start listening for real-time updates (credit changes, etc.)
            startUserListener(userId: firebaseUser.uid)
            return
        }

        // New user - check Firestore for existing data (including isTherapist flag)
        Task {
            await loadOrCreateUser(firebaseUser: firebaseUser)
        }
    }

    // MARK: - User Document Listener

    private func startUserListener(userId: String) {
        stopUserListener()

        #if DEBUG
        print("📡 UserRepository: Starting listener for user \(userId)")
        #endif

        userListener = firestore.listenToUser(userId: userId) { [weak self] user in
            Task { @MainActor in
                guard let self, let user else { return }

                // Update local state if credit changed
                if self.currentUser?.paymentCredit != user.paymentCredit {
                    #if DEBUG
                    print("💰 UserRepository: Credit updated \(self.currentUser?.paymentCredit ?? 0) → \(user.paymentCredit)")
                    #endif
                }

                self.currentUser = user
                self.storage?.saveUser(user)
            }
        }
    }

    private func stopUserListener() {
        userListener?.remove()
        userListener = nil
    }

    private func loadOrCreateUser(firebaseUser: FirebaseAuth.User) async {
        // Try to load existing user from Firestore (may have isTherapist set by admin)
        if let existingUser = try? await firestore.fetchUser(userId: firebaseUser.uid) {
            storage?.saveUser(existingUser)
            currentUser = existingUser
            startUserListener(userId: firebaseUser.uid)
            #if DEBUG
            print("✅ Loaded existing user from Firestore (isTherapist: \(existingUser.isTherapist))")
            #endif
            return
        }

        // New user - create with isTherapist: false (default is client)
        // To make someone therapist, set isTherapist: true in Firestore manually
        let user = User(
            id: firebaseUser.uid,
            email: firebaseUser.email,
            name: firebaseUser.displayName ?? "Користувач",
            isTherapist: false
        )

        storage?.saveUser(user)
        currentUser = user

        // Create new user in Firestore (includes isTherapist: false)
        try? await firestore.createUser(user)
        startUserListener(userId: firebaseUser.uid)
        #if DEBUG
        print("✅ Created new user in Firestore (isTherapist: false)")
        #endif
    }

    // MARK: - Sign In

    func signInWithGoogle() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let result = try await authService.signInWithGoogle()

            // Check Firestore for existing user (may have isTherapist set by admin)
            if let existingUser = try? await firestore.fetchUser(userId: result.userId) {
                storage?.saveUser(existingUser)
                currentUser = existingUser
                startUserListener(userId: result.userId)
                #if DEBUG
                print("✅ Loaded existing user from Firestore (isTherapist: \(existingUser.isTherapist))")
                #endif
                return
            }

            // New user - default to client role
            let user = User(
                id: result.userId,
                email: result.email,
                name: result.name,
                isTherapist: false  // Default: client. Set to true in Firestore for therapist.
            )

            storage?.saveUser(user)
            currentUser = user

            // Create new user in Firestore (includes isTherapist: false)
            do {
                try await firestore.createUser(user)
                startUserListener(userId: result.userId)
                #if DEBUG
                print("✅ Created new user in Firestore (isTherapist: false)")
                #endif
            } catch {
                #if DEBUG
                print("❌ Failed to create user in Firestore: \(error)")
                #endif
            }
        } catch {
            self.error = .signInFailed
        }
    }

    // MARK: - Refresh

    func refreshCurrentUser() async {
        guard let userId = currentUser?.id else { return }

        do {
            if let updatedUser = try await firestore.fetchUser(userId: userId) {
                currentUser = updatedUser
                storage?.saveUser(updatedUser)
            }
        } catch {
            // Silently fail - user data will be refreshed on next sign-in
        }
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try authService.signOut()
            stopUserListener()
            storage?.deleteUser()
            currentUser = nil
        } catch {
            self.error = .unknown
        }
    }

    // MARK: - Debug

    #if DEBUG
    func debugSwitchRole() {
        guard let user = currentUser else { return }
        let newUser = User(
            id: user.id,
            email: user.email,
            name: user.name,
            isTherapist: !user.isTherapist,
            createdAt: user.createdAt,
            paymentCredit: user.paymentCredit  // Preserve credit
        )
        storage?.saveUser(newUser)
        currentUser = newUser

        // Also save to Firestore to ensure document exists
        Task {
            try? await firestore.saveUser(newUser)
        }
    }

    /// Force create user document in Firestore (for debugging)
    func debugEnsureUserExists() {
        guard let user = currentUser else { return }
        Task {
            try? await firestore.saveUser(user)
            print("✅ Debug: User document created/updated in Firestore")
        }
    }
    #endif
}

enum UserError: Error {
    case signInFailed
    case networkError
    case unknown
}
