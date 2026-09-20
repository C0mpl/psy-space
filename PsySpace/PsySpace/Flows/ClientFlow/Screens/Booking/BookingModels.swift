//
//  BookingModels.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 23.08.2026.
//

import Foundation

enum TimePeriod: String, CaseIterable {
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

struct SlotGroup {
    let period: TimePeriod
    let slots: [TimeSlot]
}
