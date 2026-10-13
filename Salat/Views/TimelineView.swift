//
//  TimelineView.swift
//  Salat
//
//  Created by Parsa Saraydarpour on 7/20/22.
//

import UIKit

/// The day as a shallow arc over the Qibla arrow: midnight on the left, midnight on the right,
/// a dot per prayer, solid line for what has passed and dots for what is still to come.
class TimelineView: UIView {

    /// Distance from the top of the view to the top of the arc, leaving room for the names above it
    static let apexY: CGFloat = 50
    static let height: CGFloat = 118
    /// Where the compass should start, measured from the top of this view: just under the arc's peak
    static let compassTop: CGFloat = apexY + 8

    private static let dotRadius: CGFloat = 6
    private static let sunSize: CGFloat = 20
    private static let nameRowOffset: CGFloat = 21
    private static let nameRowStep: CGFloat = 16

    var desiredDate: Date = Date()

    private static let midnightFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("j")
        return formatter
    }()

    override func draw(_ rect: CGRect) {
        let width = bounds.width
        guard width > 0 else { return }
        let sagitta = min(width * 0.13, 40)
        let radius = (width * width / 4 + sagitta * sagitta) / (2 * sagitta)
        let centerX = width / 2
        let centerY = TimelineView.apexY + radius

        func y(at x: CGFloat) -> CGFloat {
            let dx = x - centerX
            return centerY - sqrt(max(radius * radius - dx * dx, 0))
        }
        func arc(from x0: CGFloat, to x1: CGFloat) -> UIBezierPath {
            UIBezierPath(arcCenter: CGPoint(x: centerX, y: centerY), radius: radius,
                         startAngle: atan2(y(at: x0) - centerY, x0 - centerX),
                         endAngle: atan2(y(at: x1) - centerY, x1 - centerX),
                         clockwise: true)
        }

        let now = Date()
        let isToday = desiredDate.startOfDay == now.startOfDay
        let elapsed: Double
        if isToday {
            elapsed = now.timeIntervalSince(now.startOfDay) / 86400
        } else {
            elapsed = desiredDate.startOfDay < now.startOfDay ? 1 : 0
        }
        let elapsedX = CGFloat(elapsed) * width

        // Solid up to now, dotted after
        if elapsedX > 0 {
            let passed = arc(from: 0, to: elapsedX)
            passed.lineWidth = 2
            passed.lineCapStyle = .round
            UIColor.ink.setStroke()
            passed.stroke()
        }
        if elapsedX < width {
            let ahead = arc(from: elapsedX, to: width)
            ahead.lineWidth = 2
            ahead.lineCapStyle = .round
            ahead.setLineDash([0.1, 6], count: 2, phase: 0)
            UIColor.ink.withAlphaComponent(0.4).setStroke()
            ahead.stroke()
        }

        if let location = LocationDelegate.shared.currentLocation {
            let coord = location.coordinate
            let salatTimes: [String: Date] = SalatTimes().getTimes(date: desiredDate, lat: coord.latitude, lng: coord.longitude)
            let background = UIColor(named: "Background") ?? .clear

            var marks = [(name: String, x: CGFloat)]()
            for timeName in ["Dawn", "Sunrise", "Noon", "Afternoon", "Sunset", "Night"] {
                guard let date = salatTimes[timeName] else { continue }
                let interval = date.timeIntervalSince(desiredDate.startOfDay)
                let x = CGFloat(interval / 86400) * width
                guard x >= 0, x <= width else { continue }
                marks.append((timeName, x))

                let color = UIColor(named: timeName) ?? .ink
                let dotY = y(at: x)
                if x <= elapsedX {
                    let dot = UIBezierPath(ovalIn: CGRect(x: x - 6, y: dotY - 6, width: 12, height: 12))
                    color.setFill()
                    dot.fill()
                } else {
                    // Still to come: an empty ring
                    let ring = UIBezierPath(ovalIn: CGRect(x: x - 5, y: dotY - 5, width: 10, height: 10))
                    background.setFill()
                    ring.fill()
                    ring.lineWidth = 2
                    color.setStroke()
                    ring.stroke()
                }
            }

            // Names above the arc, staggered into a second row where neighbors would collide.
            // If even that cannot keep them apart the dots stand alone.
            if let labels = DayTimelineLayout.labels(for: marks, width: width) {
                let xByName = Dictionary(uniqueKeysWithValues: marks.map { ($0.name, $0.x) })
                for label in labels {
                    guard let x = xByName[label.name] else { continue }
                    let text = label.name as NSString
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: DayTimelineLayout.font,
                        .foregroundColor: UIColor(named: label.name) ?? UIColor.ink
                    ]
                    let size = text.size(withAttributes: attributes)
                    let offset = TimelineView.nameRowOffset + CGFloat(label.row) * TimelineView.nameRowStep
                    text.draw(at: CGPoint(x: label.center - size.width / 2,
                                          y: y(at: x) - offset - size.height / 2),
                              withAttributes: attributes)
                }
            }
        }

        // Both ends of the line are midnight
        let midnight = TimelineView.midnightFormatter.string(from: now.startOfDay) as NSString
        let endAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.ink.withAlphaComponent(0.55)
        ]
        let endSize = midnight.size(withAttributes: endAttributes)
        let endY = y(at: 0) + 12
        midnight.draw(at: CGPoint(x: 0, y: endY), withAttributes: endAttributes)
        midnight.draw(at: CGPoint(x: width - endSize.width, y: endY), withAttributes: endAttributes)

        // Marks the real current time, but only while looking at today
        if isToday {
            let sunX = elapsedX
            let size = TimelineView.sunSize
            let sun = UIImage(systemName: "sun.max.fill")?.withTintColor(.ink)
            sun?.draw(in: CGRect(x: sunX - size / 2, y: y(at: sunX) - size / 2, width: size, height: size))
        }
    }
}
