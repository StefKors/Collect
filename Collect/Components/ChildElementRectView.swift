//
//  ChildElementRectView.swift
//  Collect
//
//  Created by Stef Kors on 17/01/2024.
//

import SwiftUI

struct ChildElementRectView: View {
    init(element: UIElement) {
        let frame: CGRect = (try? element.attribute(.frame)) ?? CGRect(origin: .zero, size: CGSize(width: 100, height: 100))
        self.origin = frame.origin
        self.size = frame.size
    }

    let origin: NSPoint
    let size: CGSize

    var body: some View {
        ElementRectView(origin: origin, size: size, showCollect: true)
    }
}
