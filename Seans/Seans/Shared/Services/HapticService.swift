//
//  HapticService.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 25.08.2026.
//

import UIKit

enum HapticService {
    private static var isVoiceOverRunning: Bool {
        UIAccessibility.isVoiceOverRunning
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard !isVoiceOverRunning else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard !isVoiceOverRunning else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    static func selection() {
        guard !isVoiceOverRunning else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}
