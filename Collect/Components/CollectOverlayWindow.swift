//
//  CollectOverlayWindow.swift
//  Collect
//
//  Created by Stef Kors on 15/08/2023.
//

import SwiftUI

struct CollectOverlayWindow: View {
    @State private var mouseLocation: NSPoint = .zero
    @State private var origin: NSPoint = .zero
    @State private var size: CGSize = .zero
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .center) {
            Grid {
                GridRow {
                    Text("x: ")
                    Text(Int(mouseLocation.x).description)
                }

                GridRow {
                    Text("y: ")
                    Text(Int(mouseLocation.y).description)
                }

                Divider()

                GridRow {
                    Text("x: ")
                    Text(Int(origin.x).description)
                }

                GridRow {
                    Text("y: ")
                    Text(Int(origin.y).description)
                }

                Divider()

                GridRow {
                    Text("width: ")
                    Text(Int(size.width).description)
                }

                GridRow {
                    Text("height: ")
                    Text(Int(size.height).description)
                }
            }

            Button("dismiss") {
                // WindowManager.shared.shapeWindowExample.setFrame(.zero, display: false, animate: false)
                WindowManager.shared.shapeWindowExample.orderOut(WindowManager.shared.shapeWindowExample)
                dismiss()
            }
            .padding(.top)
        }
        .fontDesign(.monospaced)
        .frame(width: 200, alignment: .leading)
        .eventMonitor(.local, for: .mouseMoved) { mouseMoveEvent in
            self.mouseLocation = NSEvent.mouseLocation

            if let trackedWindow = AXUIElement.element(at: mouseLocation.flipped()),
               let windowOrigin = trackedWindow.origin,
               let windowSize = trackedWindow.size {
                self.origin = NSPoint(x: windowOrigin.x, y: windowOrigin.y - size.height)
                self.size = windowSize

                let frameOrigin = windowOrigin.flipped() //WindowManager.shared.shapeWindowExample.convertPoint(toScreen: origin)
                                                         // print(windowOrigin, frameOrigin)
                                                         // print(size, windowSize)

                let frame = NSPoint(x: frameOrigin.x, y: frameOrigin.y - size.height)
                WindowManager.shared.shapeWindowExample.setFrameOrigin(frame)

                let rect = NSRect(origin: frame, size: windowSize)
                // TODO: Fix animation
                WindowManager.shared.shapeWindowExample.setFrame(rect, display: false, animate: false)
                // WindowManager.shared.shapeWindowExample.setContentSize(windowSize)
            }

            WindowManager.shared.shapeWindowExample.makeKeyAndOrderFront(nil);
            return mouseMoveEvent
        }
    }
}

#Preview {
    CollectOverlayWindow()
}
