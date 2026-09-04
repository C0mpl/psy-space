//
//  RichTextState.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 27.08.2026.
//

import Foundation
import SwiftUI

@Observable
@MainActor
final class RichTextState {
    var attributedText: NSAttributedString
    var selectedRange: NSRange = NSRange(location: 0, length: 0)
    var typingAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.preferredFont(forTextStyle: .body),
        .foregroundColor: UIColor.label
    ]

    var isBold = false
    var isItalic = false
    var isBulletList = false

    weak var textView: UITextView?

    init(attributedText: NSAttributedString = NSAttributedString()) {
        self.attributedText = attributedText
    }

    init(serialized: String) {
        if let data = Data(base64Encoded: serialized),
           let decoded = try? NSAttributedString(
               data: data,
               options: [.documentType: NSAttributedString.DocumentType.rtf],
               documentAttributes: nil
           ) {
            self.attributedText = decoded
        } else {
            self.attributedText = NSAttributedString(string: serialized)
        }
    }

    var serialized: String {
        guard let data = try? attributedText.data(
            from: NSRange(location: 0, length: attributedText.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) else {
            return attributedText.string
        }
        return data.base64EncodedString()
    }

    var plainText: String {
        attributedText.string
    }

    func updateSelectionAttributes() {
        guard selectedRange.location < attributedText.length else {
            return
        }

        let checkLocation = max(0, selectedRange.location - (selectedRange.length == 0 ? 1 : 0))
        guard checkLocation < attributedText.length else {
            return
        }

        let attributes = attributedText.attributes(at: checkLocation, effectiveRange: nil)

        if let font = attributes[.font] as? UIFont {
            isBold = font.fontDescriptor.symbolicTraits.contains(.traitBold)
            isItalic = font.fontDescriptor.symbolicTraits.contains(.traitItalic)
        }

        if let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle {
            isBulletList = paragraphStyle.textLists.count > 0
        }
    }

    func toggleBold() {
        isBold.toggle()
        updateTypingFont()

        if selectedRange.length > 0 {
            applyFontTrait(.traitBold, add: isBold)
        }
    }

    func toggleItalic() {
        isItalic.toggle()
        updateTypingFont()

        if selectedRange.length > 0 {
            applyFontTrait(.traitItalic, add: isItalic)
        }
    }

    private func updateTypingFont() {
        var font = UIFont.preferredFont(forTextStyle: .body)
        var traits: UIFontDescriptor.SymbolicTraits = []

        if isBold {
            traits.insert(.traitBold)
        }
        if isItalic {
            traits.insert(.traitItalic)
        }

        if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
            font = UIFont(descriptor: descriptor, size: font.pointSize)
        }

        typingAttributes[.font] = font
        textView?.typingAttributes = typingAttributes
    }

    private func applyFontTrait(_ trait: UIFontDescriptor.SymbolicTraits, add: Bool) {
        guard selectedRange.length > 0 else { return }

        let mutableAttr = NSMutableAttributedString(attributedString: attributedText)

        mutableAttr.enumerateAttribute(.font, in: selectedRange, options: []) { value, range, _ in
            let currentFont = (value as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
            var traits = currentFont.fontDescriptor.symbolicTraits

            if add {
                traits.insert(trait)
            } else {
                traits.remove(trait)
            }

            if let newDescriptor = currentFont.fontDescriptor.withSymbolicTraits(traits) {
                let newFont = UIFont(descriptor: newDescriptor, size: currentFont.pointSize)
                mutableAttr.addAttribute(.font, value: newFont, range: range)
            }
        }

        attributedText = mutableAttr
        textView?.attributedText = mutableAttr
        textView?.selectedRange = selectedRange
    }

    func insertBullet() {
        let mutableAttr = NSMutableAttributedString(attributedString: attributedText)
        let bulletPoint = "\n• "

        let insertion = NSAttributedString(
            string: bulletPoint,
            attributes: typingAttributes
        )

        let insertLocation = min(selectedRange.location, mutableAttr.length)
        mutableAttr.insert(insertion, at: insertLocation)
        attributedText = mutableAttr
        selectedRange = NSRange(location: insertLocation + bulletPoint.count, length: 0)

        textView?.attributedText = mutableAttr
        textView?.selectedRange = selectedRange
    }

    func setText(_ text: String) {
        let defaultFont = UIFont.preferredFont(forTextStyle: .body)
        attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: defaultFont,
                .foregroundColor: UIColor.label
            ]
        )
    }

    func clear() {
        attributedText = NSAttributedString()
        selectedRange = NSRange(location: 0, length: 0)
        isBold = false
        isItalic = false
        isBulletList = false
        typingAttributes = [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.label
        ]
    }

    func load(serialized: String) {
        if let data = Data(base64Encoded: serialized),
           let decoded = try? NSAttributedString(
               data: data,
               options: [.documentType: NSAttributedString.DocumentType.rtf],
               documentAttributes: nil
           ) {
            attributedText = decoded
        } else {
            attributedText = NSAttributedString(
                string: serialized,
                attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .body),
                    .foregroundColor: UIColor.label
                ]
            )
        }
        selectedRange = NSRange(location: 0, length: 0)
        isBold = false
        isItalic = false
        isBulletList = false
        textView?.attributedText = attributedText
    }
}
