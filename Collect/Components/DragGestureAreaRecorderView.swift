//
//  DragGestureAreaRecorderView.swift
//  Collect
//
//  Created by Stef Kors on 17/10/2023.
//

import SwiftUI

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
