//
//  HierarchyRectView.swift
//  Collect
//
//  Created by Stef Kors on 17/01/2024.
//

import SwiftUI
import AXSwift

/// Recursively renders a collect rect for `element` and all of its
/// `AXChildren`. Internal to the package — the public entry point is
/// `CollectAreaView`.
struct HierarchyRectView: View {
    let element: UIElement
    var level: Int

    private var children: [UIElement] {
        let childs: [AXUIElement] = (try? element.attribute(.children)) ?? []
        return childs.map { el in
            UIElement(el)
        }
    }

    private var childrenLevel: Int {
        level + 1
    }

    var body: some View {
        ZStack {
            ChildElementRectView(element: element, level: level)
            ForEach(children, id: \.inspect) { child in
                HierarchyRectView(element: child, level: childrenLevel)
            }
        }
    }
}
