//
//  RescheduleSheet.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 25.08.2026.
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
                .background(Color.psyspaceBackground)

                if isLoading {
                    PsySpaceLoadingOverlay(message: "Надсилаємо запит...")
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

    private var selectedWeekday: Int {
        Calendar.current.component(.weekday, from: selectedDate)
    }

    private var availableSlots: [TimeSlot] {
        let existingBookings = bookingRepo.bookings(for: selectedDate)
            .filter { $0.id != booking.id }
        return availabilityRepo.generateTimeSlots(for: selectedDate, existingBookings: existingBookings)
            .filter { slot in
                guard !slot.isBooked && slot.startTime > .now else { return false }

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

    private var currentBookingCard: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Поточний час")
                .font(.subheadline)
                .foregroundStyle(Color.psyspaceTextSecondary)

            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(Color.psyspacePrimary)
                Text(booking.dateFormatted)
                Text("о")
                    .foregroundStyle(Color.psyspaceTextSecondary)
                Text(booking.startTime.formatted(date: .omitted, time: .shortened))
                    .fontWeight(.medium)
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .psyspaceCard(elevation: .low)
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Нова дата")
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

    private var slotsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Новий час")
                .font(.headline)
                .foregroundStyle(Color.psyspaceTextPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: Spacing.sm) {
                ForEach(availableSlots) { slot in
                    Button {
                        withAnimation(reduceMotion ? nil : PsySpaceAnimation.quick) {
                            selectedSlot = slot
                        }
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
        .padding(.vertical, Spacing.xl)
    }

    private var dayOffView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.psyspaceTextSecondary)

            Text("Вихідний день")
                .font(.headline)
                .foregroundStyle(Color.psyspaceTextPrimary)

            Text("Оберіть інший день.")
                .font(.subheadline)
                .foregroundStyle(Color.psyspaceTextSecondary)
        }
        .padding(.vertical, Spacing.xl)
    }

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
