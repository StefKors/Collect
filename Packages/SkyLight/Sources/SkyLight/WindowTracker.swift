//
//  WindowTracker.swift
//  SkyLight
//
//  Tracks foreign window geometry the same way window-sweaters keeps its
//  borders glued to their windows: WindowServer push notifications via
//  `WindowEventCenter` (`SLSRegisterNotifyProc`), per-window interest via
//  `SLSRequestNotificationsForWindows`, and fresh geometry read back with
//  `SLSGetWindowBounds` on every event. That keeps overlays tracking a live
//  drag without an AX round-trip per event and without depending on the
//  target app posting AX notifications.
//

import CoreGraphics
import Foundation

/// Tracks move/resize/destroy events for a set of windows.
///
/// `SLSRequestNotificationsForWindows` is called whenever the tracked set
/// changes — SkyLight only delivers move/resize events for windows it has
/// been explicitly asked about (window-sweaters'
/// `windows_update_notifications`).
///
/// All handlers are invoked on the main queue. Must be used from the main
/// thread.
public final class WindowTracker {
    public static let shared = WindowTracker()

    public enum Event {
        /// The window moved. The delivered bounds are fresh.
        case moved
        /// The window resized. The delivered bounds are fresh; a final
        /// re-read shortly after the last event is still a good idea —
        /// resize notifications can precede settled geometry.
        case resized
        /// The window was destroyed or moved off its space. Bounds are
        /// delivered as `.zero`.
        case destroyed
    }

    /// `(currentWindowBounds, event)`
    public typealias Handler = (_ windowBounds: CGRect, _ event: Event) -> Void

    /// Handle for a tracked window. Cancels on `cancel()` or deinit.
    public final class Subscription {
        public let windowID: CGWindowID
        fileprivate let id = UUID()
        private weak var tracker: WindowTracker?

        fileprivate init(windowID: CGWindowID, tracker: WindowTracker) {
            self.windowID = windowID
            self.tracker = tracker
        }

        public func cancel() {
            tracker?.untrack(self)
            tracker = nil
        }

        deinit { cancel() }
    }

    private var handlers: [CGWindowID: [UUID: Handler]] = [:]
    private var subscriptions: [WindowEventCenter.Subscription] = []

    /// Whether SkyLight notifications could be registered. When false,
    /// `track` still returns a subscription but no events arrive — callers
    /// should fall back to another update source (e.g. an AX observer).
    public private(set) var isAvailable = false

    private init() {
        guard WindowEventCenter.shared.isAvailable,
              SLS.requestNotificationsForWindows != nil,
              SLS.getWindowBounds != nil else { return }

        let center = WindowEventCenter.shared
        subscriptions = [
            center.subscribe(to: .windowMove) { [weak self] info in
                self?.handleEvent(.moved, windowID: info.windowID)
            },
            center.subscribe(to: .windowResize) { [weak self] info in
                self?.handleEvent(.resized, windowID: info.windowID)
            },
            center.subscribe(to: .windowDestroy) { [weak self] info in
                self?.handleEvent(.destroyed, windowID: info.windowID)
            },
        ]
        isAvailable = true
    }

    /// Starts receiving move/resize/destroy events for `windowID`. The
    /// handler is invoked on the main queue. Multiple subscriptions per
    /// window are fine — many overlays may share the same window.
    public func track(_ windowID: CGWindowID, handler: @escaping Handler) -> Subscription {
        let subscription = Subscription(windowID: windowID, tracker: self)
        handlers[windowID, default: [:]][subscription.id] = handler
        updateNotifications()
        return subscription
    }

    /// Current WindowServer bounds of `windowID` in global top-left screen
    /// coordinates — the same space `AXFrame` reports in.
    public func bounds(of windowID: CGWindowID) -> CGRect? {
        SLWindow(windowID).bounds
    }

    private func handleEvent(_ event: Event, windowID: CGWindowID) {
        guard let subscribers = handlers[windowID], !subscribers.isEmpty else { return }

        switch event {
        case .moved, .resized:
            guard let bounds = bounds(of: windowID) else { return }
            for handler in subscribers.values {
                handler(bounds, event)
            }
        case .destroyed:
            for handler in subscribers.values {
                handler(.zero, .destroyed)
            }
        }
    }

    fileprivate func untrack(_ subscription: Subscription) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.untrack(subscription) }
            return
        }
        handlers[subscription.windowID]?[subscription.id] = nil
        if handlers[subscription.windowID]?.isEmpty != false {
            handlers[subscription.windowID] = nil
        }
        updateNotifications()
    }

    /// Like window-sweaters' `windows_update_notifications`: SkyLight only
    /// delivers move/resize events for windows we have explicitly requested.
    private func updateNotifications() {
        guard let requestNotifications = SLS.requestNotificationsForWindows else { return }
        var windowIDs = Array(handlers.keys)
        windowIDs.withUnsafeMutableBufferPointer { buffer in
            _ = requestNotifications(SkyLight.mainConnectionID,
                                     buffer.baseAddress,
                                     Int32(buffer.count))
        }
    }
}
