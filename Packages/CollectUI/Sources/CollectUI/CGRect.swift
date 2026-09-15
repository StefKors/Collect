//
//  CGRect.swift
//  Collect
//
//  Created by Stef Kors on 17/10/2023.
//

import Foundation

extension CGRect {
    /// Rect spanning the two points, regardless of drag direction.
    public init(p1: CGPoint, p2: CGPoint) {
        let left = min(p1.x, p2.x)
        let right = max(p1.x, p2.x)
        let top = min(p1.y, p2.y)
        let bottom = max(p1.y, p2.y)

        let width = right - left;
        let height = bottom - top;

        self.init(x: left, y: top, width: width, height: height)
    }
}
