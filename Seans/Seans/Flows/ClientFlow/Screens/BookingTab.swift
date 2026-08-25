//
//  BookingTab.swift
//  Seans
//
//  Created by Claude on 23.08.2026.
//

import SwiftUI

struct BookingTab: View {
    @Environment(UserRepository.self) private var userRepo
    @Environment(AvailabilityRepository.self) private var availabilityRepo
    @Environment(BookingRepository.self) private var bookingRepo

    @State private var selectedDate: Date = .now
    @State private var selectedSlot: TimeSlot?
    @State private var showingConfirmation = false
    @State private var showingError = false
    @State private var errorMessage: String?
    @State private var bookingToCancel: Booking?
    @State private var cancellationReason = ""
    @State private var bookingToReschedule: Booking?

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
            .background(Color.seansBackground)
            .navigationTitle("Запис")
            .confirmationDialog(
                "Підтвердити запис",
                isPresented: $showingConfirmation,
                presenting: selectedSlot
            ) { slot in
                Button("Записатись на \(slot.startTimeFormatted)") {
                    bookSlot(slot)
                }
                Button("Скасувати", role: .cancel) {
                    selectedSlot = nil
                }
            } message: { slot in
                Text("Записатись на сеанс \(selectedDate.formatted(date: .long, time: .omitted)) о \(slot.startTimeFormatted)?")
            }
            .alert("Помилка", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Не вдалося записатися на сеанс")
            }
            .sheet(item: $bookingToCancel) { booking in
                CancelBookingSheet(
                    booking: booking,
                    reason: $cancellationReason,
                    title: "Скасувати запис",
                    message: "Запис на \(booking.dateFormatted) о \(booking.startTime.formatted(date: .omitted, time: .shortened))"
                ) {
                    cancelBooking(booking)
                }
            }
            .sheet(item: $bookingToReschedule) { booking in
                RescheduleSheet(
                    booking: booking,
                    rescheduledBy: .client
                ) {
                    bookingToReschedule = nil
                }
            }
        }
    }

    // MARK: - Computed

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

    // MARK: - Sections

    private var myBookingsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Мої записи")
                .font(.headline)
                .foregroundStyle(Color.seansTextPrimary)

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
                .foregroundStyle(Color.seansTextPrimary)

            DatePicker(
                "Дата",
                selection: $selectedDate,
                in: .now...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(Color.seansPrimary)
            .padding(Spacing.sm)
            .background(Color.seansCardBackground)
            .clipShape(.rect(cornerRadius: CornerRadius.lg))
        }
    }

    private var timeSlotsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Доступний час")
                .font(.headline)
                .foregroundStyle(Color.seansTextPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: Spacing.sm) {
                ForEach(availableSlots) { slot in
                    TimeSlotButton(
                        slot: slot,
                        isSelected: selectedSlot?.id == slot.id
                    ) {
                        selectedSlot = slot
                        showingConfirmation = true
                    }
                }
            }
        }
    }

    private var noSlotsView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(Color.seansTextSecondary)

            Text("Немає вільного часу")
                .font(.headline)
                .foregroundStyle(Color.seansTextPrimary)

            Text("На цей день всі слоти зайняті.\nОберіть інший день.")
                .font(.subheadline)
                .foregroundStyle(Color.seansTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, Spacing.xxl)
    }

    private var dayOffView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.seansTextSecondary)

            Text("Вихідний день")
                .font(.headline)
                .foregroundStyle(Color.seansTextPrimary)

            Text("Терапевт не працює в цей день.\nОберіть інший день.")
                .font(.subheadline)
                .foregroundStyle(Color.seansTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, Spacing.xxl)
    }

    // MARK: - Actions

    private func cancelBooking(_ booking: Booking) {
        Task {
            await bookingRepo.cancelBooking(booking.bookingId, by: .client, reason: cancellationReason)
            bookingToCancel = nil
        }
    }

    private func bookSlot(_ slot: TimeSlot) {
        guard let user = userRepo.currentUser else { return }

        let weekday = Calendar.current.component(.weekday, from: selectedDate)
        let maxSessions = availabilityRepo.settings.weeklySchedule.schedule(for: weekday)?.maxSessionsPerDay

        Task {
            do {
                try await bookingRepo.createBooking(
                    clientId: user.id,
                    clientName: user.name,
                    date: selectedDate,
                    slot: slot,
                    maxSessionsPerDay: maxSessions
                )
                selectedSlot = nil
            } catch let error as BookingError {
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
                errorMessage = "Не вдалося записатися на сеанс."
                showingError = true
            }
        }
    }
}

// MARK: - My Booking Card

private struct MyBookingCard: View {
    let booking: Booking
    let onReschedule: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(booking.dateFormatted)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.seansTextPrimary)

                Text(booking.timeFormatted)
                    .font(.caption)
                    .foregroundStyle(Color.seansTextSecondary)
            }

            Spacer()

            HStack(spacing: Spacing.sm) {
                Button(action: onReschedule) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title3)
                        .foregroundStyle(Color.seansPrimary)
                }
                .buttonStyle(.plain)

                Button(role: .destructive, action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.red.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.md)
        .background(Color.seansCardBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.md))
    }
}

// MARK: - Time Slot Button

private struct TimeSlotButton: View {
    let slot: TimeSlot
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(slot.startTimeFormatted)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .white : Color.seansTextPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(isSelected ? Color.seansPrimary : Color.seansCardBackground)
                .clipShape(.rect(cornerRadius: CornerRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .stroke(Color.seansPrimary.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    BookingTab()
        .environment(UserRepository())
        .environment(AvailabilityRepository())
        .environment(BookingRepository())
}
