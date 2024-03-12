//
//  ChildElementRectView.swift
//  Collect
//
//  Created by Stef Kors on 17/01/2024.
//

import SwiftUI

struct ChildElementRectView: View {
    let element: UIElement
    var level: Int

    @State private var observer: Observer? = nil

    @State private var origin: NSPoint = .zero
    @State private var size: CGSize = .zero
    @State private var label: String?

    private var show: Bool {
        (size != .zero) && (origin != .zero)
    }

    var body: some View {
        ElementRectView(label: label, level: level, origin: origin, size: size, showCollect: show)
            .task(id: element) {
                self.calcPositions()
                self.renderElement()
            }
    }

    func calcPositions() {
        self.label = try? element.attribute(.roleDescription) ?? nil
        if let frame: CGRect = try? element.attribute(.frame) {
            // skip animation on first show
            if show == false {
                self.origin = frame.origin
                self.size = frame.size
            } else {
                withAnimation(.snappy(duration: 0.1)) {
                    self.origin = frame.origin
                    self.size = frame.size
                }
            }
        }
    }

    func renderElement() {
        observer?.stop()
        if let prevApp = observer?.application {
            AXNotification.allCases.forEach { notification in
                try? self.observer?.addNotification(notification, forElement: prevApp)
            }
        }

        print("update element")
        if let pid = try? element.pid(), let app = Application(forProcessID: pid) {
            print("pid")

            self.observer = app.createObserver({ observer, windowElement, notification in
                calcPositions()
            })

            AXNotification.allCases.forEach { notification in
                try? self.observer?.addNotification(notification, forElement: app)
            }
        }
    }
}
