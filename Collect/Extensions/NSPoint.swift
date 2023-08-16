//
//  NSPoint.swift
//  Collect
//
//  Created by Stef Kors on 15/08/2023.
//

import Foundation
import Cocoa

extension NSPoint {
    func flipped() -> NSPoint {
        if let screen = NSScreen.screens.first {
            return NSPoint(
                x: x,
                y: screen.frame.height - self.y
            )
        } else {
            return self
        }
    }

    func flippedOther() -> NSPoint {
        if let screen = NSScreen.screens.first {
            return NSPoint(
                x: x,
                y: screen.frame.height - self.y
            )
        } else {
            return self
        }
    }
}
