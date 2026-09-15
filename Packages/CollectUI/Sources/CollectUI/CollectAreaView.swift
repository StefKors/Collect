//
//  CollectAreaContentView.swift
//  Collect
//
//  Created by Stef Kors on 18/08/2023.
// /// https://developer.apple.com/documentation/appkit/nsaccessibilityprotocol/1525917-accessibilityurl

import SwiftUI
import Cocoa
import os
import AXSwift


extension NSEvent {
//    func exclusivelyContains(_ flag: ModifierFlags) -> Bool {
//        return self.modifierFlags.intersection(.deviceIndependentFlagsMask) == .option
//    }
}

struct CollectRules {
    static let minRectSize: CGSize = CGSize(width: 20, height: 5)
}

/// A pinned element with a stable identity for ForEach. `UIElement` itself
/// is only `Equatable` (CFEqual); the UUID keeps view identity stable even
/// when two elements render identical attribute dumps.
private struct PinnedElement: Identifiable {
    let id = UUID()
    let element: UIElement
}

/// An accessibility element the user clicked while the collect overlay was
/// active, together with the text extracted from it.
public struct CollectedElement {
    /// The element that was clicked.
    public let element: UIElement
    /// Combined `AXValue` strings of the element and its descendants,
    /// space-joined and trimmed.
    public let text: String
    /// Raw attribute dump of the element (`UIElement.inspectDict`).
    public let attributes: [AXAttribute: String]

    public init(element: UIElement, text: String, attributes: [AXAttribute: String]) {
        self.element = element
        self.text = text
        self.attributes = attributes
    }
}

/// Full-screen collect overlay.
///
/// Hold option to enter "collect mode": the element under the pointer is
/// outlined and clicking it fires `onCollect` with the element, its
/// extracted text and its attribute dump. Child rects of the clicked
/// element are tracked live via `SkyLight.WindowTracker` so they follow
/// foreign windows while they move.
///
/// When the `keepsRectsStorageKey` default is on, every clicked element's
/// rectangles are *pinned*: they stay on screen — through further clicks and
/// window drags — until Escape clears them. With it off, clicking somewhere
/// else replaces the previous selection.
///
/// Presented through `floatingPanel` — see `FloatingPanel.swift`.
public struct CollectAreaView: View {
    /// `UserDefaults`/`AppStorage` key for the pin mode. Bind a toggle to
    /// this key to expose the option in app UI.
    public static let keepsRectsStorageKey = "keepCollectRects"

    @AppStorage("showDebugUI") private var showDebugUI: Bool = false
    @AppStorage(CollectAreaView.keepsRectsStorageKey) private var keepsRects: Bool = false

    /// Target element
    @State private var label: String? = nil
    @State private var mouseLocation: NSPoint = .zero
    @State private var origin: NSPoint = NSPoint(x: 0, y: 0)
    @State private var size: CGSize = CGSize(width: 200, height: 200)
    @State private var showCollect: Bool = false


    /// Collected / Selected element
    @State private var element: UIElement? = nil

    /// Elements whose rectangles stay on screen while `keepsRects` is on.
    @State private var pinnedElements: [PinnedElement] = []

    /// Deduping store
    @State private var lastStore: String? = nil

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    /// Called when the user clicks an element while in collect mode.
    /// Not called for clicks that produce no text, or for elements identical
    /// to the previously collected one (deduped via `lastStore`).
    public let onCollect: (_ item: CollectedElement) -> Void

    public init(onCollect: @escaping (_ item: CollectedElement) -> Void) {
        self.onCollect = onCollect
    }

    public var body: some View {
        ZStack() {
            if showDebugUI {
                DebugFullWindowView()
                    .overlay(alignment: .bottomTrailing) {
                        DebugGridView(mouseLocation: $mouseLocation, origin: $origin, size: $size)
                            .scenePadding()
                    }
            }

            ElementRectView(label: label, origin: origin, size: size, showCollect: showCollect)
                .id("Top-Level_Element-Rect")

            ForEach(pinnedElements) { pinned in
                HierarchyRectView(element: pinned.element, level: 0)
            }

            if let element, !pinnedElements.contains(where: { $0.element == element }) {
                HierarchyRectView(element: element, level: 0)
//                ChildElementRectView(element: element)

//                ElementRectView(origin: elementFrame.origin, size: elementFrame.size, showCollect: showCollect)
//                    .task(id: elementFrame) {
//                        print("render element view")
//                    }
            }
        }
        .ignoresSafeArea(.all)
        // TODO: add more events like scroll and touch and etc...
        .universalEventMonitor(for: [.leftMouseDown, .mouseMoved, .flagsChanged, .keyUp, .keyDown]) { event in
            handleOptionKey(event)
            if event.type == .keyDown, event.keyCode == 53 {
                // Escape clears pinned rectangles and the current selection.
                pinnedElements = []
                element = nil
                return
            }
            if showCollect {
                try? handleMousePosition(event)
                if event.type == .leftMouseDown {
                    //            // Runs duplicates? still buggy
                    handleClick(event)
                }
            }
        }
    }

    private func handleOptionKey(_ event: NSEvent) {
        withAnimation(.bouncy(duration: 0.2)) {
            if exclusivelyContains(event, flag: .option) {
                if showCollect != true {
                    showCollect = true
                }
//                showDebugUI = true
            } else {
                if showCollect != false {
                    showCollect = false
                }
//                showDebugUI = false
            }
        }
    }

    func exclusivelyContains(_ event: NSEvent, flag: NSEvent.ModifierFlags) -> Bool {
        return event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .option
    }

    private func handleMousePosition(_ event: NSEvent) throws {
        self.mouseLocation = NSEvent.mouseLocation.flipped()
        
        // has element and frame
        guard let element = systemWideElement.getAtPoint(mouseLocation),
              let frame: CGRect = try element.attribute(.frame) else {
            return
        }

        guard frame.size > CollectRules.minRectSize else {
            // logger.debug("frame size is smaller than minRectSize allows")
            return
        }

        self.label = try? element.attribute(.roleDescription)

        let renderFramer = frame.insetBy(dx: -4, dy: -4)

        withAnimation(.snappy(duration: 0.1)) {
            self.origin = renderFramer.origin
            self.size = renderFramer.size
        }
    }

    private func handleClick(_ event: NSEvent) {
//        guard showCollect else { return }
        let clickLocation = NSEvent.mouseLocation.flipped()

        if let clickElement = systemWideElement.getAtPoint(clickLocation) {
            self.element = clickElement

            if keepsRects, !pinnedElements.contains(where: { $0.element == clickElement }) {
                pinnedElements.append(PinnedElement(element: clickElement))
            }

            let text = getSumString(element: clickElement)
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespaces)

            if text.isEmpty {
                print("text is empty, skipping collect")
                return
            }

            // Dedupe naively — the universal monitor can deliver a click
            // through both its local and global monitors.
            if text == lastStore {
                return
            }

            lastStore = text
            onCollect(CollectedElement(element: clickElement, text: text, attributes: clickElement.inspectDict))
        }
    }



    /// Recursively fetches the combined values of all text string of all children. Could be slow, keep out of hotpath.
    func getSumString(element: UIElement) -> [String] {
        let allChildren = getChildrenFlat(element: element)
        return allChildren.compactMap { child -> String? in
            return try? child.attribute(.value)
        }
    }


    func getChildrenFlat(element: UIElement, level: Int = 1) -> [UIElement] {
//        let value: String? = try element.attribute(.value)
        guard let children: [AXUIElement] = try? element.attribute(.children) else {
            return [element]
        }
        print("allchildren level \(level.description) \(children.count)")

        if children.isEmpty {
            return [element]
        }
        let newLevel = level + 1

        return children.map { el in
            return getChildrenFlat(element: UIElement(el), level: newLevel)
        }.reduce([], +)
//        return (children ?? []).compactMap { child in
//            return getChildrenFlat(element: UIElement(child), level: newLevel)
//        }
    }

    /// Recursively fetches the combined values of all text string of all children. Could be slow, keep out of hotpath.
    /// - Parameters:
    ///   - str: optional string array
    ///   - element: element to check
    /// - Returns: array of strings
//    private func getChildString(_ parentString: Set<String>? = [], element: UIElement) throws -> [String] {
//        var corpus: Set<String> = parentString ?? []
//        if let elementString: String = try? element.attribute(.value) {
////            print(elementString.debugDescription)
//            if !elementString.isEmpty {
//                corpus.insert(elementString)
//            }
////            if let string = elementString as? String {
////                if !string.isEmpty {
////                    array.append(string)
////                }
////            }
////
////            if let num = elementString as? NSNumber {
////                let string = num.description
////                if !string.isEmpty {
////                    array.append(string)
////                }
////            }
//        }
//
//        let children: [AXUIElement]? = try element.attribute(.children)
////        print(children, corpus.description)
//        if let children {
//            for child in children {
//                let childString = try getChildString(corpus, element: UIElement(child))
//                // if let childString {
//                for string in childString {
//                    corpus.insert(string)
//                }
//                // }
//            }
//        }
//
//
//        return Array(corpus)
//    }
}

#Preview {
    CollectAreaView(onCollect: { _ in })
}
