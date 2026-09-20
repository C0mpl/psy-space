//
//  BookingEmptyStates.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 23.08.2026.
//

import SwiftUI

struct NoSlotsView: View {
    let nextAvailableDate: Date?
    let selectedDate: Date
    let onNavigateToDate: (Date) -> Void

    var body: some View {
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

            if let nextDate = nextAvailableDate,
               !Calendar.current.isDate(nextDate, inSameDayAs: selectedDate) {
                Button {
                    onNavigateToDate(nextDate)
                } label: {
                    Text("Перейти до \(nextDate.formatted(.dateTime.day().month(.abbreviated)))")
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
}

struct DayOffView: View {
    let nextAvailableDate: Date?
    let onNavigateToDate: (Date) -> Void

    var body: some View {
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

            if let nextDate = nextAvailableDate {
                Button {
                    onNavigateToDate(nextDate)
                } label: {
                    Text("Перейти до \(nextDate.formatted(.dateTime.day().month(.abbreviated)))")
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
}
