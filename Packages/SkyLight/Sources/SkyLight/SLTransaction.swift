//
//  SLTransaction.swift
//  SkyLight
//
//  `SLSTransaction*` batches WindowServer window operations — move, order,
//  level, alpha, shape — and applies them in a single commit. window-sweaters
//  repositions a border by committing `MoveWindowWithGroup` +
//  `OrderWindow` + `SetWindowShape` together so the overlay never appears
//  at a half-updated position.
//

import CoreGraphics
import Foundation

/// A batch of WindowServer window operations applied atomically by
/// ``commit()``. Create, queue operations, commit once.
///
/// The underlying `SLSTransaction` is a CFTypeRef; this class retains it for
/// its lifetime and releases on deinit.
public final class SLTransaction {
    private let transaction: AnyObject
    private let cid: Int32
    private var committed = false

    /// Creates a transaction on `connection` (`SLSTransactionCreate`).
    /// nil if the symbol is missing or the server refused.
    public init?(on cid: Int32 = SkyLight.mainConnectionID) {
        guard let create = SLS.transactionCreate,
              let transaction = create(cid)?.takeRetainedValue()
        else { return nil }
        self.transaction = transaction
        self.cid = cid
    }

    /// Moves `window` to `origin` (top-left global screen coordinates) along
    /// with its whole "movement group" — overlays ordered relative to it
    /// travel together (`SLSTransactionMoveWindowWithGroup`). This is the
    /// call window-sweaters uses to keep borders glued to their windows.
    @discardableResult
    public func moveWindowWithGroup(_ window: SLWindow, to origin: CGPoint) -> Bool {
        SLS.transactionMoveWindowWithGroup?(transaction, window.id, origin) == 0
    }

    /// Z-ordering within the transaction (`SLSTransactionOrderWindow`).
    /// `order` is 1 (above) or -1 (below) `relativeTo` — pass 0 to order
    /// absolutely.
    @discardableResult
    public func orderWindow(_ window: SLWindow, order: Int32,
                            relativeTo other: SLWindow) -> Bool {
        SLS.transactionOrderWindow?(transaction, window.id, order, other.id) == 0
    }

    /// Sets the window level (`SLSTransactionSetWindowLevel`,
    /// NSWindow.Level scale).
    @discardableResult
    public func setWindowLevel(_ window: SLWindow, level: Int32) -> Bool {
        SLS.transactionSetWindowLevel?(transaction, window.id, level) == 0
    }

    /// Sets the sub-level within a level (`SLSTransactionSetWindowSubLevel`).
    @discardableResult
    public func setWindowSubLevel(_ window: SLWindow, level: Int32) -> Bool {
        SLS.transactionSetWindowSubLevel?(transaction, window.id, level) == 0
    }

    /// Moves/reshapes the window (`SLSTransactionSetWindowShape`). Pass a
    /// `CGSNewRegionWithRect` region as `shape`, or nil to move only.
    @discardableResult
    public func setWindowShape(_ window: SLWindow, x: Float, y: Float,
                               shape: CFTypeRef?) -> Bool {
        SLS.transactionSetWindowShape?(transaction, window.id, x, y, shape) == 0
    }

    /// Sets the window alpha (`SLSTransactionSetWindowAlpha`).
    @discardableResult
    public func setWindowAlpha(_ window: SLWindow, alpha: Float) -> Bool {
        SLS.transactionSetWindowAlpha?(transaction, window.id, alpha) == 0
    }

    /// Sets the window transform (`SLSTransactionSetWindowTransform`). The
    /// two flag ints are undocumented; 0, 0 is what window-sweaters passes.
    @discardableResult
    public func setWindowTransform(_ window: SLWindow,
                                   _ transform: CGAffineTransform) -> Bool {
        SLS.transactionSetWindowTransform?(transaction, window.id, 0, 0, transform) == 0
    }

    /// Applies every queued operation in one WindowServer commit
    /// (`SLSTransactionCommit`). `synchronously: true` blocks until the
    /// server has applied the batch — window-sweaters commits border moves
    /// synchronously so the next event sees settled state.
    @discardableResult
    public func commit(synchronously: Bool = false) -> Bool {
        guard !committed else { return false }
        committed = true
        return SLS.transactionCommit?(transaction, synchronously ? 1 : 0) == 0
    }
}
