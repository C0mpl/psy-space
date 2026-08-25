//
//  Stage.swift
//  Seans
//
//  Created by Claude on 23.08.2026.
//

import SwiftUI

struct Stage: View {
    @State private var userRepo = UserRepository()
    @State private var availabilityRepo = AvailabilityRepository()
    @State private var bookingRepo = BookingRepository()
    @State private var notificationRepo = NotificationRepository()

    var body: some View {
        Group {
            switch currentFlow {
            case .auth:
                AuthFlow()
            case .client:
                ClientFlow()
            case .therapist:
                TherapistFlow()
            }
        }
        .environment(userRepo)
        .environment(availabilityRepo)
        .environment(bookingRepo)
        .environment(notificationRepo)
        .tint(Color.seansPrimary)
        .onChange(of: userRepo.currentUser) { _, newUser in
            setupListeners(for: newUser)
        }
        .onChange(of: bookingRepo.bookings) { _, _ in
            checkForCancellations()
        }
        .onAppear {
            setupListeners(for: userRepo.currentUser)
        }
        .overlay {
            if let notification = notificationRepo.currentNotification {
                CancellationAlert(
                    notification: notification,
                    onDismiss: { notificationRepo.dismissCurrentNotification() }
                )
            }
        }
    }

    private var currentFlow: AppFlow {
        guard let user = userRepo.currentUser else {
            return .auth
        }
        return user.isTherapist ? .therapist : .client
    }

    private func setupListeners(for user: User?) {
        guard let user else { return }

        if user.isTherapist {
            // Therapist sees all bookings
            bookingRepo.startListening()
        } else {
            // Client sees only their bookings
            bookingRepo.startListening(forClientId: user.id)
        }

        // Save FCM token for push notifications
        Task {
            await PushNotificationService.shared.saveToken(for: user.id)
        }
    }

    private func checkForCancellations() {
        guard let user = userRepo.currentUser else { return }
        notificationRepo.checkForCancellations(
            bookings: bookingRepo.bookings,
            currentUserId: user.id,
            isTherapist: user.isTherapist
        )
    }
}

// MARK: - Cancellation Alert

private struct CancellationAlert: View {
    let notification: CancellationNotification
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: Spacing.md) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.red.opacity(0.8))

                Text(notification.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.seansTextPrimary)

                Text(notification.message)
                    .font(.subheadline)
                    .foregroundStyle(Color.seansTextSecondary)
                    .multilineTextAlignment(.center)

                if let reason = notification.reason {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Причина:")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.seansTextSecondary)

                        Text(reason)
                            .font(.subheadline)
                            .foregroundStyle(Color.seansTextPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.sm)
                    .background(Color.seansBackground)
                    .clipShape(.rect(cornerRadius: CornerRadius.sm))
                }

                Button {
                    onDismiss()
                } label: {
                    Text("Зрозуміло")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.seansPrimary)
            }
            .padding(Spacing.lg)
            .background(Color.seansCardBackground)
            .clipShape(.rect(cornerRadius: CornerRadius.lg))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            .padding(.horizontal, Spacing.xl)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(.spring(duration: 0.3), value: notification.id)
    }
}

#Preview {
    Stage()
}
