//
//  RecordingView.swift
//  Collect
//
//  Created by Stef Kors on 14/07/2023.
//

import SwiftUI
import SwiftData
import ScreenCaptureKit

struct RecordingContentView: View {

    var body: some View {
        ZStack(alignment: .bottom, content: { })
            .floatingPanel(isPresented: .constant(true), content: {
                RecordingPanelView()
            })
        //            .floatingPanel(isPresented: .constant(true), content: {
        //                CollectAreaContentView(onCollect: handleCollect)
        //            })
    }

}

#Preview {
    RecordingContentView()
        .modelContainer(for: LinkItem.self, inMemory: true)
}
