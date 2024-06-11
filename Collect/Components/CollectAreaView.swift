//
//  CollectAreaContentView.swift
//  Collect
//
//  Created by Stef Kors on 18/08/2023.
// /// https://developer.apple.com/documentation/appkit/nsaccessibilityprotocol/1525917-accessibilityurl

import SwiftUI
import Cocoa
import os


extension NSEvent {
//    func exclusivelyContains(_ flag: ModifierFlags) -> Bool {
//        return self.modifierFlags.intersection(.deviceIndependentFlagsMask) == .option
//    }
}

struct CollectRules {
    static let minRectSize: CGSize = CGSize(width: 20, height: 5)
}

struct CollectAreaView: View {
    @AppStorage("showDebugUI") private var showDebugUI: Bool = false
    
    /// Target element
    @State private var label: String? = nil
    @State private var mouseLocation: NSPoint = .zero
    @State private var origin: NSPoint = NSPoint(x: 0, y: 0)
    @State private var size: CGSize = CGSize(width: 200, height: 200)
    @State private var showCollect: Bool = false


    /// Collected / Selected element
    @State private var element: UIElement? = nil

    /// Deduping store
    @State private var lastStore: String? = nil

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Self.self)
    )

    var onCollect: (_ item: CollectItem) -> Void

    var body: some View {
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

            if let element {
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
            print("update clickElement")
            self.element = clickElement


//            let text = getSumString(element: clickElement)
//                .joined(separator: " ")
//                .trimmingCharacters(in: .whitespaces)
//
//             if text.isEmpty {
//                print("text is empty, skipping collect")
//                return
//            }
//
//            // Dedupe naively
//            if text == lastStore {
//                return
//            }
//
//            lastStore = text
////            let attrs = clickElement.inspectDict
////            print("onCollect \(attrs)")
//            let newItem = CollectItem(text: text, attributes: clickElement.inspectDict)
//            onCollect(newItem)
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
