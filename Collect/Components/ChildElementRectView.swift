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

        self.label = try? element.attribute(.roleDescription) ?? nil
    }

    let origin: NSPoint
    let size: CGSize
    let label: String?

    var body: some View {
        ElementRectView(label: label, origin: origin, size: size, showCollect: true)
    }
}
