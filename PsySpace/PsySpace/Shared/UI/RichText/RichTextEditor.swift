//
//  RichTextEditor.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 27.08.2026.
//

import SwiftUI
import UIKit

struct RichTextEditor: View {
    @Bindable var state: RichTextState
    var placeholder: String = "Почніть писати..."
    var minHeight: CGFloat = 200

    var body: some View {
        VStack(spacing: 0) {
            formattingToolbar

            Divider()

            RichTextEditorRepresentable(state: state, placeholder: placeholder)
                .frame(minHeight: minHeight)
        }
        .background(Color.psyspaceCardBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(Color.psyspaceTextSecondary.opacity(0.2), lineWidth: 1)
        )
    }

    private var formattingToolbar: some View {
        HStack(spacing: Spacing.sm) {
            FormatButton(
                label: "Жирний",
                icon: "bold",
                isActive: state.isBold,
                action: { state.toggleBold() }
            )

            FormatButton(
                label: "Курсив",
                icon: "italic",
                isActive: state.isItalic,
                action: { state.toggleItalic() }
            )

            Divider()
                .frame(height: 20)

            FormatButton(
                label: "Список",
                icon: "list.bullet",
                isActive: state.isBulletList,
                action: { state.insertBullet() }
            )

            Spacer()
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(Color.psyspaceBackground)
    }
}

private struct FormatButton: View {
    let label: String
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(label, systemImage: icon, action: action)
            .labelStyle(.iconOnly)
            .font(.system(size: 18, weight: isActive ? .bold : .regular))
            .foregroundStyle(isActive ? Color.psyspacePrimary : Color.psyspaceTextSecondary)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .background(isActive ? Color.psyspacePrimary.opacity(0.1) : Color.clear)
            .clipShape(.rect(cornerRadius: CornerRadius.sm))
            .buttonStyle(.plain)
    }
}

struct RichTextEditorRepresentable: UIViewRepresentable {
    @Bindable var state: RichTextState
    var placeholder: String

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state, placeholder: placeholder)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = .preferredFont(forTextStyle: .body)
        textView.textColor = UIColor.label
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.typingAttributes = state.typingAttributes

        context.coordinator.textView = textView
        state.textView = textView
        context.coordinator.updatePlaceholder()

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // Only update if the content actually differs (compare strings, not objects)
        let currentText = textView.attributedText?.string ?? ""
        let newText = state.attributedText.string

        if currentText != newText {
            let selectedRange = textView.selectedRange
            textView.attributedText = state.attributedText
            if selectedRange.location + selectedRange.length <= state.attributedText.length {
                textView.selectedRange = selectedRange
            }
        }
        textView.typingAttributes = state.typingAttributes
        context.coordinator.updatePlaceholder()
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var state: RichTextState
        var placeholder: String
        weak var textView: UITextView?
        private var placeholderLabel: UILabel?

        init(state: RichTextState, placeholder: String) {
            self.state = state
            self.placeholder = placeholder
        }

        func updatePlaceholder() {
            guard let textView else { return }

            if placeholderLabel == nil {
                let label = UILabel()
                label.text = placeholder
                label.font = .preferredFont(forTextStyle: .body)
                label.textColor = .placeholderText
                label.translatesAutoresizingMaskIntoConstraints = false
                textView.addSubview(label)

                NSLayoutConstraint.activate([
                    label.topAnchor.constraint(equalTo: textView.topAnchor, constant: 12),
                    label.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 13)
                ])

                placeholderLabel = label
            }

            // Check actual textView content, not just state
            let hasText = !(textView.text?.isEmpty ?? true)
            placeholderLabel?.isHidden = hasText
        }

        func textViewDidChange(_ textView: UITextView) {
            state.attributedText = textView.attributedText ?? NSAttributedString()
            updatePlaceholder()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            state.selectedRange = textView.selectedRange
            state.updateSelectionAttributes()
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var state = RichTextState()

        var body: some View {
            VStack {
                RichTextEditor(state: state)
                    .padding()

                Text("Plain text: \(state.plainText)")
                    .font(.caption)
                    .padding()
            }
            .background(Color.psyspaceBackground)
        }
    }

    return PreviewWrapper()
}
