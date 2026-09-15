//
//  CGSize.swift
//  Collect
//
//  Created by Stef Kors on 17/01/2024.
//

import Foundation
import CoreGraphics

extension CGSize: @retroactive Comparable {
    public static func < (lhs: CGSize, rhs: CGSize) -> Bool {
        if(lhs.width >= rhs.width) { return false }
        if(lhs.height >= rhs.height) { return false }
        return true
    }
}
