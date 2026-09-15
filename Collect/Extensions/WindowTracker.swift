//
//  WindowTracker.swift
//  Collect
//
//  Tracks foreign window geometry the same way window-sweaters keeps its
//  borders glued to their windows: SkyLight pushes WindowServer notifications
//  straight to this process (`SLSRegisterNotifyProc`), interest is declared
//  per window (`SLSRequestNotificationsForWindows`), and fresh geometry is
//  read back from the WindowServer (`SLSGetWindowBounds`). That keeps collect
//  rects tracking a live drag without depending on the target app posting
//  AXMoved and without a synchronous AX round-trip per event.
//

import Cocoa

final class WindowTracker {
    static let shared = WindowTracker()

    enum Event {
        case moved
        case resized
        case destroyed
    }

    typealias Handler = (_ windowBounds: CGRect, _ event: Event) -> Void

    /// Handle for a tracked window. Cancels on `cancel()` or deinit.
    final class Subscription {
        let windowID: CGWindowID
        fileprivate let id = UUID()
        private weak var tracker: WindowTracker?

        fileprivate init(windowID: CGWindowID, tracker: WindowTracker) {
            self.windowID = windowID
            self.tracker = tracker
        }

        func cancel() {
            tracker?.untrack(self)
            tracker = nil
        }

        deinit { cancel() }
    }

    /// SkyLight event IDs, matching window-sweaters' src/events.h.
    private enum SLSEvent {
        static let windowMove: UInt32 = 806
        static let windowResize: UInt32 = 807
        static let windowDestroy: UInt32 = 1326
    }

    private typealias SLSMainConnectionID = @convention(c) () -> Int32
    private typealias SLSNotifyProc = @convention(c) (UInt32, UnsafeMutableRawPointer?, Int, UnsafeMutableRawPointer?) -> Void
    private typealias SLSRegisterNotifyProc = @convention(c) (SLSNotifyProc, UInt32, UnsafeMutableRawPointer?) -> Int32
    private typealias SLSGetWindowBounds = @convention(c) (Int32, UInt32, UnsafeMutablePointer<CGRect>) -> Int32
    private typealias SLSRequestNotificationsForWindows = @convention(c) (Int32, UnsafeMutablePointer<UInt32>?, Int32) -> Int32
    private typealias AXUIElementGetWindow = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError

    private var handlers: [CGWindowID: [UUID: Handler]] = [:]
    private var connectionID: Int32 = 0
    private var slsGetWindowBounds: SLSGetWindowBounds?
    private var slsRequestNotifications: SLSRequestNotificationsForWindows?
    private var axGetWindow: AXUIElementGetWindow?

    /// Whether SkyLight notifications could be registered. When false,
    /// `track` still returns a subscription but no events arrive.
    private(set) var isAvailable = false

    private init() {
        let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
        let hiServices = dlopen("/System/Library/Frameworks/ApplicationServices.framework/Frameworks/HIServices.framework/HIServices", RTLD_LAZY)

        guard let mainConnectionID: SLSMainConnectionID = Self.symbol(skyLight, "SLSMainConnectionID"),
              let registerNotify: SLSRegisterNotifyProc = Self.symbol(skyLight, "SLSRegisterNotifyProc"),
              let getWindowBounds: SLSGetWindowBounds = Self.symbol(skyLight, "SLSGetWindowBounds"),
              let requestNotifications: SLSRequestNotificationsForWindows = Self.symbol(skyLight, "SLSRequestNotificationsForWindows") else {
            return
        }

        connectionID = mainConnectionID()
        slsGetWindowBounds = getWindowBounds
        slsRequestNotifications = requestNotifications
        axGetWindow = Self.symbol(hiServices, "_AXUIElementGetWindow")

        let context = Unmanaged.passUnretained(self).toOpaque()
        _ = registerNotify(Self.notifyCallback, SLSEvent.windowMove, context)
        _ = registerNotify(Self.notifyCallback, SLSEvent.windowResize, context)
        _ = registerNotify(Self.notifyCallback, SLSEvent.windowDestroy, context)
        isAvailable = true
    }

    private static func symbol<T>(_ handle: UnsafeMutableRawPointer?, _ name: String, as type: T.Type = T.self) -> T? {
        guard let handle, let pointer = dlsym(handle, name) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }

    private static let notifyCallback: SLSNotifyProc = { event, data, length, context in
        guard let context, let data else { return }
        // Move/resize payloads are just the window id. Create/destroy payloads
        // are `struct { uint64_t sid; uint32_t wid; }`, matching
        // window-sweaters' window_spawn_handler.
        let windowID: UInt32
        if event == SLSEvent.windowDestroy {
            guard length >= 12 else { return }
            windowID = data.load(fromByteOffset: 8, as: UInt32.self)
        } else {
            guard length >= 4 else { return }
            windowID = data.load(as: UInt32.self)
        }
        let tracker = Unmanaged<WindowTracker>.fromOpaque(context).takeUnretainedValue()
        DispatchQueue.main.async {
            tracker.handleEvent(event, windowID: windowID)
        }
    }

    private func handleEvent(_ event: UInt32, windowID: CGWindowID) {
        guard let subscribers = handlers[windowID], !subscribers.isEmpty else { return }

        switch event {
        case SLSEvent.windowMove, SLSEvent.windowResize:
            var bounds = CGRect.zero
            guard let slsGetWindowBounds,
                  slsGetWindowBounds(connectionID, windowID, &bounds) == 0 else { return }
            let kind: Event = event == SLSEvent.windowMove ? .moved : .resized
            for handler in subscribers.values {
                handler(bounds, kind)
            }
        case SLSEvent.windowDestroy:
            for handler in subscribers.values {
                handler(.zero, .destroyed)
            }
        default:
            break
        }
    }

    /// Starts receiving move/resize events for `windowID`. The handler is
    /// invoked on the main queue. Multiple subscriptions per window are fine;
    /// many collect rects share the same window.
    func track(_ windowID: CGWindowID, handler: @escaping Handler) -> Subscription {
        let subscription = Subscription(windowID: windowID, tracker: self)
        handlers[windowID, default: [:]][subscription.id] = handler
        updateNotifications()
        return subscription
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

    /// Like window-sweaters' windows_update_notifications: SkyLight only
    /// delivers move/resize events for windows we have explicitly requested.
    private func updateNotifications() {
        guard let slsRequestNotifications else { return }
        var windowIDs = Array(handlers.keys)
        windowIDs.withUnsafeMutableBufferPointer { buffer in
            _ = slsRequestNotifications(connectionID, buffer.baseAddress, Int32(buffer.count))
        }
    }

    /// Current WindowServer bounds of `windowID` in global top-left screen
    /// coordinates — the same space `AXFrame` reports in.
    func bounds(of windowID: CGWindowID) -> CGRect? {
        var bounds = CGRect.zero
        guard let slsGetWindowBounds,
              slsGetWindowBounds(connectionID, windowID, &bounds) == 0 else { return nil }
        return bounds
    }

    /// The CGWindowID of the window containing `element`, resolved through the
    /// same private `_AXUIElementGetWindow` call window-sweaters uses.
    func windowID(of element: UIElement) -> CGWindowID? {
        if let windowID = axWindowID(of: element.element) { return windowID }
        if let window: UIElement = try? element.attribute(.window),
           let windowID = axWindowID(of: window.element) { return windowID }
        if let topLevel: UIElement = try? element.attribute(.topLevelUIElement),
           let windowID = axWindowID(of: topLevel.element) { return windowID }
        return nil
    }

    private func axWindowID(of element: AXUIElement) -> CGWindowID? {
        var windowID = CGWindowID(0)
        guard let axGetWindow,
              axGetWindow(element, &windowID) == .success,
              windowID != 0 else { return nil }
        return windowID
    }
}
