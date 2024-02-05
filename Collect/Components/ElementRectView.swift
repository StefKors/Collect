//
//  ElementRectView.swift
//  Collect
//
//  Created by Stef Kors on 17/01/2024.
//

import SwiftUI

struct ElementRectView: View {
    var label: String? = nil
    let origin: NSPoint
    let size: CGSize
    let showCollect: Bool

    private let radius: CGFloat = 8

    var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: label != nil ? 0 : radius,
            bottomLeadingRadius: radius,
            bottomTrailingRadius: radius,
            topTrailingRadius: radius,
            style: .continuous
        )
    }

    var body: some View {
        shape
            .strokeBorder(Color.accentColor, lineWidth: 2)
            .background(
                shape
                    .foregroundColor(Color.accentColor.opacity(0.3))
                    .overlay(alignment: .topLeading) {
                        if let label {
                            Text(label.capitalized)
                                .bold()
                                .padding(.horizontal, 10)
                                .padding(.top, 4)
                                .padding(.bottom, 6)
                                .foregroundStyle(Color(nsColor: .windowBackgroundColor))
                                .background(
                                    UnevenRoundedRectangle(
                                        topLeadingRadius: radius,
                                        bottomLeadingRadius: 0,
                                        bottomTrailingRadius: 0,
                                        topTrailingRadius: radius,
                                        style: .continuous
                                    )
                                    .foregroundColor(Color.accentColor)
                                )
                                .offset(x: 0, y: -25.0)
                        }
                    }
            )
            .frame(width: size.width, height: size.height)
            .position(origin)
            .offset(x: size.width/2, y: size.height/2)
            .opacity(showCollect ? 1 : 0)

    }
}

#Preview {
    ZStack {
        ElementRectView(origin: .init(x: 20, y: 20), size: CGSize(width: 200, height: 80), showCollect: true)

        ElementRectView(label: "group", origin: .init(x: 300, y: 160), size: CGSize(width: 200, height: 80), showCollect: true)
    }
}
