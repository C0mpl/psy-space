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
            .scrollContentBackground(.hidden)
            .background(Color.seansBackground)
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

// MARK: - Day Schedule Row

private struct DayScheduleRow: View {
    let day: Weekday
    @Binding var schedule: DaySchedule?

    @State private var isExpanded = false

    private var isEnabled: Bool { schedule?.isEnabled ?? false }
    private var startHour: Int { schedule?.startTime.hour ?? 9 }
    private var startMinute: Int { schedule?.startTime.minute ?? 0 }
    private var endHour: Int { schedule?.endTime.hour ?? 17 }
    private var endMinute: Int { schedule?.endTime.minute ?? 0 }
    private var maxSessions: Int? { schedule?.maxSessionsPerDay }
    private var hasLimit: Bool { maxSessions != nil }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: Spacing.md) {
                Toggle("Робочий день", isOn: Binding(
                    get: { isEnabled },
                    set: { newValue in
                        if newValue {
                            schedule = makeSchedule()
                        } else {
                            schedule = nil
                        }
                    }
                ))

                if isEnabled {
                    HStack {
                        Text("Початок")
                        Spacer()
                        TimePicker(
                            hour: Binding(
                                get: { startHour },
                                set: { schedule = makeSchedule(startHour: $0) }
                            ),
                            minute: Binding(
                                get: { startMinute },
                                set: { schedule = makeSchedule(startMinute: $0) }
                            )
                        )
                    }

                    HStack {
                        Text("Кінець")
                        Spacer()
                        TimePicker(
                            hour: Binding(
                                get: { endHour },
                                set: { schedule = makeSchedule(endHour: $0) }
                            ),
                            minute: Binding(
                                get: { endMinute },
                                set: { schedule = makeSchedule(endMinute: $0) }
                            )
                        )
                    }

                    Divider()

                    Toggle("Обмежити кількість сеансів", isOn: Binding(
                        get: { hasLimit },
                        set: { newValue in
                            schedule = makeSchedule(maxSessions: newValue ? 4 : nil)
                        }
                    ))

                    if hasLimit {
                        Stepper(
                            "Макс. сеансів: \(maxSessions ?? 4)",
                            value: Binding(
                                get: { maxSessions ?? 4 },
                                set: { schedule = makeSchedule(maxSessions: $0) }
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
                        Text("\(formattedTime(startHour, startMinute)) - \(formattedTime(endHour, endMinute))")
                            .font(.caption)
                            .foregroundStyle(Color.seansTextSecondary)

                        if let max = maxSessions {
                            Text("до \(max) сеансів")
                                .font(.caption2)
                                .foregroundStyle(Color.seansPrimary)
                        }
                    }
                } else {
                    Text("Вихідний")
                        .font(.caption)
                        .foregroundStyle(Color.seansTextSecondary)
                }
            }
        }
    }

    private func makeSchedule(
        startHour: Int? = nil,
        startMinute: Int? = nil,
        endHour: Int? = nil,
        endMinute: Int? = nil,
        maxSessions: Int?? = nil  // Double optional: nil = keep current, .some(nil) = remove limit
    ) -> DaySchedule {
        DaySchedule(
            startTime: TimeOfDay(
                hour: startHour ?? self.startHour,
                minute: startMinute ?? self.startMinute
            ),
            endTime: TimeOfDay(
                hour: endHour ?? self.endHour,
                minute: endMinute ?? self.endMinute
            ),
            isEnabled: true,
            maxSessionsPerDay: maxSessions ?? self.maxSessions
        )
    }

    private func formattedTime(_ hour: Int, _ minute: Int) -> String {
        let hourString = hour.formatted(.number.precision(.integerLength(2)))
        let minuteString = minute.formatted(.number.precision(.integerLength(2)))
        return "\(hourString):\(minuteString)"
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
