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
    var onNotificationsTap: (() -> Void)?

    var body: some View {
        VStack {
            // Content
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(currentDateString)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.psyspaceTextSecondary)

                    Text(greetingText)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.psyspaceTextPrimary)
                        .tracking(-0.5)

                    HStack(spacing: Spacing.xs) {
                        Circle()
                            .fill(Color.psyspaceSecondary)
                            .frame(width: 8, height: 8)

                        Text(statusText)
                            .font(.subheadline)
                            .foregroundStyle(Color.psyspaceTextSecondary)
                    }
                    .padding(.top, Spacing.xxs)
                }

                Spacer()

                if let onNotificationsTap {
                    Button(action: onNotificationsTap) {
                        Image(systemName: "bell")
                            .font(.body)
                            .foregroundStyle(Color.psyspaceTextPrimary)
                            .frame(width: 44, height: 44)
                            .background(Color.psyspaceCardBackground.opacity(0.8))
                            .clipShape(Circle())
                            .shadow(color: Color.psyspaceTextPrimary.opacity(0.06), radius: 4, y: 2)
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .background {
            GeometryReader { geo in
                ZStack(alignment: .topTrailing) {
                    LinearGradient(
                        colors: [
                            Color.psyspaceHighlight,
                            Color.psyspaceBackground
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: geo.size.height + 100)
                    .offset(y: -100) // Extend into safe area

                    Circle()
                        .fill(Color.psyspacePrimary.opacity(0.2))
                        .frame(width: 176, height: 176)
                        .blur(radius: 40)
                        .offset(x: 40, y: -56)
                }
            }
        }
    }

    private var currentDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: .now).capitalized
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
                return "Наступна сесія через \(days) \(dayWord(days))"
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
