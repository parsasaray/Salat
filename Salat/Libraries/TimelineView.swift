//
//  TimelineView.swift
//  Salat
//
//  Created by Parsa Saraydarpour on 7/20/22.
//

import UIKit

class TimelineView: UIView {
    override func draw(_ rect: CGRect) {
        let line = UIBezierPath()
        line.move(to: CGPoint(x: 0, y: self.frame.height/2))
        line.addLine(to: CGPoint(x: self.frame.width, y: self.frame.height/2))
        line.lineWidth = 2
        UIColor.label.set()
        line.stroke()
        
        let salatTimes: [String: Date] = SalatTimes().getTimes(date: desiredDate, lat: desiredLocation.latitude, lng: desiredLocation.longitude)
        for timeName in ["Dawn", "Sunrise", "Noon", "Afternoon", "Sunset", "Night"] {
            guard let date = salatTimes[timeName] else { return }
            let interval = date.timeIntervalSince(desiredDate.startOfDay)
            let intervalRatio = (interval/86400) * self.bounds.width
            
            let timeCircle = UIBezierPath(ovalIn: CGRect(x: intervalRatio - 6, y: self.frame.height/2 - 6, width: 12, height: 12))
            UIColor(named: timeName)?.setFill()
            timeCircle.fill()
        }
        
        if desiredDate.startOfDay == Date().startOfDay {
            let interval = desiredDate.timeIntervalSince(desiredDate.startOfDay)
            let intervalRatio = (interval/86400) * self.bounds.width
            
            let currentTimeMarker = UIImage(systemName: "sun.max.fill")?.withTintColor(.label)
            currentTimeMarker?.draw(in: CGRect(x: intervalRatio - 10, y: self.frame.height/2 - 10, width: 20, height: 20))
        }
    }
}

extension Date {
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }
}
