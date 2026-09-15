//
//  ChildElementRectView.swift
//  Collect
//
//  Created by Stef Kors on 17/01/2024.
//

import SwiftUI
import os.signpost
import ScreenCaptureKit
import AXSwift
import SkyLight

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
    @State private var subscription: WindowTracker.Subscription? = nil

    @State private var origin: NSPoint = .zero
    @State private var size: CGSize = .zero
    @State private var label: String?

    /// Last WindowServer origin of the window containing `element`.
    @State private var windowOrigin: CGPoint? = nil
    /// Generation token so only the newest settle read runs.
    @State private var settleToken: UInt64 = 0

    private var show: Bool {
        (size != .zero) && (origin != .zero)
    }

    var body: some View {
        ElementRectView(label: label, level: level, origin: origin, size: size, showCollect: show)
//            .id(label)
            .task(id: element) {
                self.subscription?.cancel()
                self.subscription = nil
                self.observer = nil

                self.calcPositions()

                if WindowTracker.shared.isAvailable {
                    if let windowID = element.containingWindowID {
                        os_log(.debug, log: log, "tracking wid=%{public}u via SkyLight", windowID)
                        self.trackWindow(windowID)
                        // Snap once after tracking starts, covering a window move
                        // between the AX frame read and the bounds read above.
                        self.scheduleSettleRead()
                    } else {
                        os_log(.debug, log: log, "no containing window — AX observer fallback")
                        self.renderElement()
                    }
                } else {
                    // Elements without a resolvable window keep the old
                    // AXObserver path.
                    os_log(.debug, log: log, "WindowTracker unavailable — AX observer fallback")
                    self.renderElement()
                }

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
            .onDisappear {
                self.subscription?.cancel()
                self.subscription = nil
                self.observer = nil
            }
    }

    /// Tracks the containing window at the WindowServer level, the way
    /// window-sweaters tracks its borders: SkyLight pushes move/resize events
    /// for the window and the rect follows without per-event AX IPC.
    func trackWindow(_ windowID: CGWindowID) {
        windowOrigin = WindowTracker.shared.bounds(of: windowID)?.origin
        subscription = WindowTracker.shared.track(windowID) { bounds, event in
            switch event {
            case .moved:
                // A move shifts every element in the window by the same delta,
                // so the rect follows with WindowServer data alone.
                if let previous = windowOrigin {
                    origin = NSPoint(
                        x: origin.x + bounds.origin.x - previous.x,
                        y: origin.y + bounds.origin.y - previous.y
                    )
                }
                windowOrigin = bounds.origin
                scheduleSettleRead()
            case .resized:
                // Children can reflow during a resize; re-read the real frame.
                windowOrigin = bounds.origin
                calcPositions(animated: false)
                scheduleSettleRead()
            case .destroyed:
                size = .zero
                subscription?.cancel()
                subscription = nil
            }
        }
    }

    /// Notifications can precede the final WindowServer/AX geometry.
    /// window-sweaters reads the frame once more 32ms after the last event;
    /// do the same so the rect settles exactly on the element.
    func scheduleSettleRead() {
        settleToken &+= 1
        let token = settleToken
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(32)) {
            guard token == settleToken else { return }
            calcPositions(animated: false)
            if let windowID = subscription?.windowID {
                windowOrigin = WindowTracker.shared.bounds(of: windowID)?.origin
            }
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

    /// - Parameter animated: window-tracking updates pass `false` — a rect
    ///   stuck to a moving window should land on the new frame immediately,
    ///   not chase it with a spring.
    func calcPositions(animated: Bool = true) {
        self.label = try? element.attribute(.roleDescription) ?? nil
        if let frame: CGRect = try? element.attribute(.frame) {
            // skip animation on first show
            if show == false || animated == false {
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

        guard let pid = try? element.pid() else {
            os_log(.error, log: log, "renderElement: could not get pid — no tracking for this element")
            return
        }
        guard let app = Application(forProcessID: pid) else {
            os_log(.error, log: log, "renderElement: no Application for pid %d", pid)
            return
        }

        self.observer = app.createObserver({ observer, windowElement, notification, info in
            calcPositionsFast(notification)
        })

        guard let observer else {
            os_log(.error, log: log, "renderElement: AXObserverCreate failed for pid %d", pid)
            return
        }

        for notification in [AXNotification.windowMoved, AXNotification.windowResized] {
            do {
                try observer.addNotification(notification, forElement: app)
            } catch {
                os_log(.error, log: log, "renderElement: addNotification %{public}s failed: %{public}s",
                       notification.rawValue, error.localizedDescription)
            }
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
