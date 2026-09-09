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
                VStack(spacing: 0) {
                    headerSection
                        .padding(.bottom, Spacing.lg)

                    if let nextBooking = myUpcomingBookings.first {
                        nextSessionCard(nextBooking)
                            .padding(.horizontal, Spacing.md)
                            .padding(.bottom, Spacing.lg)
                    }

                    if myUpcomingBookings.count > 1 {
                        otherBookingsSection
                            .padding(.horizontal, Spacing.md)
                            .padding(.bottom, Spacing.lg)
                    }

                    bookNewSessionSection
                        .padding(.horizontal, Spacing.md)
                        .padding(.bottom, Spacing.xxl)
                }
            }
            .background(Color.psyspaceBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
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

    // MARK: - Header

    private var headerSection: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    Color.psyspaceBackgroundWarm,
                    Color.psyspaceBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 140)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(greetingText)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.psyspaceTextPrimary)

                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(Color.psyspaceTextSecondary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.md)
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let name = userRepo.currentUser?.name.components(separatedBy: " ").first ?? ""

        if hour < 12 {
            return "Доброго ранку\(name.isEmpty ? "" : ", \(name)")"
        } else if hour < 18 {
            return "Доброго дня\(name.isEmpty ? "" : ", \(name)")"
        } else {
            return "Доброго вечора\(name.isEmpty ? "" : ", \(name)")"
        }
    }

    private var statusText: String {
        if let next = myUpcomingBookings.first {
            let days = Calendar.current.dateComponents([.day], from: .now, to: next.date).day ?? 0
            if days == 0 {
                return "Ваш сеанс сьогодні о \(next.startTime.formatted(date: .omitted, time: .shortened))"
            } else if days == 1 {
                return "Наступний сеанс завтра"
            } else {
                return "Наступний сеанс через \(days) \(dayWord(days))"
            }
        }
        return "Запишіться на сеанс"
    }

    private func dayWord(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod10 == 1 && mod100 != 11 {
            return "день"
        } else if mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20) {
            return "дні"
        } else {
            return "днів"
        }
    }

    // MARK: - Next Session Card

    private func nextSessionCard(_ booking: Booking) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.psyspacePrimary, Color.psyspaceAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    VStack(spacing: -2) {
                        Text(booking.date.formatted(.dateTime.day()))
                            .font(.title2.weight(.bold))
                        Text(booking.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Наступний сеанс")
                        .font(.subheadline)
                        .foregroundStyle(Color.psyspaceTextSecondary)

                    Text(booking.date.formatted(.dateTime.weekday(.wide)))
                        .font(.headline)
                        .foregroundStyle(Color.psyspaceTextPrimary)

                    Text(booking.timeFormatted)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.psyspacePrimary)
                }

                Spacer()

                if !booking.hasPendingReschedule {
                    Menu {
                        Button {
                            bookingToReschedule = booking
                        } label: {
                            Label("Перенести", systemImage: "calendar.badge.clock")
                        }

                        Button(role: .destructive) {
                            cancellationReason = ""
                            bookingToCancel = booking
                        } label: {
                            Label("Скасувати", systemImage: "xmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.psyspaceTextSecondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }

            if booking.hasPendingReschedule {
                Divider()
                    .padding(.vertical, Spacing.sm)

                RescheduleRequestCard(
                    booking: booking,
                    isCurrentUserRequester: booking.rescheduleRequest?.requestedBy == .client
                )
            }
        }
        .psyspaceCard(elevation: .medium)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(Color.psyspacePrimary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Other Bookings

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

    // MARK: - Book New Session

    private var bookNewSessionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Записатися")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.psyspaceTextPrimary)

                Spacer()

                if let nextSlot = nextAvailableSlot {
                    Button {
                        selectedDate = nextSlot.date
                        // Defer to next run loop so onChange(selectedDate) fires first
                        Task { @MainActor in
                            selectedSlot = nextSlot
                            showingPaymentSheet = true
                        }
                    } label: {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "bolt.fill")
                                .font(.caption)
                            Text("Найближчий час")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(Color.psyspacePrimary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(Color.psyspacePrimary.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
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

    private var myUpcomingBookings: [Booking] {
        guard let userId = userRepo.currentUser?.id else { return [] }
        return bookingRepo.upcomingBookings(for: userId)
    }

    private var calendarSection: some View {
        PsySpaceCalendar(
            selectedDate: $selectedDate,
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

    private var timeSlotsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ForEach(groupedSlots, id: \.period) { group in
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: group.period.icon)
                            .font(.caption)
                            .foregroundStyle(Color.psyspaceTextSecondary)

                        Text(group.period.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.psyspaceTextSecondary)
                    }

                    LazyVGrid(columns: AdaptiveGridConfig.timeSlots.columns, spacing: AdaptiveGridConfig.timeSlots.spacing) {
                        ForEach(group.slots) { slot in
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
        }
    }

    private var groupedSlots: [SlotGroup] {
        var morning: [TimeSlot] = []
        var afternoon: [TimeSlot] = []
        var evening: [TimeSlot] = []

        for slot in availableSlots {
            let hour = Calendar.current.component(.hour, from: slot.startTime)
            if hour < 12 {
                morning.append(slot)
            } else if hour < 17 {
                afternoon.append(slot)
            } else {
                evening.append(slot)
            }
        }

        var groups: [SlotGroup] = []
        if !morning.isEmpty { groups.append(SlotGroup(period: .morning, slots: morning)) }
        if !afternoon.isEmpty { groups.append(SlotGroup(period: .afternoon, slots: afternoon)) }
        if !evening.isEmpty { groups.append(SlotGroup(period: .evening, slots: evening)) }
        return groups
    }

    private var noSlotsView: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.psyspaceDecorative1)
                    .frame(width: 80, height: 80)

                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.psyspaceTextSecondary)
            }

            Text("Все зайнято")
                .font(.headline)
                .foregroundStyle(Color.psyspaceTextPrimary)

            Text("На цей день немає вільних слотів.\nСпробуйте обрати інший день.")
                .font(.subheadline)
                .foregroundStyle(Color.psyspaceTextSecondary)
                .multilineTextAlignment(.center)

            if let nextSlot = nextAvailableSlot, !Calendar.current.isDate(nextSlot.date, inSameDayAs: selectedDate) {
                Button {
                    selectedDate = nextSlot.date
                } label: {
                    Text("Перейти до \(nextSlot.date.formatted(.dateTime.day().month(.abbreviated)))")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
                .tint(Color.psyspacePrimary)
                .padding(.top, Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
        .background(Color.psyspaceCardBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.lg))
    }

    private var dayOffView: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.psyspaceDecorative2)
                    .frame(width: 80, height: 80)

                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.psyspaceTextSecondary)
            }

            Text("Вихідний")
                .font(.headline)
                .foregroundStyle(Color.psyspaceTextPrimary)

            Text("Терапевт відпочиває в цей день.\nОберіть робочий день.")
                .font(.subheadline)
                .foregroundStyle(Color.psyspaceTextSecondary)
                .multilineTextAlignment(.center)

            if let nextSlot = nextAvailableSlot {
                Button {
                    selectedDate = nextSlot.date
                } label: {
                    Text("Перейти до \(nextSlot.date.formatted(.dateTime.day().month(.abbreviated)))")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
                .tint(Color.psyspacePrimary)
                .padding(.top, Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
        .background(Color.psyspaceCardBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.lg))
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

// MARK: - Supporting Types

private enum TimePeriod: String, CaseIterable {
    case morning
    case afternoon
    case evening

    var title: String {
        switch self {
        case .morning: "Ранок"
        case .afternoon: "День"
        case .evening: "Вечір"
        }
    }

    var icon: String {
        switch self {
        case .morning: "sunrise.fill"
        case .afternoon: "sun.max.fill"
        case .evening: "sunset.fill"
        }
    }
}

private struct SlotGroup {
    let period: TimePeriod
    let slots: [TimeSlot]
}

// MARK: - Compact Booking Row

private struct CompactBookingRow: View {
    let booking: Booking
    let onReschedule: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.psyspacePrimary)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(booking.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.psyspaceTextPrimary)

                Text(booking.timeFormatted)
                    .font(.caption)
                    .foregroundStyle(Color.psyspaceTextSecondary)
            }

            Spacer()

            if booking.hasPendingReschedule {
                Text("Перенос")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.psyspaceWarning)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 2)
                    .background(Color.psyspaceWarning.opacity(0.15))
                    .clipShape(Capsule())
            } else {
                Menu {
                    Button {
                        onReschedule()
                    } label: {
                        Label("Перенести", systemImage: "calendar.badge.clock")
                    }

                    Button(role: .destructive) {
                        onCancel()
                    } label: {
                        Label("Скасувати", systemImage: "xmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.psyspaceTextSecondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(Color.psyspaceCardBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.sm))
    }
}

// MARK: - Custom Calendar

private struct PsySpaceCalendar: View {
    @Binding var selectedDate: Date
    var isDateAvailable: (Date) -> Bool = { _ in true }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrollPosition: Date?

    private let calendar = Calendar.current
    private let daysToShow = 60 // Show ~2 months ahead

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            monthYearHeader

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Spacing.sm) {
                    ForEach(availableDates, id: \.self) { date in
                        DayCard(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            isAvailable: isDateAvailable(date),
                            showMonth: shouldShowMonth(for: date)
                        ) {
                            withAnimation(reduceMotion ? nil : PsySpaceAnimation.quick) {
                                selectedDate = date
                            }
                            if !reduceMotion {
                                HapticService.selection()
                            }
                        }
                        .id(date)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, Spacing.md)
            }
            .scrollPosition(id: $scrollPosition, anchor: .leading)
            .scrollTargetBehavior(.viewAligned)
            .frame(height: 96)
            .onAppear {
                scrollPosition = calendar.startOfDay(for: selectedDate)
            }
        }
        .padding(.vertical, Spacing.md)
        .background(Color.psyspaceCardBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.lg))
        .elevation(.low)
    }

    private var monthYearHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedMonthYear)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.psyspaceTextPrimary)

                Text(selectedWeekday)
                    .font(.subheadline)
                    .foregroundStyle(Color.psyspaceTextSecondary)
            }

            Spacer()

            Button {
                withAnimation(reduceMotion ? nil : PsySpaceAnimation.standard) {
                    selectedDate = .now
                    scrollPosition = calendar.startOfDay(for: .now)
                }
                if !reduceMotion {
                    HapticService.selection()
                }
            } label: {
                Text("Сьогодні")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.psyspacePrimary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.psyspacePrimary.opacity(0.1))
                    .clipShape(Capsule())
            }
            .opacity(calendar.isDateInToday(selectedDate) ? 0.5 : 1)
        }
        .padding(.horizontal, Spacing.md)
    }

    private var selectedMonthYear: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: selectedDate)
    }

    private var selectedWeekday: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: selectedDate).capitalized
    }

    private var availableDates: [Date] {
        let startOfToday = calendar.startOfDay(for: .now)
        return (0..<daysToShow).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startOfToday)
        }
    }

    private func shouldShowMonth(for date: Date) -> Bool {
        let day = calendar.component(.day, from: date)
        return day == 1
    }
}

// MARK: - Day Card

private struct DayCard: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isAvailable: Bool
    let showMonth: Bool
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let calendar = Calendar.current

    private var dayNumber: String {
        "\(calendar.component(.day, from: date))"
    }

    private var weekdayShort: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.dateFormat = "EE"
        return formatter.string(from: date).uppercased()
    }

    private var monthShort: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.dateFormat = "MMM"
        return formatter.string(from: date).uppercased()
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Spacing.xxs) {
                if showMonth {
                    Text(monthShort)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : Color.psyspacePrimary)
                } else {
                    Text(weekdayShort)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : Color.psyspaceTextSecondary)
                }

                Text(dayNumber)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(textColor)

                // Availability indicator
                if isAvailable && !isSelected {
                    Circle()
                        .fill(Color.psyspaceSecondary)
                        .frame(width: 6, height: 6)
                } else if isSelected && isAvailable {
                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 56, height: 76)
            .background(backgroundView)
            .clipShape(.rect(cornerRadius: CornerRadius.md))
            .overlay(borderOverlay)
            .scaleEffect(isSelected && !reduceMotion ? 1.05 : 1.0)
            .animation(reduceMotion ? nil : PsySpaceAnimation.quick, value: isSelected)
        }
        .buttonStyle(.plain)
    }

    private var textColor: Color {
        if isSelected {
            return .white
        } else if !isAvailable {
            return Color.psyspaceTextSecondary.opacity(0.5)
        } else {
            return Color.psyspaceTextPrimary
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        if isSelected {
            LinearGradient(
                colors: [Color.psyspacePrimary, Color.psyspaceAccent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isToday {
            Color.psyspaceHighlight.opacity(0.5)
        } else {
            Color.psyspaceBackground
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        if isToday && !isSelected {
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(Color.psyspacePrimary, lineWidth: 2)
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
