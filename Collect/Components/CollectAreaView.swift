//
//  CollectAreaContentView.swift
//  Collect
//
//  Created by Stef Kors on 18/08/2023.
//

import SwiftUI
import AXSwift
import Cocoa


struct CollectAreaView: View {
    @AppStorage("showDebugUI") private var showDebugUI: Bool = false
    @State private var mouseLocation: NSPoint = .zero
    @State private var origin: NSPoint = NSPoint(x: 0, y: 0)
    @State private var size: CGSize = CGSize(width: 200, height: 200)
    @State private var showCollect: Bool = false

    var onCollect: (_ text: String) -> Void

    var body: some View {
        ZStack() {
//            if showDebugUI {
//                DebugFullWindowView()
//                    .overlay(alignment: .bottomTrailing) {
//                        DebugGridView(mouseLocation: $mouseLocation, origin: $origin, size: $size)
//                            .scenePadding()
//                    }
//            }

            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .foregroundColor(Color.accentColor.opacity(0.3))
                )
                .frame(width: size.width, height: size.height)
                .position(origin)
                .offset(x: size.width/2, y: size.height/2)
                .opacity(showCollect ? 1 : 0)
        }
        .ignoresSafeArea(.all)
        
        .globalEventMonitor(for: [.leftMouseDown]) { event in
            handleClick()
        }
        // TODO: add more events like scroll and touch and etc...
        .universalEventMonitor(for: [.mouseMoved, .flagsChanged, .keyUp, .keyDown]) { event in
            handleOptionKey(event)
            if showCollect {
                try? handleMousePosition(event)
            }
        }
    }

    private func handleOptionKey(_ event: NSEvent) {
        withAnimation(.bouncy(duration: 0.2)) {
            print("has option \(event.modifierFlags.contains(.option))")
            if event.modifierFlags.contains(.option) {
                showCollect = true
                showDebugUI = true
            } else {
                showCollect = false
                showDebugUI = false
            }
        }
    }

    private func handleMousePosition(_ event: NSEvent) throws {
        self.mouseLocation = NSEvent.mouseLocation.flipped()
        
        if let element = systemWideElement.getAtPoint(mouseLocation) {
            if let frame: CGRect = try element.attribute(.frame) {
                withAnimation(.snappy(duration: 0.1)) {
                    self.origin = frame.origin
                }
                withAnimation(.snappy(duration: 0.24)) {
                    self.size = frame.size
                }
            }
        }
    }

    private func handleClick() {
        print("handleClick \(showCollect.description)")
        guard showCollect else { return }
        let clickLocation = NSEvent.mouseLocation.flipped()
        print("location \(clickLocation)")
        if let element = systemWideElement.getAtPoint(clickLocation),
           let text = try? getChildString(element: element)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines) {

            guard !text.isEmpty else { return }
            print("onCollect \(text)")
            onCollect(text)
        }
    }

    /// Recursively fetches the combined values of all text string of all children. Could be slow, keep out of hotpath.
    /// - Parameters:
    ///   - str: optional string array
    ///   - element: element to check
    /// - Returns: array of strings
    private func getChildString(_ str: [String]? = [], element: UIElement) throws -> [String] {
        var array: [String] = []
        if let elementString: Any? = try element.attribute(.value) {
            if let string = elementString as? String {
                if !string.isEmpty {
                    array.append(string)
                }
            }

            if let num = elementString as? NSNumber {
                let string = num.description
                if !string.isEmpty {
                    array.append(string)
                }
            }
        }

        let children: [AXUIElement]? = try element.attribute(.children)
        if let children {
            for child in children {
                let childString = try getChildString([], element: UIElement(child))
                // if let childString {
                array.append(contentsOf: childString)
                // }
            }
        }


        return array
    }
}

#Preview {
    CollectAreaView(onCollect: { _ in })
}
