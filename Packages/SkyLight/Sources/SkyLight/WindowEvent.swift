//
//  WindowEvent.swift
//  SkyLight
//
//  WindowServer push notifications. `SLSRegisterNotifyProc` installs a C
//  callback per event id on the process's notification port; the WindowServer
//  then posts matching events to every registered proc. Move/resize style
//  events additionally need `SLSRequestNotificationsForWindows` — see
//  `WindowTracker`.
//
//  Event ids below match window-sweaters' src/events.h, which in turn comes
//  from yabai's long-maintained list.
//

import CoreGraphics
import Foundation
import os

/// A WindowServer event identifier delivered through `SLSRegisterNotifyProc`.
///
/// The known values are listed as static members, but any id can be
/// subscribed to: `WindowEvent(rawValue: 806)`.
public struct WindowEvent: RawRepresentable, Hashable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// Posted when a window's content is refreshed (payload: window id).
    public static let windowUpdate = WindowEvent(rawValue: 723)

    /// A window was closed but may still exist (payload: window id).
    public static let windowClose = WindowEvent(rawValue: 804)

    /// A window moved. Payload: window id. Only delivered for windows
    /// registered via `SLSRequestNotificationsForWindows`.
    public static let windowMove = WindowEvent(rawValue: 806)

    /// A window resized. Payload: window id. Same per-window registration
    /// requirement as ``windowMove``.
    public static let windowResize = WindowEvent(rawValue: 807)

    /// A window's z-order changed. Payload: window id. Also doubles as a
    /// focus hint — window-sweaters schedules a focus check from it.
    public static let windowReorder = WindowEvent(rawValue: 808)

    /// A window's level changed (payload: window id).
    public static let windowLevel = WindowEvent(rawValue: 811)

    /// A window was unhidden (payload: window id).
    public static let windowUnhide = WindowEvent(rawValue: 815)

    /// A window was hidden (payload: window id).
    public static let windowHide = WindowEvent(rawValue: 816)

    /// A window's title changed (payload: window id). Also fires on focus.
    public static let windowTitle = WindowEvent(rawValue: 1322)

    /// A window was created. Payload: `struct { uint64_t sid; uint32_t wid; }`.
    public static let windowCreate = WindowEvent(rawValue: 1325)

    /// A window was destroyed or removed from a space. Payload:
    /// `struct { uint64_t sid; uint32_t wid; }` — also arrives when a live
    /// window changes displays.
    public static let windowDestroy = WindowEvent(rawValue: 1326)

    /// The active space changed on some display.
    public static let spaceChange = WindowEvent(rawValue: 1401)

    /// The frontmost application changed.
    public static let frontApplicationChange = WindowEvent(rawValue: 1508)
}

/// Decoded payload of a ``WindowEvent`` delivered by the WindowServer.
public struct WindowEventInfo: Hashable, Sendable {
    /// The event that fired.
    public let event: WindowEvent
    /// The window the event is about. 0 for global events like
    /// ``WindowEvent/spaceChange``.
    public let windowID: CGWindowID
    /// The space the window was created on/destroyed from. Only present in
    /// ``WindowEvent/windowCreate`` and ``WindowEvent/windowDestroy``
    /// payloads.
    public let spaceID: UInt64?
}

/// Central subscription point for WindowServer events.
///
/// Handlers are keyed per event and always invoked on the main queue.
/// SkyLight itself may call the C callback from a mach message thread;
/// hopping to main keeps subscribers (SwiftUI state in particular) safe by
/// construction.
///
/// `subscribe`/`cancel` must be called from the main thread.
///
/// Registration failures and payload problems are logged to the
/// `WindowEventCenter` OSLog category (subsystem: host bundle id); event
/// delivery is logged at `debug` level.
public final class WindowEventCenter {
    public static let shared = WindowEventCenter()

    public typealias Handler = (WindowEventInfo) -> Void

    /// Cancels a subscription. Also cancels on deinit.
    public final class Subscription {
        fileprivate let id = UUID()
        fileprivate let event: WindowEvent
        private weak var center: WindowEventCenter?

        fileprivate init(center: WindowEventCenter, event: WindowEvent) {
            self.center = center
            self.event = event
        }

        public func cancel() {
            center?.unsubscribe(self)
            center = nil
        }

        deinit { cancel() }
    }

    /// Handlers keyed by event rawValue — a subscription only receives the
    /// event it subscribed to.
    private var handlers: [UInt32: [UUID: Handler]] = [:]
    private var registeredEvents = Set<UInt32>()
    private let registerNotifyProc: SLS.RegisterNotifyProc?
    private let logger = Logger(subsystem: Log.subsystem, category: "WindowEventCenter")

    private init() {
        registerNotifyProc = SLS.registerNotifyProc
        if registerNotifyProc == nil {
            logger.error("SLSRegisterNotifyProc not available — no WindowServer events will be delivered")
        }
    }

    /// Whether `SLSRegisterNotifyProc` was resolved successfully.
    public var isAvailable: Bool { registerNotifyProc != nil }

    /// Subscribes to a WindowServer event. Multiple subscriptions to the same
    /// event share a single `SLSRegisterNotifyProc` registration.
    ///
    /// - Note: per-window events (``WindowEvent/windowMove``,
    ///   ``WindowEvent/windowResize``) are only delivered for windows passed
    ///   to ``WindowTracker`` or `SLSRequestNotificationsForWindows`.
    public func subscribe(to event: WindowEvent, handler: @escaping Handler) -> Subscription {
        let subscription = Subscription(center: self, event: event)
        handlers[event.rawValue, default: [:]][subscription.id] = handler

        if !registeredEvents.contains(event.rawValue), let registerNotifyProc {
            let context = Unmanaged.passUnretained(self).toOpaque()
            let error = registerNotifyProc(Self.notifyCallback, event.rawValue, context)
            if error == 0 {
                registeredEvents.insert(event.rawValue)
                logger.debug("registered for event \(event.rawValue)")
            } else {
                logger.error("SLSRegisterNotifyProc failed for event \(event.rawValue): CGError \(error)")
            }
        }
        return subscription
    }

    fileprivate func unsubscribe(_ subscription: Subscription) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.unsubscribe(subscription) }
            return
        }
        handlers[subscription.event.rawValue]?[subscription.id] = nil
        if handlers[subscription.event.rawValue]?.isEmpty != false {
            handlers[subscription.event.rawValue] = nil
        }
    }

    private static let notifyCallback: SLS.NotifyProc = { event, data, length, context in
        guard let context else { return }
        let center = Unmanaged<WindowEventCenter>.fromOpaque(context).takeUnretainedValue()

        // Payloads differ per event family: create/destroy carry a
        // `{ uint64_t sid; uint32_t wid; }` struct (window-sweaters'
        // window_spawn_handler), everything else we care about is a bare
        // window id. Events with no window payload decode to windowID 0.
        // WindowServer payloads are not guaranteed aligned — plain
        // `load(as:)` traps on misaligned access.
        var windowID: CGWindowID = 0
        var spaceID: UInt64? = nil
        if let data {
            let isSpawnEvent = event == WindowEvent.windowCreate.rawValue
                || event == WindowEvent.windowDestroy.rawValue
            if isSpawnEvent && length >= 12 {
                spaceID = data.loadUnaligned(as: UInt64.self)
                windowID = data.loadUnaligned(fromByteOffset: 8, as: UInt32.self)
            } else if length >= 4 {
                windowID = data.loadUnaligned(as: UInt32.self)
            }
        }

        let info = WindowEventInfo(event: WindowEvent(rawValue: event),
                                   windowID: windowID,
                                   spaceID: spaceID)
        // `handlers` is owned by the main thread — look up and deliver there.
        DispatchQueue.main.async {
            guard let subscribers = center.handlers[event], !subscribers.isEmpty else { return }
            center.logger.debug("event \(event) wid=\(windowID) subscribers=\(subscribers.count)")
            for handler in subscribers.values {
                handler(info)
            }
        }
    }
}

/// Shared OSLog subsystem for the SkyLight package. Uses the host app's
/// bundle identifier so `log show --process Collect` picks it up.
enum Log {
    static let subsystem = Bundle.main.bundleIdentifier ?? "SkyLight"
}
