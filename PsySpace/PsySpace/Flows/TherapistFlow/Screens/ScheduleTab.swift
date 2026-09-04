//
//  ScheduleTab.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 23.08.2026.
//

import SwiftUI

struct ScheduleTab: View {
    @Environment(AvailabilityRepository.self) private var availabilityRepo
    @Environment(BookingRepository.self) private var bookingRepo
    @Environment(PaymentRepository.self) private var paymentRepo
    @State private var showingSettings = false
    @State private var bookingToCancel: Booking?
    @State private var cancellationReason = ""
    @State private var bookingToReschedule: Booking?

    var body: some View {
        NavigationStack {
            List {
                statsSection

                upcomingSection

                weeklyScheduleSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.psyspaceBackground)
            .navigationTitle("Розклад")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Налаштування", systemImage: "gearshape") {
                        showingSettings = true
                    }
                }
            }
            .adaptiveSheet(isPresented: $showingSettings, detents: [.large]) {
                AvailabilitySettingsView(repository: availabilityRepo)
            }
            .adaptiveSheet(item: $bookingToCancel, detents: [.medium, .large]) { booking in
                CancelBookingSheet(
                    booking: booking,
                    reason: $cancellationReason,
                    title: "Скасувати сеанс",
                    message: "Сеанс з \(booking.clientName) на \(booking.dateFormatted) о \(booking.startTime.formatted(date: .omitted, time: .shortened))",
                    isTherapist: true
                ) { refund in
                    cancelBooking(booking, refund: refund)
                }
            }
            .adaptiveSheet(item: $bookingToReschedule, detents: [.large]) { booking in
                RescheduleSheet(
                    booking: booking,
                    rescheduledBy: .therapist
                ) {
                    bookingToReschedule = nil
                }
            }
        }
    }

    private func cancelBooking(_ booking: Booking, refund: Bool) {
        Task {
            _ = await bookingRepo.cancelBooking(
                booking.bookingId,
                by: .therapist,
                reason: cancellationReason,
                refund: refund,
                paymentRepo: paymentRepo
            )
            bookingToCancel = nil
        }
    }

    private var statsSection: some View {
        Section {
            HStack {
                StatCard(
                    title: "Цього тижня",
                    value: "\(bookingRepo.sessionsThisWeek)",
                    subtitle: "з \(availabilityRepo.settings.maxSessionsPerWeek)",
                    color: .psyspacePrimary
                )

                StatCard(
                    title: "Тривалість",
                    value: "\(availabilityRepo.settings.sessionDurationMinutes)",
                    subtitle: "хвилин",
                    color: .psyspaceSecondary
                )
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private var upcomingSection: some View {
        Section("Найближчі сеанси") {
            let upcoming = bookingRepo.upcomingBookings()

            if upcoming.isEmpty {
                Text("Немає запланованих сеансів")
                    .foregroundStyle(Color.psyspaceTextSecondary)
            } else {
                ForEach(upcoming.prefix(5)) { booking in
                    BookingRow(
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

    private var weeklyScheduleSection: some View {
        Section("Робочі дні") {
            ForEach(Weekday.allCases) { day in
                WeekdayRow(
                    day: day,
                    schedule: availabilityRepo.settings.weeklySchedule.schedule(for: day.calendarWeekday)
                )
            }
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.psyspaceTextSecondary)

            Text(value)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(color)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(Color.psyspaceTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .psyspaceCard(elevation: .low)
    }
}

private struct BookingRow: View {
    let booking: Booking
    let onReschedule: () -> Void
    let onCancel: () -> Void

    private var hasPendingReschedule: Bool {
        booking.rescheduleRequest?.status == .pending
    }

    private var isCurrentUserRequester: Bool {
        booking.rescheduleRequest?.requestedBy == .therapist
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(booking.clientName)
                        .font(.headline)

                    HStack(spacing: Spacing.xs) {
                        Text(booking.dateFormatted)
                        Text("•")
                        Text(booking.startTime.formatted(date: .omitted, time: .shortened))
                    }
                    .font(.subheadline)
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
    }
}

private struct WeekdayRow: View {
    let day: Weekday
    let schedule: DaySchedule?

    var body: some View {
        HStack {
            Text(day.ukrainianName)
                .foregroundStyle(Color.psyspaceTextPrimary)

            Spacer()

            if let schedule, schedule.isEnabled {
                Text(schedule.formattedSummary)
                    .font(.subheadline)
                    .foregroundStyle(Color.psyspaceTextSecondary)
            } else {
                Text("Вихідний")
                    .font(.subheadline)
                    .foregroundStyle(Color.psyspaceTextSecondary)
            }
        }
    }
}

enum Weekday: Int, CaseIterable, Identifiable {
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    case sunday = 1

    var id: Int { rawValue }
    var calendarWeekday: Int { rawValue }

    var ukrainianName: String {
        switch self {
        case .monday: "Понеділок"
        case .tuesday: "Вівторок"
        case .wednesday: "Середа"
        case .thursday: "Четвер"
        case .friday: "П'ятниця"
        case .saturday: "Субота"
        case .sunday: "Неділя"
        }
    }
}

#Preview {
    ScheduleTab()
        .environment(AvailabilityRepository())
        .environment(BookingRepository())
        .environment(PaymentRepository())
}
