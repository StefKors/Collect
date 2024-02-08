//
//  ElementRectView.swift
//  Collect
//
//  Created by Stef Kors on 17/01/2024.
//

import SwiftUI

struct ElementRectView: View {
    var label: String? = nil
    var level: Int = 0
    let origin: NSPoint
    let size: CGSize
    let showCollect: Bool

    private let radius: CGFloat = 8

    private var roundLeadingCorner: Bool {
        (level != 0) || (label == nil)
    }

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: roundLeadingCorner ? radius : 0,
            bottomLeadingRadius: radius,
            bottomTrailingRadius: radius,
            topTrailingRadius: radius,
            style: .continuous
        )
    }

    private let levelColor: Color = Color.accentColor
//    {
//        if level < colours.count {
//            return colours[level]
//        }
//
//        return Color.accentColor
//    }

    var body: some View {
        shape
            .strokeBorder(levelColor, lineWidth: 2)
            .background(
                shape
                    .foregroundColor(levelColor.opacity(0.3))
                    .overlay(alignment: .topLeading) {
                        if let label {
                            Text(label.capitalized)
                                .bold()
                                .padding(.horizontal, 10)
                                .padding(.top, 4)
                                .padding(.bottom, 6)
                                .foregroundStyle(Color(nsColor: .textBackgroundColor))
                                .background(
                                    UnevenRoundedRectangle(
                                        topLeadingRadius: radius,
                                        bottomLeadingRadius: 0,
                                        bottomTrailingRadius: 0,
                                        topTrailingRadius: radius,
                                        style: .continuous
                                    )
                                    .foregroundColor(levelColor)
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

//    var colours: [Color] = [
//        Color.accentColor,
//        Color(red: 0.921569, green: 0.815686, blue: 0.976471),
//        Color(red: 0.470588, green: 0.447059, blue: 0.968628),
//        Color(red: 0.745098, green: 0.901961, blue: 0.356863),
//        Color(red: 0.196078, green: 0.427451, blue: 0.341176),
//        Color(red: 0.917647, green: 0.329412, blue: 0.388235),
//        Color(red: 0.854902, green: 0.415686, blue: 0.247059),
//    ]
}

#Preview {
    ZStack {
        ElementRectView(origin: .init(x: 20, y: 20), size: CGSize(width: 200, height: 80), showCollect: true)

        ElementRectView(label: "group", level: 0, origin: .init(x: 300, y: 160), size: CGSize(width: 200, height: 80), showCollect: true)
        ElementRectView(label: "text", level: 1, origin: .init(x: 300, y: 160), size: CGSize(width: 200, height: 80), showCollect: true)
        ElementRectView(label: "text", level: 2, origin: .init(x: 300, y: 160), size: CGSize(width: 200, height: 80), showCollect: true)
        ElementRectView(label: "text", level: 3, origin: .init(x: 300, y: 160), size: CGSize(width: 200, height: 80), showCollect: true)
    }

}
