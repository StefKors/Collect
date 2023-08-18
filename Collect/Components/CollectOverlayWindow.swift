//
//  CollectOverlayWindow.swift
//  Collect
//
//  Created by Stef Kors on 15/08/2023.
//

import SwiftUI
import Cocoa

struct CollectOverlayWindow: View {
    @Environment(\.dismiss) private var dismiss

    @State private var showingPanel: Bool = true
    var body: some View {
        VStack(alignment: .center) {
            Button("dismiss") {
                dismiss()
            }
            .padding(.top)

            Button("Present panel \(showingPanel.description)") {
                showingPanel.toggle()
            }
        }
 
        .fontDesign(.monospaced)
        .frame(width: 200, alignment: .leading)


        // .eventMonitor(.local, for: .mouseMoved) { mouseMoveEvent in
        //     withAnimation(.bouncy) {
        //         self.mouseLocation = NSEvent.mouseLocation
        //     }
        // 
        //     if let trackedWindow = AXUIElement.element(at: mouseLocation.flipped()),
        //        let windowOrigin = trackedWindow.origin,
        //        let windowSize = trackedWindow.size {
        // 
        //         withAnimation(.bouncy) {
        //             self.origin = NSPoint(x: windowOrigin.x, y: windowOrigin.y - size.height)
        //         }
        //         withAnimation(.bouncy) {
        //             self.size = windowSize
        //         }
        //     }
        // 
        //     // WindowManager.shared.fullScreenWindow.makeKeyAndOrderFront(nil);
        //     return mouseMoveEvent
        // }
        // .eventMonitor(.local, for: .mouseMoved) { mouseMoveEvent in
        //     withAnimation(.bouncy) {
        //         self.mouseLocation = NSEvent.mouseLocation
        //     }
        // 
        //     if let trackedWindow = AXUIElement.element(at: mouseLocation.flipped()),
        //        let windowOrigin = trackedWindow.origin,
        //        let windowSize = trackedWindow.size {
        //         withAnimation(.bouncy) {
        //             self.origin = NSPoint(x: windowOrigin.x, y: windowOrigin.y - size.height)
        //         }
        //         withAnimation(.bouncy) {
        //             self.size = windowSize
        //         }
        // 
        //         let frameOrigin = windowOrigin.flipped() //WindowManager.shared.shapeWindowExample.convertPoint(toScreen: origin)
        //                                                  // print(windowOrigin, frameOrigin)
        //                                                  // print(size, windowSize)
        // 
        //         let frame = NSPoint(x: frameOrigin.x, y: frameOrigin.y - size.height)
        //         WindowManager.shared.shapeWindowExample.setFrameOrigin(frame)
        // 
        //         let rect = NSRect(origin: frame, size: windowSize)
        //         // TODO: Fix animation
        // 
        //         WindowManager.shared.shapeWindowExample.setFrame(rect, display: false, animate: false)
        //         // WindowManager.shared.shapeWindowExample.setContentSize(windowSize)
        //     }
        // 
        //     WindowManager.shared.shapeWindowExample.makeKeyAndOrderFront(nil);
        //     return mouseMoveEvent
        // }
    }
}


#Preview {
    CollectOverlayWindow()
}
