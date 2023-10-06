//
//  ContentView.swift
//  Collect
//
//  Created by Stef Kors on 14/07/2023.
//

import SwiftUI
import SwiftData
import ScreenCaptureKit

struct PositionOffset: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(.quaternary, in: Capsule())
    }
}

#Preview {
    Text("Hello, world!")
        .modifier(PositionOffset())
}

extension CGRect {
    init(p1: CGPoint, p2: CGPoint) {
        let left = min(p1.x, p2.x)
        let right = max(p1.x, p2.x)
        let top = min(p1.y, p2.y)
        let bottom = max(p1.y, p2.y)

        let width = right - left;
        let height = bottom - top;

        self.init(x: left, y: top, width: width, height: height)
    }
}

struct DragGestureAreaRecorderView: View {
    @Binding var area: CGRect
    @State private var isDragging = false

    var drag: some Gesture {
        DragGesture()
            .onChanged { val in
                area.origin = val.startLocation
                area = CGRect(p1: val.startLocation, p2: val.location)
                self.isDragging = true
            }
            .onEnded { _ in self.isDragging = false }
    }

    var body: some View {
        Rectangle()
            .subtracting(
                RoundedRectangle(cornerRadius: 6)
                    .size(area.size)
                    .offset(area.origin)
            )
            .fill(.background.opacity(0.7))
            .overlay(content: {
                RoundedRectangle(cornerRadius: 6)
                    .size(area.size)
                    .offset(area.origin)
                    .stroke(Color.accentColor.opacity(0.6), lineWidth: 5)
            })
            .gesture(drag)
    }
}

#Preview {
    DragGestureAreaRecorderView(area: .constant(.preview940))
}

struct FloatingPanelContentView: View {
    @State private var area: CGRect = CGRect(x: 0, y: 0, width: 200, height: 100)

    var body: some View {
        DragGestureAreaRecorderView(area: $area)
            .overlay(alignment: .bottom) {
                RecordingToolBarView(area: $area)
                    .scenePadding()
                    .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 12.0))
                    .shadow(radius: 25, x: 0, y: 6)
                    .padding(.bottom, 100)
            }
    }
}

#Preview {
    FloatingPanelContentView()
}

struct ContentView: View {

    var body: some View {
        ZStack(alignment: .bottom, content: { })
            .floatingPanel(isPresented: .constant(true), content: {
                FloatingPanelContentView()
            })
        //            .floatingPanel(isPresented: .constant(true), content: {
        //                CollectAreaContentView(onCollect: handleCollect)
        //            })
    }

}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
