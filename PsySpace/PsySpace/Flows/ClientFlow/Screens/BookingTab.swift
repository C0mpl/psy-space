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
                    if !myUpcomingBookings.isEmpty {
                        myBookingsSection
                    }

                    calendarSection

                    if !availableSlots.isEmpty {
                        timeSlotsSection
                    } else if availabilityRepo.isWorkingDay(selectedWeekday) {
                        noSlotsView
                    } else {
                        dayOffView
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Color.psyspaceBackground)
            .navigationTitle("Запис")
            .adaptiveSheet(isPresented: $showingPaymentSheet, detents: [.large]) {
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

    private var selectedWeekday: Int {
        Calendar.current.component(.weekday, from: selectedDate)
    }

    private var availableSlots: [TimeSlot] {
        let existingBookings = bookingRepo.bookings(for: selectedDate)
        return availabilityRepo.generateTimeSlots(for: selectedDate, existingBookings: existingBookings)
            .filter { !$0.isBooked && $0.startTime > .now }
    }

    private var myUpcomingBookings: [Booking] {
        guard let userId = userRepo.currentUser?.id else { return [] }
        return bookingRepo.upcomingBookings(for: userId)
    }

    private var myBookingsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Мої записи")
                .font(.headline)
                .foregroundStyle(Color.psyspaceTextPrimary)

            VStack(spacing: Spacing.sm) {
                ForEach(myUpcomingBookings) { booking in
                    MyBookingCard(
                        booking: booking,
                        onReschedule: {
                            bookingToReschedule = booking
                        },
                        onCancel: {
                            cancellationReason = ""
                            bookingToCancel = booking
                        }
                    )
                }
            }
        }
    }

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Оберіть дату")
                .font(.headline)
                .foregroundStyle(Color.psyspaceTextPrimary)

            DatePicker(
                "Дата",
                selection: $selectedDate,
                in: .now...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(Color.psyspacePrimary)
            .padding(Spacing.sm)
            .background(Color.psyspaceCardBackground)
            .clipShape(.rect(cornerRadius: CornerRadius.lg))
            .elevation(.low)
            .onChange(of: selectedDate) { _, _ in
                selectedSlot = nil
                if !reduceMotion {
                    HapticService.selection()
                }
            }
        }
    }

    private var timeSlotsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Доступний час")
                .font(.headline)
                .foregroundStyle(Color.psyspaceTextPrimary)

            LazyVGrid(columns: AdaptiveGridConfig.timeSlots.columns, spacing: AdaptiveGridConfig.timeSlots.spacing) {
                ForEach(availableSlots) { slot in
                    Button {
                        withAnimation(reduceMotion ? nil : PsySpaceAnimation.quick) {
                            selectedSlot = slot
                        }
                        showingPaymentSheet = true
                    } label: {
                        Text(slot.startTimeFormatted)
                    }
                    .buttonStyle(PsySpaceSlotButtonStyle(isSelected: selectedSlot?.id == slot.id))
                }
            }
        }
    }

    private var noSlotsView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(Color.psyspaceTextSecondary)

            Text("Немає вільного часу")
                .font(.headline)
                .foregroundStyle(Color.psyspaceTextPrimary)

            Text("На цей день всі слоти зайняті.\nОберіть інший день.")
                .font(.subheadline)
                .foregroundStyle(Color.psyspaceTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, Spacing.xxl)
    }

    private var dayOffView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.psyspaceTextSecondary)

            Text("Вихідний день")
                .font(.headline)
                .foregroundStyle(Color.psyspaceTextPrimary)

            Text("Терапевт не працює в цей день.\nОберіть інший день.")
                .font(.subheadline)
                .foregroundStyle(Color.psyspaceTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, Spacing.xxl)
    }

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
                    try await FirestoreService.shared.useUserCredit(userId: user.id, amount: usedCredit)
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

private struct MyBookingCard: View {
    @Environment(UserRepository.self) private var userRepo

    let booking: Booking
    let onReschedule: () -> Void
    let onCancel: () -> Void

    private var hasPendingReschedule: Bool {
        booking.rescheduleRequest?.status == .pending
    }

    private var isCurrentUserRequester: Bool {
        booking.rescheduleRequest?.requestedBy == .client
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(booking.dateFormatted)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.psyspaceTextPrimary)

                    Text(booking.timeFormatted)
                        .font(.caption)
                        .foregroundStyle(Color.psyspaceTextSecondary)
                }

                Spacer()

                if !hasPendingReschedule {
                    HStack(spacing: Spacing.sm) {
                        Button("Перенести сеанс", systemImage: "calendar.badge.clock", action: onReschedule)
                            .labelStyle(.iconOnly)
                            .font(.title3)
                            .foregroundStyle(Color.psyspacePrimary)
                            .buttonStyle(PsySpaceIconButtonStyle())

                        Button("Скасувати сеанс", systemImage: "xmark.circle.fill", role: .destructive, action: onCancel)
                            .labelStyle(.iconOnly)
                            .font(.title3)
                            .foregroundStyle(Color.psyspaceError)
                            .buttonStyle(PsySpaceIconButtonStyle())
                    }
                }
            }

            if hasPendingReschedule {
                RescheduleRequestCard(
                    booking: booking,
                    isCurrentUserRequester: isCurrentUserRequester
                )
            }
        }
        .psyspaceCard(elevation: .low)
    }
}

#Preview {
    BookingTab()
        .environment(UserRepository())
        .environment(AvailabilityRepository())
        .environment(BookingRepository())
        .environment(PaymentRepository())
}
