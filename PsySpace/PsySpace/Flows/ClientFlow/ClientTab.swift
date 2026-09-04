//
//  ClientTab.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 23.08.2026.
//

import Foundation

enum ClientTab: String, Hashable, CaseIterable, Identifiable {
    case booking
    case homework
    case journal
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .booking: "Запис"
        case .homework: "Завдання"
        case .journal: "Щоденник"
        case .profile: "Профіль"
        }
    }

    var systemImage: String {
        switch self {
        case .booking: "calendar"
        case .homework: "doc.text.fill"
        case .journal: "book.closed"
        case .profile: "person.circle"
        }
    }
}
