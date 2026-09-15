import Cocoa
import Foundation
import os

/// `_AXUIElementGetWindow` — private HIServices function that maps an
/// AXUIElement to the CGWindowID of its backing WindowServer window. This is
/// the same call tools like yabai and window-sweaters use to bridge the AX
/// world and the CGWindowList/SkyLight world.
///
/// Private API: resolved via dlsym at first use and treated as optional.
/// When it is absent, `containingWindowID` is nil and callers should fall
/// back to other window-tracking approaches.
private typealias AXUIElementGetWindow =
    @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AXSwift",
                            category: "WindowID")

private let axUIElementGetWindow: AXUIElementGetWindow? = {
    let handle = dlopen(
        "/System/Library/Frameworks/ApplicationServices.framework/Frameworks/HIServices.framework/HIServices",
        RTLD_LAZY
    )
    guard let handle, let pointer = dlsym(handle, "_AXUIElementGetWindow") else {
        logger.warning("_AXUIElementGetWindow not found — containingWindowID will always be nil")
        return nil
    }
    return unsafeBitCast(pointer, to: AXUIElementGetWindow.self)
}()

extension UIElement {

    /// Whether `_AXUIElementGetWindow` could be resolved on this system.
    public static var windowIDLookupIsAvailable: Bool {
        axUIElementGetWindow != nil
    }

    /// The CGWindowID of the window containing this element.
    ///
    /// Resolves the element itself first, then walks up through `AXWindow`
    /// and `AXTopLevelUIElement` — the same fallback chain window-sweaters
    /// relies on for elements that are not themselves windows.
    ///
    /// The result can be fed to `CGWindowList`, `SCWindow`, or SkyLight
    /// window APIs, all of which use the same window id space.
    public var containingWindowID: CGWindowID? {
        if let windowID = rawWindowID(of: element) { return windowID }
        if let window: UIElement = try? attribute(.window),
           let windowID = rawWindowID(of: window.element) { return windowID }
        if let topLevel: UIElement = try? attribute(.topLevelUIElement),
           let windowID = rawWindowID(of: topLevel.element) { return windowID }
        logger.debug("containingWindowID: no window id resolved for \(String(describing: self.element))")
        return nil
    }

    private func rawWindowID(of element: AXUIElement) -> CGWindowID? {
        var windowID = CGWindowID(0)
        guard let axUIElementGetWindow else { return nil }
        let error = axUIElementGetWindow(element, &windowID)
        guard error == .success, windowID != 0 else {
            logger.debug("_AXUIElementGetWindow failed: \(error), wid=\(windowID)")
            return nil
        }
        return windowID
    }
}
