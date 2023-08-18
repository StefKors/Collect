//
//  SystemWideElement.swift
//  Collect
//
//  Created by Stef Kors on 18/08/2023.
//

import Foundation
import AXSwift

extension SystemWideElement {
    func getAtPoint(_ point: NSPoint) -> UIElement? {
        return try? self.elementAtPosition(Float(point.x), Float(point.y))
    }
}
