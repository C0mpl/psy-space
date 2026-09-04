//
//  TherapistTab.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 23.08.2026.
//

import Foundation

enum TherapistTab: String, Hashable, CaseIterable, Identifiable {
    case schedule
    case clients
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .schedule: "Розклад"
        case .clients: "Клієнти"
        case .profile: "Профіль"
        }
    }

    var systemImage: String {
        switch self {
        case .schedule: "calendar"
        case .clients: "person.2"
        case .profile: "person.circle"
        }
    }
}
