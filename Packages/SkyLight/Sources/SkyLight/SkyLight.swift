//
//  SkyLight.swift
//  SkyLight
//
//  Swift wrapper around the private SkyLight framework — the client library
//  of the macOS WindowServer. Everything is resolved with dlopen/dlsym at
//  runtime so the module never links private symbols directly, and every
//  wrapper degrades to nil/false instead of crashing when a symbol is gone.
//
//  Function signatures follow the ones used by window-sweaters (a
//  JankyBorders fork) and yabai, which are known-good on modern macOS.
//

import CoreGraphics
import Foundation

/// Namespace for process-wide WindowServer state and free functions.
///
/// Most SkyLight calls take a connection id ("cid"). `mainConnectionID` is the
/// per-process connection created by the system for every GUI app; additional
/// private connections can be made with `newConnection()`.
public enum SkyLight {

    /// Whether the SkyLight framework was found and its core entry points
    /// resolved. All other API silently no-ops when this is false.
    public static var isAvailable: Bool { SLS.mainConnectionID != nil }

    /// The id of this process's main WindowServer connection
    /// (`SLSMainConnectionID`). 0 when SkyLight is unavailable.
    public static var mainConnectionID: Int32 {
        SLS.mainConnectionID?() ?? 0
    }

    /// Creates an additional private WindowServer connection
    /// (`SLSNewConnection`). Extra connections isolate window operations —
    /// window-sweaters gives each border its own connection so a failure on
    /// one overlay cannot wedge the others.
    ///
    /// - Returns: the new connection id, or nil on failure.
    public static func newConnection() -> Int32? {
        guard let fn = SLS.newConnection else { return nil }
        var cid: Int32 = 0
        guard fn(0, &cid) == 0, cid != 0 else { return nil }
        return cid
    }

    /// Releases a connection created with `newConnection()`
    /// (`SLSReleaseConnection`). Never release `mainConnectionID`.
    public static func releaseConnection(_ cid: Int32) {
        _ = SLS.releaseConnection?(cid)
    }

    /// `SLSDisableUpdate` / `SLSReenableUpdate` — suspend and resume
    /// WindowServer screen updates for the whole connection. Used to make a
    /// reshape + redraw appear atomic; always re-enable.
    public static func disableUpdates(on cid: Int32 = mainConnectionID) {
        _ = SLS.disableUpdate?(cid)
    }

    /// See ``disableUpdates(on:)``.
    public static func reenableUpdates(on cid: Int32 = mainConnectionID) {
        _ = SLS.reenableUpdate?(cid)
    }
}

/// Resolved SkyLight entry points. Function pointers are looked up lazily via
/// `static let` on first access so a missing symbol never traps at load time.
enum SLS {
    static let handle: UnsafeMutableRawPointer? =
        dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)

    /// Resolves a symbol from the SkyLight image to a C function pointer.
    static func symbol<T>(_ name: String, as type: T.Type = T.self) -> T? {
        guard let handle, let pointer = dlsym(handle, name) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }

    // MARK: - Connections

    typealias MainConnectionID = @convention(c) () -> Int32
    /// `int SLSMainConnectionID()`
    static let mainConnectionID: MainConnectionID? = symbol("SLSMainConnectionID")

    typealias NewConnection = @convention(c) (Int32, UnsafeMutablePointer<Int32>) -> Int32
    /// `CGError SLSNewConnection(int zero, int *cid)`
    static let newConnection: NewConnection? = symbol("SLSNewConnection")

    typealias ReleaseConnection = @convention(c) (Int32) -> Int32
    /// `CGError SLSReleaseConnection(int cid)`
    static let releaseConnection: ReleaseConnection? = symbol("SLSReleaseConnection")

    // MARK: - Notifications

    /// `void (*)(uint32_t event, void *data, size_t length, void *context)`
    typealias NotifyProc = @convention(c) (UInt32, UnsafeMutableRawPointer?, Int, UnsafeMutableRawPointer?) -> Void

    typealias RegisterNotifyProc = @convention(c) (NotifyProc, UInt32, UnsafeMutableRawPointer?) -> Int32
    /// `CGError SLSRegisterNotifyProc(void *handler, uint32_t event, void *context)`
    static let registerNotifyProc: RegisterNotifyProc? = symbol("SLSRegisterNotifyProc")

    typealias RequestNotificationsForWindows = @convention(c) (Int32, UnsafeMutablePointer<UInt32>?, Int32) -> Int32
    /// `CGError SLSRequestNotificationsForWindows(int cid, uint32_t *list, int count)`.
    /// Move/resize notifications are only delivered for windows listed here.
    static let requestNotificationsForWindows: RequestNotificationsForWindows? = symbol("SLSRequestNotificationsForWindows")

    // MARK: - Window queries

    typealias GetWindowBounds = @convention(c) (Int32, UInt32, UnsafeMutablePointer<CGRect>) -> Int32
    /// `CGError SLSGetWindowBounds(int cid, uint32_t wid, CGRect *frame)`.
    /// Frame is in global top-left screen coordinates (same as AXFrame and
    /// kCGWindowBounds).
    static let getWindowBounds: GetWindowBounds? = symbol("SLSGetWindowBounds")

    typealias GetWindowOwner = @convention(c) (Int32, UInt32, UnsafeMutablePointer<Int32>) -> Int32
    /// `CGError SLSGetWindowOwner(int cid, uint32_t wid, int *out_cid)` —
    /// returns the *connection id* owning the window, not a pid.
    static let getWindowOwner: GetWindowOwner? = symbol("SLSGetWindowOwner")

    typealias ConnectionGetPID = @convention(c) (Int32, UnsafeMutablePointer<pid_t>) -> Int32
    /// `CGError SLSConnectionGetPID(int cid, pid_t *pid)`
    static let connectionGetPID: ConnectionGetPID? = symbol("SLSConnectionGetPID")

    typealias WindowIsOrderedIn = @convention(c) (Int32, UInt32, UnsafeMutablePointer<Bool>) -> Int32
    /// `CGError SLSWindowIsOrderedIn(int cid, uint32_t wid, bool *shown)` —
    /// true while the window is on screen in the window server's ordering.
    static let windowIsOrderedIn: WindowIsOrderedIn? = symbol("SLSWindowIsOrderedIn")

    typealias GetWindowLevel = @convention(c) (Int32, UInt32, UnsafeMutablePointer<Int64>) -> Int32
    /// `CGError SLSGetWindowLevel(int cid, uint32_t wid, int64_t *level)`
    static let getWindowLevel: GetWindowLevel? = symbol("SLSGetWindowLevel")

    typealias GetWindowTransform = @convention(c) (Int32, UInt32, UnsafeMutablePointer<CGAffineTransform>) -> Int32
    /// `CGError SLSGetWindowTransform(int cid, uint32_t wid, CGAffineTransform *t)`
    static let getWindowTransform: GetWindowTransform? = symbol("SLSGetWindowTransform")

    typealias GetWindowAlpha = @convention(c) (Int32, UInt32, UnsafeMutablePointer<Float>) -> Int32
    /// `CGError SLSGetWindowAlpha(int cid, uint32_t wid, float *alpha)`
    static let getWindowAlpha: GetWindowAlpha? = symbol("SLSGetWindowAlpha")

    // MARK: - Window mutations

    typealias SetWindowTags = @convention(c) (Int32, UInt32, UnsafeMutablePointer<UInt64>, Int32) -> Int32
    /// `CGError SLSSetWindowTags(int cid, uint32_t wid, uint64_t *tags, int tag_size)`.
    /// tag_size is the bit count of the tag field (window-sweaters uses 64).
    static let setWindowTags: SetWindowTags? = symbol("SLSSetWindowTags")

    typealias ClearWindowTags = @convention(c) (Int32, UInt32, UnsafeMutablePointer<UInt64>, Int32) -> Int32
    /// `CGError SLSClearWindowTags(int cid, uint32_t wid, uint64_t *tags, int tag_size)`
    static let clearWindowTags: ClearWindowTags? = symbol("SLSClearWindowTags")

    typealias SetWindowShape = @convention(c) (Int32, UInt32, Float, Float, CFTypeRef?) -> Int32
    /// `CGError SLSSetWindowShape(int cid, uint32_t wid, float x, float y, CFTypeRef shape)`.
    /// shape is a CGS region (see `CGSNewRegionWithRect`); nil leaves the
    /// shape unchanged while still moving the window to (x, y).
    static let setWindowShape: SetWindowShape? = symbol("SLSSetWindowShape")

    typealias NewRegionWithRect = @convention(c) (UnsafePointer<CGRect>, UnsafeMutablePointer<CFTypeRef?>) -> Int32
    /// `CGError CGSNewRegionWithRect(CGRect *rect, CFTypeRef *outRegion)`
    static let newRegionWithRect: NewRegionWithRect? = symbol("CGSNewRegionWithRect")

    typealias SetWindowAlpha = @convention(c) (Int32, UInt32, Float) -> Int32
    /// `CGError SLSSetWindowAlpha(int cid, uint32_t wid, float alpha)`
    static let setWindowAlpha: SetWindowAlpha? = symbol("SLSSetWindowAlpha")

    typealias SetWindowOpacity = @convention(c) (Int32, UInt32, Bool) -> Int32
    /// `CGError SLSSetWindowOpacity(int cid, uint32_t wid, bool isOpaque)` —
    /// note this toggles the window's *opaqueness*, not its alpha.
    static let setWindowOpacity: SetWindowOpacity? = symbol("SLSSetWindowOpacity")

    typealias SetWindowResolution = @convention(c) (Int32, UInt32, Double) -> Int32
    /// `CGError SLSSetWindowResolution(int cid, uint32_t wid, double res)` —
    /// backing scale factor; use 2.0 for Retina overlays.
    static let setWindowResolution: SetWindowResolution? = symbol("SLSSetWindowResolution")

    typealias SetWindowBackgroundBlurRadius = @convention(c) (Int32, UInt32, UInt32) -> Int32
    /// `CGError SLSSetWindowBackgroundBlurRadius(int cid, uint32_t wid, uint32_t radius)`
    static let setWindowBackgroundBlurRadius: SetWindowBackgroundBlurRadius? = symbol("SLSSetWindowBackgroundBlurRadius")

    typealias SetWindowShadowParameters = @convention(c) (Int32, UInt32, Float, Float, Int32, Int32) -> Int32
    /// `CGError SLSSetWindowShadowParameters(int cid, uint32_t wid, float stdDev,
    /// float density, int xOffset, int yOffset)`
    static let setWindowShadowParameters: SetWindowShadowParameters? = symbol("SLSSetWindowShadowParameters")

    typealias SetWindowTransform = @convention(c) (Int32, UInt32, CGAffineTransform) -> Int32
    /// `CGError SLSSetWindowTransform(int cid, uint32_t wid, CGAffineTransform t)`
    static let setWindowTransform: SetWindowTransform? = symbol("SLSSetWindowTransform")

    typealias MoveWindowsToManagedSpace = @convention(c) (Int32, CFArray, UInt64) -> Int32
    /// `CGError SLSMoveWindowsToManagedSpace(int cid, CFArrayRef window_list, uint64_t sid)`
    static let moveWindowsToManagedSpace: MoveWindowsToManagedSpace? = symbol("SLSMoveWindowsToManagedSpace")

    typealias FlushWindowContentRegion = @convention(c) (Int32, UInt32, UnsafeMutableRawPointer?) -> Int32
    /// `CGError SLSFlushWindowContentRegion(int cid, uint32_t wid, void *dirty)` —
    /// push a redrawn backing store to the WindowServer. nil dirty region
    /// flushes the whole window.
    static let flushWindowContentRegion: FlushWindowContentRegion? = symbol("SLSFlushWindowContentRegion")

    typealias WindowFreezeWithOptions = @convention(c) (Int32, UInt32, CFTypeRef?) -> Int32
    /// `CGError SLSWindowFreezeWithOptions(int cid, uint32_t wid, CFTypeRef options)` —
    /// freeze a window's surface while it is reshaped (pair with `windowThaw`).
    static let windowFreezeWithOptions: WindowFreezeWithOptions? = symbol("SLSWindowFreezeWithOptions")

    typealias WindowThaw = @convention(c) (Int32, UInt32) -> Int32
    /// `CGError SLSWindowThaw(int cid, uint32_t wid)`
    static let windowThaw: WindowThaw? = symbol("SLSWindowThaw")

    typealias DisableUpdate = @convention(c) (Int32) -> Int32
    /// `CGError SLSDisableUpdate(int cid)` / `SLSReenableUpdate`
    static let disableUpdate: DisableUpdate? = symbol("SLSDisableUpdate")
    static let reenableUpdate: DisableUpdate? = symbol("SLSReenableUpdate")

    // MARK: - Window creation / drawing

    typealias NewWindow = @convention(c) (Int32, Int32, Float, Float, CFTypeRef, UnsafeMutablePointer<UInt32>) -> Int32
    /// `CGError SLSNewWindow(int cid, int type, float x, float y,
    /// CFTypeRef region, uint32_t *wid)` — creates a bare WindowServer window
    /// with no AppKit involvement. type is a CGWindowBackingType
    /// (kCGBackingStoreBuffered = 2).
    static let newWindow: NewWindow? = symbol("SLSNewWindow")

    typealias ReleaseWindow = @convention(c) (Int32, UInt32) -> Int32
    /// `CGError SLSReleaseWindow(int cid, uint32_t wid)`
    static let releaseWindow: ReleaseWindow? = symbol("SLSReleaseWindow")

    typealias WindowContextCreate = @convention(c) (Int32, UInt32, CFDictionary?) -> CGContext?
    /// `CGContextRef SLWindowContextCreate(int cid, uint32_t wid, CFDictionaryRef options)` —
    /// a drawing context targeting the window's backing store; bottom-left
    /// origin like any CGContext. Created once against the backing store as it
    /// was at creation time — recreate after growing a window.
    static let windowContextCreate: WindowContextCreate? = symbol("SLWindowContextCreate")

    // MARK: - Spaces & displays

    typealias CopySpacesForWindows = @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?
    /// `CFArrayRef SLSCopySpacesForWindows(int cid, int selector, CFArrayRef window_list)` —
    /// space ids for the given windows. Selector 0x7 queries across spaces.
    static let copySpacesForWindows: CopySpacesForWindows? = symbol("SLSCopySpacesForWindows")

    typealias CopyManagedDisplays = @convention(c) (Int32) -> Unmanaged<CFArray>?
    /// `CFArrayRef SLSCopyManagedDisplays(int cid)` — array of display UUID
    /// CFStrings for managed (non-mirror) displays.
    static let copyManagedDisplays: CopyManagedDisplays? = symbol("SLSCopyManagedDisplays")

    typealias CopyManagedDisplaySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>?
    /// `CFArrayRef SLSCopyManagedDisplaySpaces(int cid)` — array of dicts,
    /// each with a "Spaces" array of dicts containing "id64" numbers.
    static let copyManagedDisplaySpaces: CopyManagedDisplaySpaces? = symbol("SLSCopyManagedDisplaySpaces")

    typealias CopyManagedDisplayForWindow = @convention(c) (Int32, UInt32) -> Unmanaged<CFString>?
    /// `CFStringRef SLSCopyManagedDisplayForWindow(int cid, uint32_t wid)`
    static let copyManagedDisplayForWindow: CopyManagedDisplayForWindow? = symbol("SLSCopyManagedDisplayForWindow")

    typealias ManagedDisplayGetCurrentSpace = @convention(c) (Int32, CFString) -> UInt64
    /// `uint64_t SLSManagedDisplayGetCurrentSpace(int cid, CFStringRef uuid)`
    static let managedDisplayGetCurrentSpace: ManagedDisplayGetCurrentSpace? = symbol("SLSManagedDisplayGetCurrentSpace")

    typealias CopyActiveMenuBarDisplayIdentifier = @convention(c) (Int32) -> Unmanaged<CFString>?
    /// `CFStringRef SLSCopyActiveMenuBarDisplayIdentifier(int cid)` — the
    /// display whose menu bar is active, i.e. the "focused" display.
    static let copyActiveMenuBarDisplayIdentifier: CopyActiveMenuBarDisplayIdentifier? = symbol("SLSCopyActiveMenuBarDisplayIdentifier")

    // MARK: - Window list queries

    typealias CopyWindowsWithOptionsAndTags = @convention(c) (Int32, UInt32, CFArray, UInt32, UnsafeMutablePointer<UInt64>, UnsafeMutablePointer<UInt64>) -> Unmanaged<CFArray>?
    /// `CFArrayRef SLSCopyWindowsWithOptionsAndTags(int cid, uint32_t owner_cid,
    /// CFArrayRef spaces, uint32_t options, uint64_t *set_tags, uint64_t *clear_tags)` —
    /// window ids on the given spaces filtered by tag bits. Option 0x2 is the
    /// "on screen" style filter used by JankyBorders/yabai.
    static let copyWindowsWithOptionsAndTags: CopyWindowsWithOptionsAndTags? = symbol("SLSCopyWindowsWithOptionsAndTags")

    typealias WindowQueryWindows = @convention(c) (Int32, CFArray, UInt32) -> Unmanaged<AnyObject>?
    /// `CFTypeRef SLSWindowQueryWindows(int cid, CFArrayRef windows, uint32_t options)` —
    /// begins a batched query over a list of window ids.
    static let windowQueryWindows: WindowQueryWindows? = symbol("SLSWindowQueryWindows")

    typealias WindowQueryResultCopyWindows = @convention(c) (AnyObject) -> Unmanaged<AnyObject>?
    /// `CFTypeRef SLSWindowQueryResultCopyWindows(CFTypeRef query)` — iterator
    /// over the query result.
    static let windowQueryResultCopyWindows: WindowQueryResultCopyWindows? = symbol("SLSWindowQueryResultCopyWindows")

    typealias WindowIteratorGetCount = @convention(c) (AnyObject) -> Int32
    /// `int SLSWindowIteratorGetCount(CFTypeRef iterator)`
    static let windowIteratorGetCount: WindowIteratorGetCount? = symbol("SLSWindowIteratorGetCount")

    typealias WindowIteratorAdvance = @convention(c) (AnyObject) -> Bool
    /// `bool SLSWindowIteratorAdvance(CFTypeRef iterator)` — advance to the
    /// next row; call before the first read.
    static let windowIteratorAdvance: WindowIteratorAdvance? = symbol("SLSWindowIteratorAdvance")

    typealias WindowIteratorGetWindowID = @convention(c) (AnyObject) -> UInt32
    /// `uint32_t SLSWindowIteratorGetWindowID(CFTypeRef iterator)`
    static let windowIteratorGetWindowID: WindowIteratorGetWindowID? = symbol("SLSWindowIteratorGetWindowID")

    typealias WindowIteratorGetParentID = @convention(c) (AnyObject) -> UInt32
    /// `uint32_t SLSWindowIteratorGetParentID(CFTypeRef iterator)` — parent
    /// window id (e.g. an attached sheet's window), 0 for top-level windows.
    static let windowIteratorGetParentID: WindowIteratorGetParentID? = symbol("SLSWindowIteratorGetParentID")

    typealias WindowIteratorGetTags = @convention(c) (AnyObject) -> UInt64
    /// `uint64_t SLSWindowIteratorGetTags(CFTypeRef iterator)` — WindowServer
    /// tag bits (document, floating, modal, sticky...). See `WindowTag`.
    static let windowIteratorGetTags: WindowIteratorGetTags? = symbol("SLSWindowIteratorGetTags")

    typealias WindowIteratorGetAttributes = @convention(c) (AnyObject) -> UInt64
    /// `uint64_t SLSWindowIteratorGetAttributes(CFTypeRef iterator)`
    static let windowIteratorGetAttributes: WindowIteratorGetAttributes? = symbol("SLSWindowIteratorGetAttributes")

    typealias WindowIteratorGetLevel = @convention(c) (AnyObject) -> Int32
    /// `int SLSWindowIteratorGetLevel(CFTypeRef iterator)` — the window level,
    /// same scale as NSWindow.Level raw values.
    static let windowIteratorGetLevel: WindowIteratorGetLevel? = symbol("SLSWindowIteratorGetLevel")

    // MARK: - Transactions

    typealias TransactionCreate = @convention(c) (Int32) -> Unmanaged<AnyObject>?
    /// `CFTypeRef SLSTransactionCreate(int cid)` — batch WindowServer window
    /// operations and apply them in one commit.
    static let transactionCreate: TransactionCreate? = symbol("SLSTransactionCreate")

    typealias TransactionCommit = @convention(c) (AnyObject, Int32) -> Int32
    /// `CGError SLSTransactionCommit(CFTypeRef transaction, int synchronous)`
    static let transactionCommit: TransactionCommit? = symbol("SLSTransactionCommit")

    typealias TransactionMoveWindowWithGroup = @convention(c) (AnyObject, UInt32, CGPoint) -> Int32
    /// `CGError SLSTransactionMoveWindowWithGroup(CFTypeRef t, uint32_t wid, CGPoint point)` —
    /// move a window including its "movement group" peers (overlays ordered
    /// relative to it travel together).
    static let transactionMoveWindowWithGroup: TransactionMoveWindowWithGroup? = symbol("SLSTransactionMoveWindowWithGroup")

    typealias TransactionOrderWindow = @convention(c) (AnyObject, UInt32, Int32, UInt32) -> Int32
    /// `CGError SLSTransactionOrderWindow(CFTypeRef t, uint32_t wid, int order,
    /// uint32_t relative_wid)` — order 1 = above relative window,
    /// -1 (BORDER_ORDER_BELOW in window-sweaters) = below.
    static let transactionOrderWindow: TransactionOrderWindow? = symbol("SLSTransactionOrderWindow")

    typealias TransactionSetWindowLevel = @convention(c) (AnyObject, UInt32, Int32) -> Int32
    /// `CGError SLSTransactionSetWindowLevel(CFTypeRef t, uint32_t wid, int level)`
    static let transactionSetWindowLevel: TransactionSetWindowLevel? = symbol("SLSTransactionSetWindowLevel")

    typealias TransactionSetWindowSubLevel = @convention(c) (AnyObject, UInt32, Int32) -> Int32
    /// `CGError SLSTransactionSetWindowSubLevel(CFTypeRef t, uint32_t wid, int level)`
    static let transactionSetWindowSubLevel: TransactionSetWindowSubLevel? = symbol("SLSTransactionSetWindowSubLevel")

    typealias TransactionSetWindowShape = @convention(c) (AnyObject, UInt32, Float, Float, CFTypeRef?) -> Int32
    /// `CGError SLSTransactionSetWindowShape(CFTypeRef t, uint32_t wid, float x,
    /// float y, CFTypeRef shape)`
    static let transactionSetWindowShape: TransactionSetWindowShape? = symbol("SLSTransactionSetWindowShape")

    typealias TransactionSetWindowAlpha = @convention(c) (AnyObject, UInt32, Float) -> Int32
    /// `CGError SLSTransactionSetWindowAlpha(CFTypeRef t, uint32_t wid, float alpha)`
    static let transactionSetWindowAlpha: TransactionSetWindowAlpha? = symbol("SLSTransactionSetWindowAlpha")

    typealias TransactionSetWindowTransform = @convention(c) (AnyObject, UInt32, Int32, Int32, CGAffineTransform) -> Int32
    /// `CGError SLSTransactionSetWindowTransform(CFTypeRef t, uint32_t wid,
    /// int unknown0, int unknown1, CGAffineTransform transform)` — the two
    /// ints are undocumented flags; window-sweaters passes 0, 0.
    static let transactionSetWindowTransform: TransactionSetWindowTransform? = symbol("SLSTransactionSetWindowTransform")
}
