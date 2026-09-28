//
//  BookingTab.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 23.08.2026.
//

import SwiftUI

struct BookingTab: View {
    @Environment(UserRepository.self) private var userRepo
    @Environment(AvailabilityRepository.self) private var availabilityRepo
    @Environment(BookingRepository.self) private var bookingRepo
    @Environment(PaymentRepository.self) private var paymentRepo
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedDate: Date = .now
    @State private var selectedSlot: TimeSlot?
    @State private var showingPaymentSheet = false
    @State private var showingError = false
    @State private var errorMessage: String?
    @State private var bookingToCancel: Booking?
    @State private var cancellationReason = ""
    @State private var bookingToReschedule: Booking?
    @State private var isBooking = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    BookingHeader(
                        userName: userRepo.currentUser?.name,
                        nextBooking: myUpcomingBookings.first,
                        onNotificationsTap: { /* TODO: Navigate to notifications */ }
                    )

                    if let nextBooking = myUpcomingBookings.first {
                        NextSessionCard(
                            booking: nextBooking,
                            onReschedule: { bookingToReschedule = nextBooking },
                            onCancel: {
                                cancellationReason = ""
                                bookingToCancel = nextBooking
                            }
                        )
                        .padding(.horizontal, Spacing.lg)
                    }

                    if myUpcomingBookings.count > 1 {
                        otherBookingsSection
                            .padding(.horizontal, Spacing.lg)
                    }

                    bookNewSessionSection
                        .padding(.horizontal, Spacing.lg)

                    if !availableSlots.isEmpty {
                        SimpleTimeSlotGrid(
                            slots: availableSlots,
                            selectedSlotId: selectedSlot?.id,
                            selectedDate: selectedDate,
                            reduceMotion: reduceMotion
                        ) { slot in
                            selectedSlot = slot
                            showingPaymentSheet = true
                        }
                        .padding(.horizontal, Spacing.lg)
                    } else {
                        slotSelectionContent
                            .padding(.horizontal, Spacing.lg)
                    }

                    if let nextSlot = nextAvailableSlot {
                        QuickBookCTA {
                            selectedDate = nextSlot.date
                            Task { @MainActor in
                                selectedSlot = nextSlot
                                showingPaymentSheet = true
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
                    }

                    Spacer()
                        .frame(height: Spacing.xxl)
                }
            }
            .scrollClipDisabled()
            .background(Color.psyspaceBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .adaptiveSheet(isPresented: $showingPaymentSheet, detents: [.large]) {
                paymentSheetContent
            }
            .alert("Помилка", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Не вдалося записатися на сеанс")
            }
            .adaptiveSheet(item: $bookingToCancel, detents: [.medium, .large]) { booking in
                CancelBookingSheet(
                    booking: booking,
                    reason: $cancellationReason,
                    title: "Скасувати запис",
                    message: "Запис на \(booking.dateFormatted) о \(booking.startTime.formatted(date: .omitted, time: .shortened))",
                    isTherapist: false
                ) { _ in
                    cancelBooking(booking)
                }
            }
            .adaptiveSheet(item: $bookingToReschedule, detents: [.large]) { booking in
                RescheduleSheet(
                    booking: booking,
                    rescheduledBy: .client
                ) {
                    bookingToReschedule = nil
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var myUpcomingBookings: [Booking] {
        guard let userId = userRepo.currentUser?.id else { return [] }
        return bookingRepo.upcomingBookings(for: userId)
    }

    private var selectedWeekday: Int {
        Calendar.current.component(.weekday, from: selectedDate)
    }

    private var availableSlots: [TimeSlot] {
        let existingBookings = bookingRepo.bookings(for: selectedDate)
        return availabilityRepo.generateTimeSlots(for: selectedDate, existingBookings: existingBookings)
            .filter { !$0.isBooked && $0.startTime > .now }
    }

    private var nextAvailableSlot: TimeSlot? {
        for dayOffset in 0..<14 {
            guard let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: .now) else { continue }
            let weekday = Calendar.current.component(.weekday, from: date)
            guard availabilityRepo.isWorkingDay(weekday) else { continue }

            let existingBookings = bookingRepo.bookings(for: date)
            let slots = availabilityRepo.generateTimeSlots(for: date, existingBookings: existingBookings)
                .filter { !$0.isBooked && $0.startTime > .now }

            if let first = slots.first {
                return first
            }
        }
        return nil
    }

    // MARK: - Sections

    private var otherBookingsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Інші записи")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.psyspaceTextSecondary)

            VStack(spacing: Spacing.xs) {
                ForEach(myUpcomingBookings.dropFirst()) { booking in
                    CompactBookingRow(
                        booking: booking,
                        onReschedule: { bookingToReschedule = booking },
                        onCancel: {
                            cancellationReason = ""
                            bookingToCancel = booking
                        }
                    )
                }
            }
        }
    }

    private var bookNewSessionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Оберіть зручний час")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.psyspaceTextSecondary)

                HStack {
                    Text("Записатися")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.psyspaceTextPrimary)
                        .tracking(-0.5)

                    Spacer()

                    if myUpcomingBookings.count > 0 {
                        Button {
                            // TODO: Show my bookings list
                        } label: {
                            Text("Мої записи")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.psyspacePrimary)
                        }
                    }
                }
            }

            MonthlyCalendarView(
                selectedDate: $selectedDate,
                bookedDate: myUpcomingBookings.first?.date,
                isDateAvailable: { date in
                    let weekday = Calendar.current.component(.weekday, from: date)
                    return availabilityRepo.isWorkingDay(weekday)
                }
            )
            .onChange(of: selectedDate) { _, _ in
                selectedSlot = nil
                if !reduceMotion {
                    HapticService.selection()
                }
            }
        }
    }

    @ViewBuilder
    private var slotSelectionContent: some View {
        if availabilityRepo.isWorkingDay(selectedWeekday) {
            NoSlotsView(
                nextAvailableDate: nextAvailableSlot?.date,
                selectedDate: selectedDate
            ) { date in
                selectedDate = date
            }
        } else {
            DayOffView(nextAvailableDate: nextAvailableSlot?.date) { date in
                selectedDate = date
            }
        }
    }

    @ViewBuilder
    private var paymentSheetContent: some View {
        if let slot = selectedSlot, let user = userRepo.currentUser {
            PaymentSheet(
                slot: slot,
                date: selectedDate,
                priceUAH: availabilityRepo.settings.sessionPriceUAH,
                clientId: user.id,
                clientName: user.name,
                userCredit: user.paymentCredit,
                onComplete: { payment, usedCredit in
                    showingPaymentSheet = false
                    createBookingAfterPayment(slot: slot, payment: payment, usedCreditAmount: usedCredit)
                },
                onCancel: {
                    showingPaymentSheet = false
                    selectedSlot = nil
                }
            )
            .interactiveDismissDisabled()
        }
    }

    // MARK: - Actions

    private func cancelBooking(_ booking: Booking) {
        Task {
            await bookingRepo.cancelBooking(booking.bookingId, by: .client, reason: cancellationReason)
            bookingToCancel = nil
        }
    }

    private func createBookingAfterPayment(slot: TimeSlot, payment: Payment, usedCreditAmount: Int?) {
        guard let user = userRepo.currentUser else { return }

        let weekday = Calendar.current.component(.weekday, from: selectedDate)
        let maxSessions = availabilityRepo.settings.weeklySchedule.schedule(for: weekday)?.maxSessionsPerDay

        isBooking = true

        Task {
            do {
                if let usedCredit = usedCreditAmount, usedCredit > 0 {
                    try await FirestoreUserService.shared.useUserCredit(userId: user.id, amount: usedCredit)
                    await userRepo.refreshCurrentUser()
                }

                try await bookingRepo.createBooking(
                    clientId: user.id,
                    clientName: user.name,
                    clientEmail: user.email,
                    date: selectedDate,
                    slot: slot,
                    maxSessionsPerDay: maxSessions,
                    paymentId: payment.invoiceId,
                    paidAmount: payment.amount > 0 ? payment.amount : nil,
                    usedCreditAmount: usedCreditAmount
                )
                HapticService.notification(.success)
                selectedSlot = nil
                paymentRepo.reset()
            } catch let error as BookingError {
                HapticService.notification(.error)
                switch error {
                case .slotUnavailable:
                    errorMessage = "Цей час вже зайнятий. Оберіть інший."
                case .maxSessionsReached:
                    errorMessage = "Досягнуто максимальну кількість сеансів."
                case .unknown:
                    errorMessage = "Не вдалося записатися на сеанс."
                }
                showingError = true
            } catch {
                HapticService.notification(.error)
                errorMessage = "Не вдалося записатися на сеанс."
                showingError = true
            }
            isBooking = false
        }
    }
}

#Preview {
    BookingTab()
        .environment(UserRepository())
        .environment(AvailabilityRepository())
        .environment(BookingRepository())
        .environment(PaymentRepository())
}
