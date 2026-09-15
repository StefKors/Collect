//
//  Spaces.swift
//  SkyLight
//
//  Space and display queries. Spaces ("desktops") are per-display; window
//  visibility checks need to ask every managed display for its current
//  space, which is what `isSpaceVisible` does — same logic as
//  window-sweaters' `is_space_visible`.
//

import CoreGraphics
import Foundation

extension SkyLight {

    /// UUID strings of all managed (non-mirrored) displays
    /// (`SLSCopyManagedDisplays`).
    public static func managedDisplayUUIDs() -> [String] {
        guard let fn = SLS.copyManagedDisplays,
              let displays = fn(mainConnectionID)?.takeRetainedValue() as? [String]
        else { return [] }
        return displays
    }

    /// The space currently active on a managed display
    /// (`SLSManagedDisplayGetCurrentSpace`). 0 on failure.
    public static func currentSpace(onDisplay uuid: String) -> UInt64 {
        guard let fn = SLS.managedDisplayGetCurrentSpace else { return 0 }
        return fn(mainConnectionID, uuid as CFString)
    }

    /// The space active on every managed display — the set of spaces that is
    /// actually on screen right now.
    public static func visibleSpaces() -> Set<UInt64> {
        Set(managedDisplayUUIDs().map(currentSpace(onDisplay:)).filter { $0 != 0 })
    }

    /// True when `spaceID` is the active space of some managed display.
    /// Mirrors window-sweaters' `is_space_visible`.
    public static func isSpaceVisible(_ spaceID: UInt64) -> Bool {
        spaceID != 0 && visibleSpaces().contains(spaceID)
    }

    /// UUID of the display whose menu bar is active — the focused display in
    /// multi-monitor setups (`SLSCopyActiveMenuBarDisplayIdentifier`).
    public static var activeMenuBarDisplayUUID: String? {
        SLS.copyActiveMenuBarDisplayIdentifier?(mainConnectionID)?
            .takeRetainedValue() as String?
    }

    /// The "active" space across the whole session: with a single display it
    /// is that display's current space; with several, the space on the
    /// display owning the active menu bar. Same rule as window-sweaters'
    /// `get_active_space_id` (which additionally consults
    /// `CGGetActiveDisplayList` / `CGDisplayCreateUUIDFromDisplayID` — we
    /// keep the simpler SLS path since it is correct whenever a menu bar is
    /// shown).
    public static var activeSpace: UInt64 {
        if let uuid = activeMenuBarDisplayUUID {
            return currentSpace(onDisplay: uuid)
        }
        return managedDisplayUUIDs().first.map(currentSpace(onDisplay:)) ?? 0
    }
}
