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
        .tint(Color.seansPrimary)
        .onChange(of: userRepo.currentUser) { _, newUser in
            setupListeners(for: newUser)
        }
        .onAppear {
            setupListeners(for: userRepo.currentUser)
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
    }
}

#Preview {
    Stage()
}
