//
//  UserRepository.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 23.08.2026.
//

import FirebaseAuth
import FirebaseFirestore
import Foundation

@Observable
@MainActor
final class UserRepository {
    private let authService = AuthService.shared
    private let firestore = FirestoreService.shared
    private let storage: UserStorage?
    private var authListener: AuthStateDidChangeListenerHandle?
    private var userListener: ListenerRegistration?

    var currentUser: User?
    var isLoading = false
    var error: UserError?

    var isAuthenticated: Bool { currentUser != nil }

    init() {
        self.storage = try? UserStorage()
        setupAuthListener()
    }

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
        if let storedUser = storage?.loadUser(), storedUser.id == firebaseUser.uid {
            currentUser = storedUser
            startUserListener(userId: firebaseUser.uid)
            return
        }

        Task {
            await loadOrCreateUser(firebaseUser: firebaseUser)
        }
    }

    private func startUserListener(userId: String) {
        stopUserListener()

        #if DEBUG
        print("📡 UserRepository: Starting listener for user \(userId)")
        #endif

        userListener = firestore.listenToUser(userId: userId) { [weak self] user in
            Task { @MainActor in
                guard let self, let user else { return }

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
        if let existingUser = try? await firestore.fetchUser(userId: firebaseUser.uid) {
            storage?.saveUser(existingUser)
            currentUser = existingUser
            startUserListener(userId: firebaseUser.uid)
            #if DEBUG
            print("✅ Loaded existing user from Firestore (isTherapist: \(existingUser.isTherapist))")
            #endif
            return
        }

        let user = User(
            id: firebaseUser.uid,
            email: firebaseUser.email,
            name: firebaseUser.displayName ?? "Користувач",
            isTherapist: false
        )

        storage?.saveUser(user)
        currentUser = user

        try? await firestore.createUser(user)
        startUserListener(userId: firebaseUser.uid)
        #if DEBUG
        print("✅ Created new user in Firestore (isTherapist: false)")
        #endif
    }

    func signInWithGoogle() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let result = try await authService.signInWithGoogle()

            if let existingUser = try? await firestore.fetchUser(userId: result.userId) {
                storage?.saveUser(existingUser)
                currentUser = existingUser
                startUserListener(userId: result.userId)
                #if DEBUG
                print("✅ Loaded existing user from Firestore (isTherapist: \(existingUser.isTherapist))")
                #endif
                return
            }

            let user = User(
                id: result.userId,
                email: result.email,
                name: result.name,
                isTherapist: false
            )

            storage?.saveUser(user)
            currentUser = user

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

    func refreshCurrentUser() async {
        guard let userId = currentUser?.id else { return }

        do {
            if let updatedUser = try await firestore.fetchUser(userId: userId) {
                currentUser = updatedUser
                storage?.saveUser(updatedUser)
            }
        } catch {
        }
    }

    func setCalendarSyncEnabled(_ enabled: Bool) async {
        guard var user = currentUser else { return }
        user.calendarSyncEnabled = enabled

        storage?.saveUser(user)
        currentUser = user

        try? await firestore.saveUser(user)

        #if DEBUG
        print("📅 Calendar sync set to \(enabled) for user \(user.id)")
        #endif
    }

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

    #if DEBUG
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
