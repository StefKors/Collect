import SwiftUI

// ???? https://gist.github.com/samalone/e7663899e2f65f99e607fe5f0bb5f0aa
// Still buggy
struct LocalEventMonitor: ViewModifier {
    var mask: NSEvent.EventTypeMask
    var handler: (NSEvent) -> NSEvent?

    @State var monitor: Any?

    func body(content: Content) -> some View {
        content.overlay(EmptyView()
            .onAppear {
                guard monitor == nil else { return }
                monitor = NSEvent.addLocalMonitorForEvents(matching: mask, handler: handler)
            }
            .onDisappear {
                if let monitor {
                    NSEvent.removeMonitor(monitor)
                }
            }
        )
    }
}

struct GlobalEventMonitor: ViewModifier {
    var mask: NSEvent.EventTypeMask
    var handler: (NSEvent) -> Void

    @State var monitor: Any?

    func body(content: Content) -> some View {
        content.overlay(EmptyView()
            .onAppear {
                guard monitor == nil else { return }
                monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
            }
            .onDisappear {
                if let monitor {
                    NSEvent.removeMonitor(monitor)
                }
            }
        )
    }
}

struct UniversalEventMonitor: ViewModifier {
    var mask: NSEvent.EventTypeMask
    var handler: (NSEvent) -> Void

    @State var monitor: Any?

    func body(content: Content) -> some View {
        content
            .localEventMonitor(for: mask, handler: handleEvent)
            .globalEventMonitor(for: mask, handler: handleEvent)
    }

    func handleEvent(_ event: NSEvent) -> NSEvent? {
        handler(event)
        return event
    }

    func handleEvent(_ event: NSEvent) {
        handler(event)
    }
}

extension View {
    func localEventMonitor(for mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> NSEvent?) -> some View {
        modifier(LocalEventMonitor(mask: mask, handler: handler))
    }

    func globalEventMonitor(for mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> Void) -> some View {
        modifier(GlobalEventMonitor(mask: mask, handler: handler))
    }

    func universalEventMonitor(for mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> Void) -> some View {
        modifier(UniversalEventMonitor(mask: mask, handler: handler))
    }
}
