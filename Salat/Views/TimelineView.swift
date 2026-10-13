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
    
    static let height = DayTimelineLayout.height
    /// From the top of this view to the top of the arc
    static let apexY = DayTimelineLayout.apexY
    /// Where the compass should start, measured from the top of this view
    static let compassTop = DayTimelineLayout.compassTop
    /// How far the disc behind the arc extends past it
    static let underlayMargin: CGFloat = 24
    
    /// Radius of the arc on a timeline `width` points wide
    static func arcRadius(forWidth width: CGFloat) -> CGFloat {
        DayTimelineLayout(width: width).radiusOfArc
    }
    
    private static let sunSize: CGFloat = 20
    
    var desiredDate: Date = Date()
    
    private static let midnightFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("j")
        return formatter
    }()
    
    override func draw(_ rect: CGRect) {
        let width = bounds.width
        guard width > 0 else { return }
        let layout = DayTimelineLayout(width: width)
        
        func arc(from x0: CGFloat, to x1: CGFloat) -> UIBezierPath {
            UIBezierPath(arcCenter: layout.center, radius: layout.radiusOfArc,
                         startAngle: layout.angle(at: x0), endAngle: layout.angle(at: x1),
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
        
        // Both ends of the line are midnight
        let midnight = TimelineView.midnightFormatter.string(from: now.startOfDay) as NSString
        let midnightAttributes: [NSAttributedString.Key: Any] = [
            .font: DayTimelineLayout.midnightFont,
            .foregroundColor: UIColor.ink.withAlphaComponent(0.55)
        ]
        let midnightFrames = layout.midnightFrames(size: midnight.size(withAttributes: midnightAttributes))
        for frame in midnightFrames {
            midnight.draw(at: frame.origin, withAttributes: midnightAttributes)
        }
        
        if let location = LocationDelegate.shared.currentLocation {
            let coord = location.coordinate
            let salatTimes: [String: Date] = SalatTimes().getTimes(date: desiredDate, lat: coord.latitude, lng: coord.longitude)
            // The rings sit on the disc behind the arc
            let background = UIColor(named: "Tertiary Background") ?? .clear
            
            for timeName in ["Dawn", "Sunrise", "Noon", "Afternoon", "Sunset", "Night"] {
                guard let date = salatTimes[timeName] else { continue }
                let interval = date.timeIntervalSince(desiredDate.startOfDay)
                let x = CGFloat(interval / 86400) * width
                guard x >= 0, x <= width else { continue }
                
                let color = UIColor(named: timeName) ?? .ink
                let dotY = layout.y(at: x)
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
        }
        
        // Marks the real current time, but only while looking at today
        if isToday {
            let size = TimelineView.sunSize
            let sun = UIImage(systemName: "sun.max.fill")?.withTintColor(.ink)
            sun?.draw(in: CGRect(x: elapsedX - size / 2, y: layout.y(at: elapsedX) - size / 2, width: size, height: size))
        }
    }
}
