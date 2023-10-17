//
//  PositionOffset.swift
//  Collect
//
//  Created by Stef Kors on 17/10/2023.
//

import SwiftUI

// Unused?
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
