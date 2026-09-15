//
//  SLWindow.swift
//  SkyLight
//
//  `SLWindow` is a value-type handle to a WindowServer window. All state is
//  queried per access — the struct only stores the window id, so it is cheap
//  to keep around and compare.
//
//  Window tags (the `SLSWindowIteratorGetTags` bits) classify windows the way
//  the WindowServer does: document, floating, attached, modal... These are
//  the bits window-sweaters' `window_suitable` inspects to find "real"
//  windows worth tracking.
//

import CoreGraphics
import Foundation

/// WindowServer tag bits for classifying windows
/// (`SLSWindowIteratorGetTags`). Values follow window-sweaters' window.h.
public struct WindowTag: OptionSet, Hashable, Sendable {
    public let rawValue: UInt64
    public init(rawValue: UInt64) { self.rawValue = rawValue }

    /// A normal document window.
    public static let document = WindowTag(rawValue: 1 << 0)
    /// A floating utility/palette window.
    public static let floating = WindowTag(rawValue: 1 << 1)
    /// Attached to another window (sheets, attached menus).
    public static let attached = WindowTag(rawValue: 1 << 7)
    /// Shown on every space ("sticky" windows float across spaces).
    public static let sticky = WindowTag(rawValue: 1 << 11)
    /// Excluded from the window cycle (cmd-`) — status bars, docks, HUDs.
    public static let ignoresCycle = WindowTag(rawValue: 1 << 18)
    /// A modal window — combined with ``floating`` these are "real" windows
    /// even without the ``document`` bit.
    public static let modal = WindowTag(rawValue: 1 << 31)
}

/// Snapshot of a window's attributes from a `SLSWindowQueryWindows` row.
/// Fetch once via ``SLWindow/info`` when more than one field is needed —
/// every accessor below that goes through the iterator runs a fresh query.
public struct WindowInfo: Hashable, Sendable {
    public let tags: WindowTag
    public let attributes: UInt64
    /// Parent window id — nonzero for sheets and attached windows.
    public let parentID: CGWindowID
    /// Window level on the NSWindow.Level scale.
    public let level: Int

    /// window-sweaters' `window_suitable` heuristic: a top-level window that
    /// is a document (or modal floating) window, not attached to another
    /// window, and participates in the window cycle. Good filter for
    /// "a window a user would consider real".
    public var isStandardWindow: Bool {
        parentID == 0
            && (attributes & 0x2 != 0 || tags.contains(WindowTag(rawValue: 0x400000000000000)))
            && !tags.contains(.attached)
            && !tags.contains(.ignoresCycle)
            && (tags.contains(.document) || (tags.contains(.floating) && tags.contains(.modal)))
    }
}

/// A WindowServer window handle.
///
/// `id` is the same window id used by `CGWindowList`, `_AXUIElementGetWindow`
/// and SkyLight notifications, so this bridges all three APIs.
public struct SLWindow: Hashable, Sendable {
    public let id: CGWindowID
    private let cid: Int32

    /// Wraps a WindowServer window id, owned by `connection` (defaults to
    /// ``SkyLight/mainConnectionID``).
    public init(_ id: CGWindowID, on cid: Int32 = SkyLight.mainConnectionID) {
        self.id = id
        self.cid = cid
    }

    // MARK: - Queries

    /// Window frame in global top-left screen coordinates
    /// (`SLSGetWindowBounds`). Matches AXFrame, so window deltas can be
    /// applied directly to accessibility geometry. nil if the window is gone
    /// or the call fails.
    public var bounds: CGRect? {
        guard let fn = SLS.getWindowBounds else { return nil }
        var frame = CGRect.zero
        return fn(cid, id, &frame) == 0 ? frame : nil
    }

    /// pid of the process that owns the window (`SLSGetWindowOwner` +
    /// `SLSConnectionGetPID`).
    public var ownerPID: pid_t? {
        guard let ownerFn = SLS.getWindowOwner, let pidFn = SLS.connectionGetPID else { return nil }
        var ownerCID: Int32 = 0
        var pid: pid_t = 0
        guard ownerFn(cid, id, &ownerCID) == 0, pidFn(ownerCID, &pid) == 0 else { return nil }
        return pid
    }

    /// True while the window is ordered into the screen's window list
    /// (`SLSWindowIsOrderedIn`). False for minimized and off-screen windows.
    public var isOrderedIn: Bool {
        guard let fn = SLS.windowIsOrderedIn else { return false }
        var ordered = false
        return fn(cid, id, &ordered) == 0 && ordered
    }

    /// Window level (`SLSGetWindowLevel`, NSWindow.Level scale).
    public var level: Int? {
        guard let fn = SLS.getWindowLevel else { return nil }
        var level: Int64 = 0
        return fn(cid, id, &level) == 0 ? Int(level) : nil
    }

    /// The window's transform (`SLSGetWindowTransform`), e.g. genie
    /// minimize animations.
    public var transform: CGAffineTransform? {
        guard let fn = SLS.getWindowTransform else { return nil }
        var t = CGAffineTransform.identity
        return fn(cid, id, &t) == 0 ? t : nil
    }

    /// Current alpha (`SLSGetWindowAlpha`).
    public var alpha: Float? {
        guard let fn = SLS.getWindowAlpha else { return nil }
        var alpha: Float = 0
        return fn(cid, id, &alpha) == 0 ? alpha : nil
    }

    /// One-shot snapshot of the window's query row (`SLSWindowQueryWindows` +
    /// `SLSWindowIterator*`). Prefer this over the individual accessors when
    /// you need several fields.
    public var info: WindowInfo? {
        guard let queryFn = SLS.windowQueryWindows,
              let copyFn = SLS.windowQueryResultCopyWindows,
              let countFn = SLS.windowIteratorGetCount,
              let advanceFn = SLS.windowIteratorAdvance,
              let tagsFn = SLS.windowIteratorGetTags,
              let attrsFn = SLS.windowIteratorGetAttributes,
              let parentFn = SLS.windowIteratorGetParentID,
              let levelFn = SLS.windowIteratorGetLevel else { return nil }

        let windowList = [id] as CFArray
        guard let query = queryFn(cid, windowList, 0)?.takeRetainedValue() else { return nil }
        guard let iterator = copyFn(query)?.takeRetainedValue() else { return nil }
        guard countFn(iterator) > 0, advanceFn(iterator) else { return nil }

        return WindowInfo(
            tags: WindowTag(rawValue: tagsFn(iterator)),
            attributes: attrsFn(iterator),
            parentID: parentFn(iterator),
            level: Int(levelFn(iterator))
        )
    }

    /// Tags only (`SLSWindowQueryWindows`). See ``WindowTag``.
    public var tags: WindowTag? { info?.tags }

    /// Space ids this window lives on (`SLSCopySpacesForWindows`, selector
    /// 0x7 = query all spaces). Falls back to the window's display's current
    /// space when the direct query returns nothing — mirrors
    /// window-sweaters' `window_space_id`.
    public var spaceIDs: [UInt64] {
        guard let copyFn = SLS.copySpacesForWindows else { return [] }
        let windowList = [id] as CFArray
        var spaces: [UInt64] = []
        if let list = copyFn(cid, 0x7, windowList)?.takeRetainedValue() as? [NSNumber] {
            spaces = list.map { UInt64(bitPattern: $0.int64Value) }
        }
        if spaces.isEmpty, let uuid = displayUUID,
           let fn = SLS.managedDisplayGetCurrentSpace {
            let sid = fn(cid, uuid as CFString)
            if sid != 0 { spaces = [sid] }
        }
        return spaces
    }

    /// UUID string of the managed display showing the window
    /// (`SLSCopyManagedDisplayForWindow`).
    public var displayUUID: String? {
        guard let fn = SLS.copyManagedDisplayForWindow else { return nil }
        return fn(cid, id)?.takeRetainedValue() as String?
    }

    /// True if the window is on a currently-visible space on some display.
    /// Cheap enough to call from move handlers to hide overlays for windows
    /// that slid onto another space.
    public var isOnVisibleSpace: Bool {
        SkyLight.isSpaceVisible(spaceIDs.first ?? 0)
    }

    // MARK: - Mutations

    /// Sets the window's alpha (`SLSSetWindowAlpha`).
    @discardableResult
    public func setAlpha(_ alpha: Float) -> Bool {
        SLS.setWindowAlpha?(cid, id, alpha) == 0
    }

    /// Sets window opaqueness (`SLSSetWindowOpacity`) — this toggles the
    /// opaque *flag*, not the alpha. Borders set it to false.
    @discardableResult
    public func setOpaque(_ opaque: Bool) -> Bool {
        SLS.setWindowOpacity?(cid, id, opaque) == 0
    }

    /// Sets the backing resolution (`SLSSetWindowResolution`); use 2.0 for
    /// Retina-sharp overlays.
    @discardableResult
    public func setResolution(_ resolution: Double) -> Bool {
        SLS.setWindowResolution?(cid, id, resolution) == 0
    }

    /// Sets the behind-window blur radius in points
    /// (`SLSSetWindowBackgroundBlurRadius`).
    @discardableResult
    public func setBackgroundBlurRadius(_ radius: UInt32) -> Bool {
        SLS.setWindowBackgroundBlurRadius?(cid, id, radius) == 0
    }

    /// Adjusts the shadow (`SLSSetWindowShadowParameters`). Pass
    /// `density: 0` to kill the shadow entirely.
    @discardableResult
    public func setShadowParameters(stdDev: Float, density: Float,
                                    offsetX: Int32, offsetY: Int32) -> Bool {
        SLS.setWindowShadowParameters?(cid, id, stdDev, density, offsetX, offsetY) == 0
    }

    /// Applies an affine transform (`SLSSetWindowTransform`).
    @discardableResult
    public func setTransform(_ transform: CGAffineTransform) -> Bool {
        SLS.setWindowTransform?(cid, id, transform) == 0
    }

    /// Sets tag bits (`SLSSetWindowTags`). `bitSize` is the bit count of the
    /// tag field — 64 sets/clears the full field, matching window-sweaters.
    @discardableResult
    public func setTags(_ tags: WindowTag, bitSize: Int32 = 64) -> Bool {
        var value = tags.rawValue
        return SLS.setWindowTags?(cid, id, &value, bitSize) == 0
    }

    /// Clears tag bits (`SLSClearWindowTags`).
    @discardableResult
    public func clearTags(_ tags: WindowTag, bitSize: Int32 = 64) -> Bool {
        var value = tags.rawValue
        return SLS.clearWindowTags?(cid, id, &value, bitSize) == 0
    }

    /// Moves and optionally reshapes the window (`SLSSetWindowShape` with a
    /// nil shape). This is the non-transactional way window-sweaters
    /// repositions borders; ``SLTransaction`` is preferable when combining
    /// a move with z-ordering.
    @discardableResult
    public func setPosition(x: Float, y: Float) -> Bool {
        SLS.setWindowShape?(cid, id, x, y, nil) == 0
    }

    /// Pushes the window's backing store to the WindowServer
    /// (`SLSFlushWindowContentRegion`, whole window). Call after drawing
    /// into the window's `CGContext` (see ``SLOverlayWindow``).
    @discardableResult
    public func flushContentRegion() -> Bool {
        SLS.flushWindowContentRegion?(cid, id, nil) == 0
    }

    /// Freezes the window's surface while it is resized/reshaped
    /// (`SLSWindowFreezeWithOptions`); pair with ``thaw()``.
    @discardableResult
    public func freeze() -> Bool {
        SLS.windowFreezeWithOptions?(cid, id, nil) == 0
    }

    /// See ``freeze()`` (`SLSWindowThaw`).
    @discardableResult
    public func thaw() -> Bool {
        SLS.windowThaw?(cid, id) == 0
    }

    /// Moves this window to another space (`SLSMoveWindowsToManagedSpace`).
    @discardableResult
    public func moveToSpace(_ spaceID: UInt64) -> Bool {
        guard let fn = SLS.moveWindowsToManagedSpace else { return false }
        let list = [id] as CFArray
        return fn(cid, list, spaceID) == 0
    }

    /// Destroys the window (`SLSReleaseWindow`). Only for windows created
    /// through this API — never release windows owned by other apps.
    @discardableResult
    public func destroy() -> Bool {
        SLS.releaseWindow?(cid, id) == 0
    }
}
