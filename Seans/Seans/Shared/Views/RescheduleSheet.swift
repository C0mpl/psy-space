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
            .navigationTitle("Перенести сеанс")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Скасувати") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if let slot = selectedSlot {
                        Button("Готово") {
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
            .filter { !$0.isBooked && $0.startTime > .now }
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
        .padding(Spacing.md)
        .background(Color.seansCardBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.md))
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
            .onChange(of: selectedDate) { _, _ in
                selectedSlot = nil
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
                    SlotButton(
                        slot: slot,
                        isSelected: selectedSlot?.id == slot.id
                    ) {
                        selectedSlot = slot
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
                try await bookingRepo.rescheduleBooking(
                    booking.bookingId,
                    to: slot,
                    newDate: selectedDate,
                    by: rescheduledBy
                )
                dismiss()
                onComplete()
            } catch let error as BookingError {
                switch error {
                case .slotUnavailable:
                    errorMessage = "Цей час вже зайнятий. Оберіть інший."
                default:
                    errorMessage = "Не вдалося перенести сеанс."
                }
                showingError = true
            } catch {
                errorMessage = "Не вдалося перенести сеанс."
                showingError = true
            }
            isLoading = false
        }
    }
}

// MARK: - Slot Button

private struct SlotButton: View {
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
