//
//  RecordingFloatingPanelContentView.swift
//  Collect
//
//  Created by Stef Kors on 17/10/2023.
//

import SwiftUI

struct RecordingPanelView: View {
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
    RecordingPanelView()
}
