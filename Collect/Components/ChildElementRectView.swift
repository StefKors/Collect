//
//  ChildElementRectView.swift
//  Collect
//
//  Created by Stef Kors on 17/01/2024.
//

import SwiftUI
import os.signpost
import ScreenCaptureKit

/// NSAccessibilityAnnotationPosition
/// setAccessibilityFrameInParentSpace
/// CGSSetWindowOriginRelativeToWindow
/// https://github.com/jamesarosen/iTerm2/blob/master/CGSInternal/CGSWindow.h

fileprivate let log = OSLog(subsystem: "com.stefkors.Collect", category: "CalcPositionsFast")

fileprivate let signpost = OSSignpostID(log: log)

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
//            .id(label)
            .task(id: element) {
                self.calcPositions()
                self.renderElement()

//                    let apps = NSWorkspace.shared.runningApplications
//                    .filter { $0 != NSRunningApplication.current }
//                    .filter { $0.activationPolicy == .regular }

//                let el = NSAccessibilityElement.element(withRole: .application, frame: NSRect(x: 0, y: 0, width: 200, height: 200), label: "collect demo", parent: apps[0])
//                if let viewEl = el as? NSWindow {
////                    viewEl.wantsLayer = true
////                    viewEl.layer?.backgroundColor = NSColor.blue.cgColor
//                    print(viewEl)
//                    print(dump(viewEl))
//                }
//                print(dump(el))
            }
    }

    func calcPositionsFast(_ notification: AXNotification) {
//        os_signpost(.begin, log: log, name: "Calculate Positions Fast", signpostID: signpost, "%{public}s", notification.rawValue)
        if let frame: CGRect = try? element.attribute(.frame) {
            self.origin = frame.origin
            self.size = frame.size
        }
//        os_signpost(.begin, log: log, name: "Calculate Positions Fast", signpostID: signpost, "%{public}s", notification.rawValue)
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
                try? self.observer?.removeNotification(notification, forElement: prevApp)
//                try? self.observer?.addNotification(notification, forElement: prevApp)
            }
        }

        print("update element")
        if let pid = try? element.pid(), let app = Application(forProcessID: pid) {
//            print("pid")

            self.observer = app.createObserver({ observer, windowElement, notification, info in
                calcPositionsFast(notification)
            })

//            AXNotification.allCases.forEach { notification in
//                try? self.observer?.addNotification(notification, forElement: app)
//            }

            [AXNotification.windowMoved].forEach { notification in
                try? self.observer?.addNotification(notification, forElement: app)
            }

//            Task {
//                let things = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
//                things?.windows.forEach({ window in
//                    let filter = SCContentFilter(desktopIndependentWindow: window)
//                    print(filter.contentRect, filter.style)
//                })

//                SCShareableContentInfo
//                print(dump(things?.applications))
//            }
        }
    }
}
