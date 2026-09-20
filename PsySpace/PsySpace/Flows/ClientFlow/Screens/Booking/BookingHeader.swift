//
//  BookingHeader.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 23.08.2026.
//

import SwiftUI

struct BookingHeader: View {
    let userName: String?
    let nextBooking: Booking?

    var body: some View {
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
        let name = userName?.components(separatedBy: " ").first ?? ""

        if hour < 12 {
            return "Доброго ранку\(name.isEmpty ? "" : ", \(name)")"
        } else if hour < 18 {
            return "Доброго дня\(name.isEmpty ? "" : ", \(name)")"
        } else {
            return "Доброго вечора\(name.isEmpty ? "" : ", \(name)")"
        }
    }

    private var statusText: String {
        if let next = nextBooking {
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
}
