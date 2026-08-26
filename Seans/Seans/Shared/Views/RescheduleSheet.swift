//
//  RescheduleSheet.swift
//  Seans
//
//  Created by Claude on 25.08.2026.
//

import SwiftUI

struct RescheduleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AvailabilityRepository.self) private var availabilityRepo
    @Environment(BookingRepository.self) private var bookingRepo
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let booking: Booking
    let rescheduledBy: CancelledBy
    let onComplete: () -> Void

    @State private var selectedDate: Date = .now
    @State private var selectedSlot: TimeSlot?
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        currentBookingCard

                        dateSection

                        if !availableSlots.isEmpty {
                            slotsSection
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

                if isLoading {
                    SeansLoadingOverlay(message: "Надсилаємо запит...")
                }
            }
            .navigationTitle("Запит на перенесення")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Скасувати") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if let slot = selectedSlot {
                        Button("Надіслати") {
                            reschedule(to: slot)
                        }
                        .fontWeight(.semibold)
                        .disabled(isLoading)
                    }
                }
            }
            .alert("Помилка", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Не вдалося перенести сеанс")
            }
        }
    }

    // MARK: - Computed

    private var selectedWeekday: Int {
        Calendar.current.component(.weekday, from: selectedDate)
    }

    private var availableSlots: [TimeSlot] {
        let existingBookings = bookingRepo.bookings(for: selectedDate)
            .filter { $0.id != booking.id } // Exclude current booking
        return availabilityRepo.generateTimeSlots(for: selectedDate, existingBookings: existingBookings)
            .filter { slot in
                // Exclude booked slots and past slots
                guard !slot.isBooked && slot.startTime > .now else { return false }

                // Exclude the current booking's slot if same date
                if Calendar.current.isDate(selectedDate, inSameDayAs: booking.date) {
                    let bookingHour = Calendar.current.component(.hour, from: booking.startTime)
                    let bookingMinute = Calendar.current.component(.minute, from: booking.startTime)
                    let slotHour = Calendar.current.component(.hour, from: slot.startTime)
                    let slotMinute = Calendar.current.component(.minute, from: slot.startTime)

                    if bookingHour == slotHour && bookingMinute == slotMinute {
                        return false
                    }
                }

                return true
            }
    }

    // MARK: - Views

    private var currentBookingCard: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Поточний час")
                .font(.subheadline)
                .foregroundStyle(Color.seansTextSecondary)

            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(Color.seansPrimary)
                Text(booking.dateFormatted)
                Text("о")
                    .foregroundStyle(Color.seansTextSecondary)
                Text(booking.startTime.formatted(date: .omitted, time: .shortened))
                    .fontWeight(.medium)
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .seansCard(elevation: .low)
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Нова дата")
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
            .elevation(.low)
            .onChange(of: selectedDate) { _, _ in
                selectedSlot = nil
                if !reduceMotion {
                    HapticService.selection()
                }
            }
        }
    }

    private var slotsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Новий час")
                .font(.headline)
                .foregroundStyle(Color.seansTextPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: Spacing.sm) {
                ForEach(availableSlots) { slot in
                    Button {
                        withAnimation(reduceMotion ? nil : SeansAnimation.quick) {
                            selectedSlot = slot
                        }
                    } label: {
                        Text(slot.startTimeFormatted)
                    }
                    .buttonStyle(SeansSlotButtonStyle(isSelected: selectedSlot?.id == slot.id))
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
        .padding(.vertical, Spacing.xl)
    }

    private var dayOffView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.seansTextSecondary)

            Text("Вихідний день")
                .font(.headline)
                .foregroundStyle(Color.seansTextPrimary)

            Text("Оберіть інший день.")
                .font(.subheadline)
                .foregroundStyle(Color.seansTextSecondary)
        }
        .padding(.vertical, Spacing.xl)
    }

    // MARK: - Actions

    private func reschedule(to slot: TimeSlot) {
        isLoading = true

        Task {
            do {
                try await bookingRepo.requestReschedule(
                    booking.bookingId,
                    to: slot,
                    newDate: selectedDate,
                    by: rescheduledBy
                )
                HapticService.notification(.success)
                dismiss()
                onComplete()
            } catch let error as BookingError {
                HapticService.notification(.error)
                switch error {
                case .slotUnavailable:
                    errorMessage = "Цей час вже зайнятий. Оберіть інший."
                default:
                    errorMessage = "Не вдалося надіслати запит."
                }
                showingError = true
            } catch {
                HapticService.notification(.error)
                errorMessage = "Не вдалося надіслати запит."
                showingError = true
            }
            isLoading = false
        }
    }
}

#Preview {
    RescheduleSheet(
        booking: Booking(
            clientId: "1",
            clientName: "Тест",
            date: .now,
            startTime: .now,
            endTime: .now.addingTimeInterval(3600)
        ),
        rescheduledBy: .client,
        onComplete: {}
    )
    .environment(AvailabilityRepository())
    .environment(BookingRepository())
}
