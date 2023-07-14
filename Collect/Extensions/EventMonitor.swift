import SwiftUI

struct EventMonitor: ViewModifier {
    enum Scope {
        case local
        case global
    }
    
    // FIXME: View does not react to changes in these properties!
    var scope: Scope
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

extension View {
    func eventMonitor(_ scope: EventMonitor.Scope = .local, for mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> NSEvent?) -> some View {
        modifier(EventMonitor(scope: scope, mask: mask, handler: handler))
    }
}
