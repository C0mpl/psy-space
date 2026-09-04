//
//  AvailabilitySettingsView.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 24.08.2026.
//

import SwiftUI

struct AvailabilitySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var repository: AvailabilityRepository

    var body: some View {
        NavigationStack {
            List {
                generalSection

                scheduleSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.psyspaceBackground)
            .navigationTitle("Налаштування")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var generalSection: some View {
        Section("Загальні") {
            HStack {
                Text("Ціна сеансу")
                Spacer()
                TextField("", value: Binding(
                    get: { repository.settings.sessionPriceUAH },
                    set: { repository.updateSessionPrice($0) }
                ), format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                Text("\u{20B4}")
                    .foregroundStyle(Color.psyspaceTextSecondary)
            }

            Stepper(
                "Макс. сеансів на тиждень: \(repository.settings.maxSessionsPerWeek)",
                value: Binding(
                    get: { repository.settings.maxSessionsPerWeek },
                    set: { repository.updateMaxSessions($0) }
                ),
                in: 1...50
            )

            Picker("Тривалість сеансу", selection: Binding(
                get: { repository.settings.sessionDurationMinutes },
                set: { repository.updateSessionDuration($0) }
            )) {
                Text("30 хв").tag(30)
                Text("45 хв").tag(45)
                Text("60 хв").tag(60)
                Text("90 хв").tag(90)
                Text("120 хв").tag(120)
            }

            Picker("Перерва між сеансами", selection: Binding(
                get: { repository.settings.breakBetweenSessionsMinutes },
                set: { repository.updateBreakDuration($0) }
            )) {
                Text("Без перерви").tag(0)
                Text("10 хв").tag(10)
                Text("15 хв").tag(15)
                Text("30 хв").tag(30)
            }
        }
    }

    private var scheduleSection: some View {
        Section("Робочі години") {
            ForEach(Weekday.allCases) { day in
                DayScheduleRow(
                    day: day,
                    schedule: scheduleBinding(for: day.calendarWeekday)
                )
            }
        }
    }

    private func scheduleBinding(for weekday: Int) -> Binding<DaySchedule?> {
        Binding(
            get: { repository.settings.weeklySchedule.schedule(for: weekday) },
            set: { repository.updateDaySchedule($0, for: weekday) }
        )
    }
}

private struct DayScheduleRow: View {
    let day: Weekday
    @Binding var schedule: DaySchedule?

    @State private var isExpanded = false

    private var isEnabled: Bool { schedule?.isEnabled ?? false }
    private var timeWindows: [TimeWindow] { schedule?.timeWindows ?? [] }
    private var maxSessions: Int? { schedule?.maxSessionsPerDay }
    private var hasLimit: Bool { maxSessions != nil }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: Spacing.md) {
                Toggle("Робочий день", isOn: Binding(
                    get: { isEnabled },
                    set: { newValue in
                        if newValue {
                            schedule = DaySchedule()
                        } else {
                            schedule = nil
                        }
                    }
                ))

                if isEnabled {
                    ForEach(Array(timeWindows.enumerated()), id: \.element.id) { index, window in
                        TimeWindowRow(
                            window: window,
                            index: index,
                            canDelete: timeWindows.count > 1,
                            onUpdate: { updated in
                                updateWindow(at: index, with: updated)
                            },
                            onDelete: {
                                deleteWindow(at: index)
                            }
                        )

                        if index < timeWindows.count - 1 {
                            Divider()
                        }
                    }

                    Button {
                        addWindow()
                    } label: {
                        Label("Додати вікно", systemImage: "plus.circle")
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.psyspacePrimary)

                    Divider()

                    Toggle("Обмежити кількість сеансів", isOn: Binding(
                        get: { hasLimit },
                        set: { newValue in
                            updateMaxSessions(newValue ? 4 : nil)
                        }
                    ))

                    if hasLimit {
                        Stepper(
                            "Макс. сеансів: \(maxSessions ?? 4)",
                            value: Binding(
                                get: { maxSessions ?? 4 },
                                set: { updateMaxSessions($0) }
                            ),
                            in: 1...12
                        )
                    }
                }
            }
        } label: {
            HStack {
                Text(day.ukrainianName)

                Spacer()

                if isEnabled {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(schedule?.formattedSummary ?? "")
                            .font(.caption)
                            .foregroundStyle(Color.psyspaceTextSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)

                        if let max = maxSessions {
                            Text("до \(max) сеансів")
                                .font(.caption2)
                                .foregroundStyle(Color.psyspacePrimary)
                        }
                    }
                } else {
                    Text("Вихідний")
                        .font(.caption)
                        .foregroundStyle(Color.psyspaceTextSecondary)
                }
            }
        }
    }

    private func updateWindow(at index: Int, with window: TimeWindow) {
        guard var current = schedule else { return }
        guard index < current.timeWindows.count else { return }
        current.timeWindows[index] = window
        schedule = current
    }

    private func deleteWindow(at index: Int) {
        guard var current = schedule else { return }
        guard current.timeWindows.count > 1 else { return }
        current.timeWindows.remove(at: index)
        schedule = current
    }

    private func addWindow() {
        guard var current = schedule else { return }

        let lastWindow = current.timeWindows.last
        let newStartHour = (lastWindow?.endTime.hour ?? 12) + 1
        let newEndHour = min(newStartHour + 4, 22)

        let newWindow = TimeWindow(
            startTime: TimeOfDay(hour: newStartHour, minute: 0),
            endTime: TimeOfDay(hour: newEndHour, minute: 0)
        )
        current.timeWindows.append(newWindow)
        schedule = current
    }

    private func updateMaxSessions(_ value: Int?) {
        guard var current = schedule else { return }
        current.maxSessionsPerDay = value
        schedule = current
    }
}

private struct TimeWindowRow: View {
    let window: TimeWindow
    let index: Int
    let canDelete: Bool
    let onUpdate: (TimeWindow) -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                if index == 0 {
                    Text("Робочий час")
                        .font(.subheadline.weight(.medium))
                } else {
                    Text("Вікно \(index + 1)")
                        .font(.subheadline.weight(.medium))
                }

                Spacer()

                if canDelete {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.psyspaceError)
                }
            }

            HStack {
                Text("Початок")
                Spacer()
                TimePicker(
                    hour: Binding(
                        get: { window.startTime.hour },
                        set: { hour in
                            var updated = window
                            updated.startTime.hour = hour
                            onUpdate(updated)
                        }
                    ),
                    minute: Binding(
                        get: { window.startTime.minute },
                        set: { minute in
                            var updated = window
                            updated.startTime.minute = minute
                            onUpdate(updated)
                        }
                    )
                )
            }

            HStack {
                Text("Кінець")
                Spacer()
                TimePicker(
                    hour: Binding(
                        get: { window.endTime.hour },
                        set: { hour in
                            var updated = window
                            updated.endTime.hour = hour
                            onUpdate(updated)
                        }
                    ),
                    minute: Binding(
                        get: { window.endTime.minute },
                        set: { minute in
                            var updated = window
                            updated.endTime.minute = minute
                            onUpdate(updated)
                        }
                    )
                )
            }

            if !window.isValid {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Час закінчення має бути пізніше початку")
                }
                .font(.caption)
                .foregroundStyle(Color.psyspaceError)
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}

private struct TimePicker: View {
    @Binding var hour: Int
    @Binding var minute: Int

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Picker("", selection: $hour) {
                ForEach(6..<23, id: \.self) { h in
                    Text(h, format: .number.precision(.integerLength(2))).tag(h)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 60)

            Text(":")
                .foregroundStyle(Color.psyspaceTextSecondary)

            Picker("", selection: $minute) {
                ForEach([0, 15, 30, 45], id: \.self) { m in
                    Text(m, format: .number.precision(.integerLength(2))).tag(m)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 60)
        }
    }
}

#Preview {
    AvailabilitySettingsView(repository: AvailabilityRepository())
}
