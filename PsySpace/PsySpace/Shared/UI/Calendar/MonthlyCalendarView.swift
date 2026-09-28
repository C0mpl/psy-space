//
//  MonthlyCalendarView.swift
//  PsySpace
//
//  Created by Claude on 27.09.2026.
//

import SwiftUI

struct MonthlyCalendarView: View {
    @Binding var selectedDate: Date
    var bookedDate: Date?
    var isDateAvailable: (Date) -> Bool = { _ in true }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedMonth: Date = .now
    @State private var slideDirection: SlideDirection = .none

    private let calendar = Calendar.current
    private let weekdaySymbols = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Нд"]

    private enum SlideDirection {
        case none, forward, backward
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            monthNavigationHeader
            weekdayHeader
            daysGrid
                .id(displayedMonth)
                .transition(slideTransition)
        }
        .padding(Spacing.md)
        .background(Color.psyspaceCardBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.lg))
        .elevation(.low)
        .clipped()
    }

    private var slideTransition: AnyTransition {
        switch slideDirection {
        case .forward:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        case .none:
            return .opacity
        }
    }

    // MARK: - Month Navigation

    private var monthNavigationHeader: some View {
        HStack {
            Button {
                navigateMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.psyspaceTextSecondary)
                    .frame(width: 32, height: 32)
                    .background(Color.psyspaceBackground)
                    .clipShape(Circle())
            }

            Spacer()

            Text(monthYearString)
                .font(.headline)
                .foregroundStyle(Color.psyspaceTextPrimary)

            Spacer()

            Button {
                navigateMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.psyspaceTextSecondary)
                    .frame(width: 32, height: 32)
                    .background(Color.psyspaceBackground)
                    .clipShape(Circle())
            }
        }
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: displayedMonth).capitalized
    }

    private func navigateMonth(by offset: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) else { return }

        slideDirection = offset > 0 ? .forward : .backward

        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
            displayedMonth = newMonth
        }
        if !reduceMotion {
            HapticService.selection()
        }
    }

    // MARK: - Weekday Header

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.psyspaceTextSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Days Grid

    private var daysGrid: some View {
        let days = generateDaysForMonth()
        let rows = days.chunked(into: 7)

        return VStack(spacing: Spacing.xs) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(week, id: \.id) { day in
                        dayCell(for: day)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(for day: CalendarDay) -> some View {
        if let date = day.date {
            let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
            let isBooked = bookedDate.map { calendar.isDate(date, inSameDayAs: $0) } ?? false
            let isAvailable = isDateAvailable(date)
            let isPast = date < calendar.startOfDay(for: .now)
            let isCurrentMonth = day.isCurrentMonth

            Button {
                guard isCurrentMonth && !isPast && isAvailable else { return }
                withAnimation(reduceMotion ? nil : PsySpaceAnimation.quick) {
                    selectedDate = date
                }
                if !reduceMotion {
                    HapticService.selection()
                }
            } label: {
                Text("\(calendar.component(.day, from: date))")
                    .font(.subheadline.weight(isSelected || isBooked ? .semibold : .regular))
                    .foregroundStyle(dayTextColor(
                        isSelected: isSelected,
                        isBooked: isBooked,
                        isCurrentMonth: isCurrentMonth,
                        isPast: isPast,
                        isAvailable: isAvailable
                    ))
                    .frame(width: 36, height: 36)
                    .background(dayBackground(isSelected: isSelected))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!isCurrentMonth || isPast || !isAvailable)
        } else {
            Color.clear
                .frame(width: 36, height: 36)
        }
    }

    private func dayTextColor(
        isSelected: Bool,
        isBooked: Bool,
        isCurrentMonth: Bool,
        isPast: Bool,
        isAvailable: Bool
    ) -> Color {
        if isSelected {
            return .white
        } else if isBooked {
            return Color.psyspacePrimary
        } else if !isCurrentMonth || isPast {
            return Color.psyspaceTextSecondary.opacity(0.4)
        } else if !isAvailable {
            return Color.psyspaceTextSecondary
        } else {
            return Color.psyspaceTextPrimary
        }
    }

    @ViewBuilder
    private func dayBackground(isSelected: Bool) -> some View {
        if isSelected {
            LinearGradient(
                colors: [Color.psyspacePrimary, Color.psyspaceAccent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color.clear
        }
    }

    // MARK: - Day Generation

    private func generateDaysForMonth() -> [CalendarDay] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let firstWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday
        else {
            return []
        }

        var days: [CalendarDay] = []

        // Adjust for Monday start (Ukrainian calendar starts on Monday)
        let leadingEmptyDays = (firstWeekday + 5) % 7

        // Previous month padding
        if leadingEmptyDays > 0, let previousMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
            let previousMonthRange = calendar.range(of: .day, in: .month, for: previousMonth)!
            let previousMonthDays = previousMonthRange.count

            for i in (previousMonthDays - leadingEmptyDays + 1)...previousMonthDays {
                if let date = calendar.date(from: DateComponents(
                    year: calendar.component(.year, from: previousMonth),
                    month: calendar.component(.month, from: previousMonth),
                    day: i
                )) {
                    days.append(CalendarDay(date: date, isCurrentMonth: false))
                }
            }
        }

        // Current month days
        let daysInMonth = calendar.range(of: .day, in: .month, for: displayedMonth)!
        for day in daysInMonth {
            if let date = calendar.date(from: DateComponents(
                year: calendar.component(.year, from: displayedMonth),
                month: calendar.component(.month, from: displayedMonth),
                day: day
            )) {
                days.append(CalendarDay(date: date, isCurrentMonth: true))
            }
        }

        // Next month padding
        let trailingDays = (7 - (days.count % 7)) % 7
        if trailingDays > 0, let nextMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
            for i in 1...trailingDays {
                if let date = calendar.date(from: DateComponents(
                    year: calendar.component(.year, from: nextMonth),
                    month: calendar.component(.month, from: nextMonth),
                    day: i
                )) {
                    days.append(CalendarDay(date: date, isCurrentMonth: false))
                }
            }
        }

        return days
    }
}

// MARK: - Supporting Types

private struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date?
    let isCurrentMonth: Bool

    init(date: Date?, isCurrentMonth: Bool = true) {
        self.date = date
        self.isCurrentMonth = isCurrentMonth
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

#Preview {
    MonthlyCalendarView(
        selectedDate: .constant(.now),
        bookedDate: Calendar.current.date(byAdding: .day, value: 3, to: .now)
    )
    .padding()
    .background(Color.psyspaceBackground)
}
