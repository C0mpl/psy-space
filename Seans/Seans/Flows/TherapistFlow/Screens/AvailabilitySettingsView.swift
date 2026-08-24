//
//  AvailabilitySettingsView.swift
//  Seans
//
//  Created by Claude on 24.08.2026.
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

    // MARK: - Sections

    private var generalSection: some View {
        Section("Загальні") {
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
                    schedule: repository.settings.weeklySchedule.schedule(for: day.calendarWeekday),
                    onChange: { schedule in
                        repository.updateDaySchedule(schedule, for: day.calendarWeekday)
                    }
                )
            }
        }
    }
}

// MARK: - Day Schedule Row

private struct DayScheduleRow: View {
    let day: Weekday
    let schedule: DaySchedule?
    let onChange: (DaySchedule?) -> Void

    @State private var isExpanded = false
    @State private var isEnabled: Bool
    @State private var startHour: Int
    @State private var startMinute: Int
    @State private var endHour: Int
    @State private var endMinute: Int

    init(day: Weekday, schedule: DaySchedule?, onChange: @escaping (DaySchedule?) -> Void) {
        self.day = day
        self.schedule = schedule
        self.onChange = onChange
        self._isEnabled = State(initialValue: schedule?.isEnabled ?? false)
        self._startHour = State(initialValue: schedule?.startTime.hour ?? 9)
        self._startMinute = State(initialValue: schedule?.startTime.minute ?? 0)
        self._endHour = State(initialValue: schedule?.endTime.hour ?? 17)
        self._endMinute = State(initialValue: schedule?.endTime.minute ?? 0)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: Spacing.md) {
                Toggle("Робочий день", isOn: $isEnabled)
                    .onChange(of: isEnabled) { _, newValue in
                        updateSchedule()
                    }

                if isEnabled {
                    HStack {
                        Text("Початок")
                        Spacer()
                        TimePicker(hour: $startHour, minute: $startMinute)
                            .onChange(of: startHour) { _, _ in updateSchedule() }
                            .onChange(of: startMinute) { _, _ in updateSchedule() }
                    }

                    HStack {
                        Text("Кінець")
                        Spacer()
                        TimePicker(hour: $endHour, minute: $endMinute)
                            .onChange(of: endHour) { _, _ in updateSchedule() }
                            .onChange(of: endMinute) { _, _ in updateSchedule() }
                    }
                }
            }
        } label: {
            HStack {
                Text(day.ukrainianName)

                Spacer()

                if isEnabled {
                    Text("\(formattedTime(startHour, startMinute)) - \(formattedTime(endHour, endMinute))")
                        .font(.caption)
                        .foregroundStyle(Color.seansTextSecondary)
                } else {
                    Text("Вихідний")
                        .font(.caption)
                        .foregroundStyle(Color.seansTextSecondary)
                }
            }
        }
    }

    private func formattedTime(_ hour: Int, _ minute: Int) -> String {
        let hourString = hour.formatted(.number.precision(.integerLength(2)))
        let minuteString = minute.formatted(.number.precision(.integerLength(2)))
        return "\(hourString):\(minuteString)"
    }

    private func updateSchedule() {
        if isEnabled {
            onChange(DaySchedule(
                startTime: TimeOfDay(hour: startHour, minute: startMinute),
                endTime: TimeOfDay(hour: endHour, minute: endMinute),
                isEnabled: true
            ))
        } else {
            onChange(nil)
        }
    }
}

// MARK: - Time Picker

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
                .foregroundStyle(Color.seansTextSecondary)

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
