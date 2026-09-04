//
//  Stage.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 23.08.2026.
//

import SwiftUI

struct Stage: View {
    @State private var userRepo = UserRepository()
    @State private var availabilityRepo = AvailabilityRepository()
    @State private var bookingRepo = BookingRepository()
    @State private var notificationRepo = NotificationRepository()
    @State private var paymentRepo = PaymentRepository()

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
        .environment(paymentRepo)
        .tint(Color.psyspacePrimary)
        .onOpenURL { url in
            handleOpenURL(url)
        }
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

        #if DEBUG
        print("🔄 Stage: Setting up listeners for user \(user.id) (isTherapist: \(user.isTherapist))")
        #endif

        if user.isTherapist {
            bookingRepo.startListening()
        } else {
            bookingRepo.startListening(forClientId: user.id)
        }

        Task {
            _ = await PushNotificationService.shared.requestPermission()
            await PushNotificationService.shared.saveToken(for: user.id)

            if user.isTherapist && !user.calendarSyncEnabled {
                let granted = await CalendarService.shared.requestAccess()
                if granted {
                    await userRepo.setCalendarSyncEnabled(true)
                }
            }
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

    private func handleOpenURL(_ url: URL) {
        if url.scheme == "psyspace" && url.host == "payment-callback" {
            paymentRepo.handlePaymentCallback(url: url)
        }
    }
}

private struct CancellationAlert: View {
    let notification: CancellationNotification
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Закрити сповіщення")

            VStack(spacing: Spacing.md) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.red.opacity(0.8))

                Text(notification.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.psyspaceTextPrimary)

                Text(notification.message)
                    .font(.subheadline)
                    .foregroundStyle(Color.psyspaceTextSecondary)
                    .multilineTextAlignment(.center)

                if let reason = notification.reason {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Причина:")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.psyspaceTextSecondary)

                        Text(reason)
                            .font(.subheadline)
                            .foregroundStyle(Color.psyspaceTextPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.sm)
                    .background(Color.psyspaceBackground)
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
                .tint(Color.psyspacePrimary)
            }
            .padding(Spacing.lg)
            .background(Color.psyspaceCardBackground)
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
