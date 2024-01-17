//
//  HierarchyRectView.swift
//  Collect
//
//  Created by Stef Kors on 17/01/2024.
//

import SwiftUI

struct HierarchyRectView: View {
    let element: UIElement

    var children: [UIElement] {
        let childs: [AXUIElement] = (try? element.attribute(.children)) ?? []
        return childs.map { el in
            UIElement(el)
        }
    }
    var body: some View {
        ZStack {
            ChildElementRectView(element: element)
            ForEach(children, id: \.inspect) { child in
                HierarchyRectView(element: child)
            }
        }
    }
}
