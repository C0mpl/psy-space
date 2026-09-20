//
//  PsySpaceCalendar.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 23.08.2026.
//

import SwiftUI

struct PsySpaceCalendar: View {
    @Binding var selectedDate: Date
    var isDateAvailable: (Date) -> Bool = { _ in true }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrollPosition: Date?

    private let calendar = Calendar.current
    private let daysToShow = 60

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
