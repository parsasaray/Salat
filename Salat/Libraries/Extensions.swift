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
}
