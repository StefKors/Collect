//
//  FloatingPanel.swift
//  Collect
//
//  Created by Stef Kors on 18/08/2023.
//

import SwiftUI

class FullScreenWindowController<Content: View>: NSWindowController {
    init(view: () -> Content,
         contentRect: NSRect,
         isPresented: Binding<Bool>,
         ignoresMouseEvents: Binding<Bool>) {
        super.init(window: FloatingPanel(view: view, contentRect: contentRect, isPresented: isPresented, ignoresMouseEvents: ignoresMouseEvents))
        // Remove the window header
        window?.styleMask = .borderless
        /// Enable drawing/positioning on top of the menubar
        /// and dock regions.
        window?.level = .mainMenu + 1
        window?.setFrame(window!.screen!.frame, display: true)
        window?.makeKeyAndOrderFront(self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// An NSPanel subclass that implements floating panel traits.
class FloatingPanel<Content: View>: NSWindow {
    @Binding var isPresented: Bool

    init(view: () -> Content,
         contentRect: NSRect,
         backing: NSWindow.BackingStoreType = .buffered,
         defer flag: Bool = true,
         isPresented: Binding<Bool>,
         ignoresMouseEvents: Binding<Bool>) {
        /// Initialize the binding variable by assigning the whole value via an underscore
        self._isPresented = isPresented

        /// Init the window as usual
        super.init(
            contentRect: contentRect,
            styleMask: [
                .borderless
            ],
            backing: backing,
            defer: flag
        )
        self.isOpaque = false;
        self.ignoresMouseEvents = ignoresMouseEvents.wrappedValue
        self.hasShadow = false;
        self.backgroundColor = .clear;

        /// Set the content view.
        /// The safe area is ignored because the title bar still interferes with the geometry
        contentView = NSHostingView(rootView: view()
            .ignoresSafeArea(.all)
            .environment(\.floatingPanel, self))
    }
}

extension View {
    /** Present a ``FloatingPanel`` in SwiftUI fashion
     - Parameter isPresented: A boolean binding that keeps track of the panel's presentation state
     - Parameter content: The displayed content
     **/
    func floatingPanel<Content: View>(isPresented: Binding<Bool>,
                                      ignoresMouseEvents: Binding<Bool>,
                                      // collectRect: Binding<CGRect>,
                                      @ViewBuilder content: @escaping () -> Content) -> some View {
        self.modifier(FloatingPanelModifier(isPresented: isPresented, ignoresMouseEvents: ignoresMouseEvents, view: content))
    }
}

private struct FloatingPanelKey: EnvironmentKey {
    static let defaultValue: NSWindow? = nil
}

extension EnvironmentValues {
    var floatingPanel: NSWindow? {
        get { self[FloatingPanelKey.self] }
        set { self[FloatingPanelKey.self] = newValue }
    }
}


/// Add a  ``FloatingPanel`` to a view hierarchy
fileprivate struct FloatingPanelModifier<PanelContent: View>: ViewModifier {
    /// Determines wheter the panel should be presented or not
    @Binding var isPresented: Bool

    /// Determines wheter the panel ignores mouse events or not
    @Binding var ignoresMouseEvents: Bool

    /// Holds the panel content's view closure
    @ViewBuilder let view: () -> PanelContent

    /// Stores the panel instance with the same generic type as the view closure
    @State var panel: FullScreenWindowController<PanelContent>?

    func body(content: Content) -> some View {
        content
            .task {
                /// TODO: this might create multiple windows when parent view re-renders, figure out a way to dedupe
                let screenFrame = NSScreen.main?.frame ?? .zero
                panel = FullScreenWindowController(view: view, contentRect: screenFrame, isPresented: $isPresented, ignoresMouseEvents: $ignoresMouseEvents)
            }.onDisappear {
                /// When the view disappears, close and kill the panel
                panel?.close()
                panel = nil
            }
            .onChange(of: isPresented, initial: false) { (oldValue, newValue) in
                /// On change of the presentation state, make the panel react accordingly
//                if newValue == false {
//                    panel?.close()
//                }
            }
    }
}

