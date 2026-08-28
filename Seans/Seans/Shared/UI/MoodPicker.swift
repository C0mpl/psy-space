//
//  MoodPicker.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 27.08.2026.
//

import SwiftUI

struct MoodPicker: View {
    @Binding var selectedMood: Mood?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Як ви себе почуваєте?")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.seansTextPrimary)

            HStack(spacing: Spacing.sm) {
                ForEach(Mood.allCases, id: \.self) { mood in
                    MoodButton(
                        mood: mood,
                        isSelected: selectedMood == mood,
                        action: { toggleMood(mood) }
                    )
                }
            }

            if let mood = selectedMood {
                Text(mood.label)
                    .font(.caption)
                    .foregroundStyle(Color.seansTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(SeansAnimation.standard, value: selectedMood)
    }

    private func toggleMood(_ mood: Mood) {
        if selectedMood == mood {
            selectedMood = nil
        } else {
            selectedMood = mood
        }
        HapticService.selection()
    }
}

private struct MoodButton: View {
    let mood: Mood
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text(mood.emoji)
                .font(.system(size: 28))
                .frame(width: 52, height: 52)
                .background(
                    Circle()
                        .fill(isSelected ? Color.seansPrimary.opacity(0.2) : Color.seansCardBackground)
                )
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.seansPrimary : Color.clear, lineWidth: 2)
                )
                .scaleEffect(isSelected && !reduceMotion ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mood.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(reduceMotion ? nil : SeansAnimation.quick, value: isSelected)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var mood: Mood?

        var body: some View {
            VStack {
                MoodPicker(selectedMood: $mood)
                    .padding()
                    .background(Color.seansCardBackground)
                    .clipShape(.rect(cornerRadius: CornerRadius.md))
                    .padding()
            }
            .background(Color.seansBackground)
        }
    }

    return PreviewWrapper()
}
