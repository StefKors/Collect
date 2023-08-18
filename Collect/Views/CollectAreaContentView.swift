//
//  CollectAreaContentView.swift
//  Collect
//
//  Created by Stef Kors on 18/08/2023.
//

import SwiftUI

struct CollectAreaContentView: View {
    @AppStorage("showDebugUI") private var showDebugUI: Bool = false
    @State private var mouseLocation: NSPoint = .zero
    @State private var origin: NSPoint = NSPoint(x: 0, y: 0)
    @State private var size: CGSize = CGSize(width: 200, height: 200)

    @State private var showCollect: Bool = false
    var body: some View {
        ZStack() {
            if showDebugUI {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.red, lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .foregroundColor(Color.red.opacity(0.1))
                    )
                    .overlay(alignment: .bottomTrailing) {
                        DebugGridView(mouseLocation: $mouseLocation, origin: $origin, size: $size)
                            .scenePadding()
                    }
            }

            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.accentColor, lineWidth: 3)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .foregroundColor(Color.accentColor.opacity(0.1))
                )
                .frame(width: size.width, height: size.height)
                .position(origin)
                .offset(x: size.width/2, y: size.height/2)
                .opacity(showCollect ? 1 : 0)
        }
        .ignoresSafeArea(.all)
        // TODO: add more events like scroll and touch and etc...
        .eventMonitor(.global, for: [.mouseMoved, .flagsChanged]) { event in
            handleOptionKey(event)
            handleMousePosition(event)
            return event
        }
    }

    private func handleOptionKey(_ event: NSEvent) {
        withAnimation(.bouncy(duration: 0.2)) {
            if event.modifierFlags.contains(.option) {
                showCollect = true
            } else {
                showCollect = false
            }
        }
    }

    private func handleMousePosition(_ event: NSEvent) {
        self.mouseLocation = NSEvent.mouseLocation.flipped()
        if let trackedWindow = AXUIElement.element(at: mouseLocation),
           let windowOrigin = trackedWindow.origin,
           let windowSize = trackedWindow.size {
            withAnimation(.snappy(duration: 0.1)) {
                self.origin = windowOrigin
            }
            withAnimation(.snappy(duration: 0.24)) {
                self.size = windowSize
            }
        }
    }
}

#Preview {
    CollectAreaContentView()
}
