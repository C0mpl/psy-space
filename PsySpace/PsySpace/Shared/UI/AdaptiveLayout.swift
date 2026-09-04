//
//  AdaptiveLayout.swift
//  PsySpace
//
//  Created by Claude on 03.09.2026.
//

import SwiftUI

// MARK: - Device Layout Detection

enum DeviceLayout {
    case compact
    case regular

    static func current(for horizontalSizeClass: UserInterfaceSizeClass?) -> DeviceLayout {
        horizontalSizeClass == .regular ? .regular : .compact
    }

    var isRegular: Bool { self == .regular }
    var isCompact: Bool { self == .compact }
}

// MARK: - Adaptive Grid Configuration

struct AdaptiveGridConfig {
    let minimumItemWidth: CGFloat
    let maximumItemWidth: CGFloat
    let spacing: CGFloat

    static let timeSlots = AdaptiveGridConfig(
        minimumItemWidth: 80,
        maximumItemWidth: 120,
        spacing: Spacing.sm
    )

    static let cards = AdaptiveGridConfig(
        minimumItemWidth: 300,
        maximumItemWidth: 400,
        spacing: Spacing.md
    )

    static let journalEntries = AdaptiveGridConfig(
        minimumItemWidth: 320,
        maximumItemWidth: 450,
        spacing: Spacing.md
    )

    var columns: [GridItem] {
        [GridItem(.adaptive(minimum: minimumItemWidth, maximum: maximumItemWidth), spacing: spacing)]
    }
}

// MARK: - Adaptive Sheet Modifier

struct AdaptiveSheetModifier<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let detents: Set<PresentationDetent>
    @ViewBuilder let sheetContent: () -> SheetContent

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var adaptiveDetents: Set<PresentationDetent> {
        if horizontalSizeClass == .regular {
            return [.large]
        } else {
            return detents
        }
    }

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            sheetContent()
                .presentationDetents(adaptiveDetents)
        }
    }
}

struct AdaptiveSheetItemModifier<Item: Identifiable, SheetContent: View>: ViewModifier {
    @Binding var item: Item?
    let detents: Set<PresentationDetent>
    @ViewBuilder let sheetContent: (Item) -> SheetContent

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var adaptiveDetents: Set<PresentationDetent> {
        if horizontalSizeClass == .regular {
            return [.large]
        } else {
            return detents
        }
    }

    func body(content: Content) -> some View {
        content.sheet(item: $item) { item in
            sheetContent(item)
                .presentationDetents(adaptiveDetents)
        }
    }
}

extension View {
    func adaptiveSheet<Content: View>(
        isPresented: Binding<Bool>,
        detents: Set<PresentationDetent> = [.medium, .large],
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(AdaptiveSheetModifier(
            isPresented: isPresented,
            detents: detents,
            sheetContent: content
        ))
    }

    func adaptiveSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        detents: Set<PresentationDetent> = [.medium, .large],
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        modifier(AdaptiveSheetItemModifier(
            item: item,
            detents: detents,
            sheetContent: content
        ))
    }
}

// MARK: - Layout Environment Key

private struct DeviceLayoutKey: EnvironmentKey {
    static let defaultValue: DeviceLayout = .compact
}

extension EnvironmentValues {
    var deviceLayout: DeviceLayout {
        get { self[DeviceLayoutKey.self] }
        set { self[DeviceLayoutKey.self] = newValue }
    }
}

// MARK: - Adaptive Container

struct AdaptiveContainer<Compact: View, Regular: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let compact: () -> Compact
    let regular: () -> Regular

    init(
        @ViewBuilder compact: @escaping () -> Compact,
        @ViewBuilder regular: @escaping () -> Regular
    ) {
        self.compact = compact
        self.regular = regular
    }

    var body: some View {
        if horizontalSizeClass == .regular {
            regular()
        } else {
            compact()
        }
    }
}

// MARK: - Adaptive Width Modifier

struct AdaptiveReadableWidthModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let maxWidth: CGFloat

    func body(content: Content) -> some View {
        if horizontalSizeClass == .regular {
            content
                .frame(maxWidth: maxWidth)
                .frame(maxWidth: .infinity)
        } else {
            content
        }
    }
}

extension View {
    func adaptiveReadableWidth(_ maxWidth: CGFloat = 700) -> some View {
        modifier(AdaptiveReadableWidthModifier(maxWidth: maxWidth))
    }
}
