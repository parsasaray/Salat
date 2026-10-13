//
//  DayTimelineLayout.swift
//  Salat
//
//  Decides where the prayer names go on the day timeline so that no two of them overlap.
//

import UIKit

enum DayTimelineLayout {
    struct Label: Equatable {
        let name: String
        /// Horizontal center, kept inside the timeline's width
        let center: CGFloat
        /// 0 sits closest to the line, every further row is one step further out
        let row: Int
    }

    static let font = UIFont.systemFont(ofSize: 12, weight: .semibold)

    /// Puts each name in the lowest row where it clears every name already in that row.
    /// Returns nil when that would take more than `maxRows` rows.
    static func labels(for marks: [(name: String, x: CGFloat)],
                       width: CGFloat,
                       spacing: CGFloat = 6,
                       maxRows: Int = 2) -> [Label]? {
        var placed = [(label: Label, halfWidth: CGFloat)]()
        for mark in marks.sorted(by: { $0.x < $1.x }) {
            let half = (mark.name as NSString).size(withAttributes: [.font: font]).width / 2
            let center = min(max(mark.x, half), max(width - half, half))
            let row = (0..<maxRows).first { row in
                placed.allSatisfy { other in
                    other.label.row != row
                        || abs(other.label.center - center) >= other.halfWidth + half + spacing
                }
            }
            guard let row = row else { return nil }
            placed.append((Label(name: mark.name, center: center, row: row), half))
        }
        return placed.map { $0.label }
    }
}
