//
//  Extensions.swift
//  Salat
//
//  Created by Parsa Saraydarpour on 1/29/26.
//

import Foundation

extension Date {
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }
}

extension Double {
    var radians: Self { return self * Double.pi / 180 }
    var degrees: Self { return self * 180 / Double.pi }
    
    /// This angle in radians, wrapped into (-π, π]
    var wrappedToHalfTurn: Self {
        let wrapped = self.truncatingRemainder(dividingBy: 2 * .pi)
        if wrapped > .pi { return wrapped - 2 * .pi }
        if wrapped <= -.pi { return wrapped + 2 * .pi }
        return wrapped
    }
    
    /// Rotation for a text label lying along an arrow that points `self` radians clockwise
    /// from up, chosen so the text is never upside down.
    var readableLabelRotation: Self {
        let direction = self.wrappedToHalfTurn
        return direction > 0 ? direction - .pi / 2 : direction + .pi / 2
    }
}
