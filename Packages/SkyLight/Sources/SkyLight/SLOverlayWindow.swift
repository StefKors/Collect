//
//  SLOverlayWindow.swift
//  SkyLight
//
//  Bare WindowServer windows with a drawable CGContext — no AppKit, no
//  NSWindow. This is how window-sweaters/JankyBorders render their borders:
//  `SLSNewWindow` creates the surface, `SLWindowContextCreate` returns a
//  context to draw into, and `SLSFlushWindowContentRegion` pushes the pixels.
//  Ordering and movement are then done transactionally so the overlay lands
//  in the same commit as the window it decorates.
//

import CoreGraphics
import Foundation

/// A drawable WindowServer window created through SkyLight directly.
///
/// Creation follows window-sweaters' `window_create`: a buffered window off
/// screen, tagged as a non-participating overlay, shadow disabled, then moved
/// into place. The drawing `context` is created against the backing store as
/// it exists at creation time — call ``resize(to:)`` after growing the
/// window, it recreates the context for the new size.
public final class SLOverlayWindow {
    /// Window handle for queries, mutations and transactions.
    public let window: SLWindow

    private let cid: Int32

    /// Current frame in top-left global screen coordinates.
    public private(set) var frame: CGRect

    /// Context drawing into the window's backing store
    /// (`SLWindowContextCreate`). Bottom-left origin like any CGContext —
    /// remember to flip y if you draw with top-left coordinates. nil until
    /// the window is ordered on screen.
    public private(set) var context: CGContext?

    /// Creates a buffered overlay window (`SLSNewWindow` +
    /// `SLWindowContextCreate`). The window starts fully transparent
    /// (alpha 0) — draw, then raise alpha or order it in via a transaction.
    ///
    /// - Parameters:
    ///   - frame: initial frame in top-left global screen coordinates.
    ///   - hidpi: sets backing resolution 2.0 for Retina-sharp drawing.
    ///   - cid: connection to create the window on.
    public init?(frame: CGRect, hidpi: Bool = true, on cid: Int32 = SkyLight.mainConnectionID) {
        guard let newWindow = SLS.newWindow,
              let newRegion = SLS.newRegionWithRect,
              let contextCreate = SLS.windowContextCreate else { return nil }

        var frame = frame
        var region: CFTypeRef?
        guard newRegion(&frame, &region) == 0, let region else { return nil }

        var wid: UInt32 = 0
        // kCGBackingStoreBuffered = 2; window is created at -9999, -9999 and
        // moved into place afterwards, matching window-sweaters.
        guard newWindow(cid, 2, -9999, -9999, region, &wid) == 0, wid != 0 else { return nil }

        self.cid = cid
        self.window = SLWindow(wid, on: cid)
        self.frame = frame

        window.setResolution(hidpi ? 2.0 : 1.0)
        // Tag as a managed, cycle-exempt overlay — (1<<1)|(1<<9) is the tag
        // set window-sweaters applies to its border windows.
        window.setTags(WindowTag(rawValue: (1 << 1) | (1 << 9)))
        window.setOpaque(false)
        window.setShadowParameters(stdDev: 0, density: 0, offsetX: 0, offsetY: 0)
        window.setAlpha(0)

        self.context = contextCreate(cid, wid, nil)
    }

    /// Moves and reshapes the window. Growing a window invalidates the
    /// drawing context (it is bound to the backing store), so the context is
    /// recreated whenever the size changed — same rule as window-sweaters'
    /// `border_move_window`.
    public func resize(to newFrame: CGRect) {
        var shape: CFTypeRef?
        var rect = newFrame
        guard let newRegion = SLS.newRegionWithRect,
              newRegion(&rect, &shape) == 0, let shape else { return }

        let sizeChanged = newFrame.size != frame.size
        if sizeChanged {
            window.freeze()
        }

        let moved = SLS.setWindowShape?(cid, window.id,
                                        Float(newFrame.origin.x),
                                        Float(newFrame.origin.y),
                                        shape) == 0
        if moved {
            frame = newFrame
        }
        if sizeChanged, let contextCreate = SLS.windowContextCreate {
            context = contextCreate(cid, window.id, nil)
            window.thaw()
        }
    }

    /// Pushes drawn pixels to the WindowServer
    /// (`SLSFlushWindowContentRegion`).
    @discardableResult
    public func flush() -> Bool {
        window.flushContentRegion()
    }

    /// Destroys the window (`SLSReleaseWindow`). Also called from deinit.
    public func destroy() {
        window.destroy()
    }

    deinit {
        destroy()
    }
}
