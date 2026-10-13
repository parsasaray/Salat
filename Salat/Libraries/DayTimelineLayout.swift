//
//  DayTimelineLayout.swift
//  Salat
//
//  The day timeline's geometry: the arc over the compass and where its midnight labels go.
//

import UIKit

struct DayTimelineLayout {
    static let midnightFont = UIFont.systemFont(ofSize: 11)

    /// From the top of the timeline to the top of the arc
    static let apexY: CGFloat = 50
    static let height: CGFloat = 118
    /// Where the compass starts, measured from the top of the timeline: just under the arc's peak
    static let compassTop: CGFloat = apexY + 8

    let width: CGFloat
    private let radius: CGFloat

    init(width: CGFloat) {
        self.width = width
        let sagitta = min(width * 0.13, 40)
        radius = sagitta > 0 ? (width * width / 4 + sagitta * sagitta) / (2 * sagitta) : 0
    }

    // MARK: - Arc

    var center: CGPoint { CGPoint(x: width / 2, y: DayTimelineLayout.apexY + radius) }

    /// Height of the arc over `x`
    func y(at x: CGFloat) -> CGFloat {
        let dx = x - width / 2
        return center.y - sqrt(max(radius * radius - dx * dx, 0))
    }

    /// Angle of the point of the arc over `x`, for drawing it
    func angle(at x: CGFloat) -> CGFloat {
        atan2(y(at: x) - center.y, x - center.x)
    }

    var radiusOfArc: CGFloat { radius }

    // MARK: - Midnight labels

    /// Where "12 AM" goes at each end of the arc
    func midnightFrames(size: CGSize) -> [CGRect] {
        [CGRect(x: 0, y: y(at: 0) + 12, width: size.width, height: size.height),
         CGRect(x: width - size.width, y: y(at: width) + 12, width: size.width, height: size.height)]
    }
}
