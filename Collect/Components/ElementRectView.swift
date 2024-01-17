//
//  ElementRectView.swift
//  Collect
//
//  Created by Stef Kors on 17/01/2024.
//

import SwiftUI

struct ElementRectView: View {
    let origin: NSPoint
    let size: CGSize
    let showCollect: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 2)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .foregroundColor(Color.accentColor.opacity(0.3))
            )
            .frame(width: size.width, height: size.height)
            .position(origin)
            .offset(x: size.width/2, y: size.height/2)
            .opacity(showCollect ? 1 : 0)
    }
}

#Preview {
    ElementRectView(origin: .zero, size: CGSize(width: 200, height: 80), showCollect: true)
}
