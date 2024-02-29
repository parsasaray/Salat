//
//  SalatTimes.swift
//  Salat
//
//  Created by Vladimir Agafonkin
//  Ported by Cristian Gonzales
//  Modified by Parsa Saraydarpour
//

import Foundation

var salatTimes = [String: Date]()

public class SalatTimes {
    
    // Simple Conventions
    internal let pi: Double = Double.pi
    internal let rad: Double = Double.pi/180
    
    // Date VConversions
    internal let dayMS: Double = 1000.0 * 60.0 * 60.0 * 24.0
    internal let J0: Double = 0.0009
    internal let J1970: Double = 2440588.0
    internal let J2000: Double = 2451545.0
    
    // Obliquity of the Earth
    internal let e: Double = (Double.pi / 180.0) * 23.4397
    
    // Time Configuration (Angle°, AM, PM)
    internal var listedtimes: [[Any]] = [
        [-18.0, "Dawn", "Night"],
        [-0.833, "Sunrise", "Sunset"]
    ]
    
    // Convert Date to Day Count
    private func toDays(date: Date) -> Double {
        return toJulian(date: date) - J2000
    }
    
    // Convert Julian to Date
    private func fromJulian(j: Double) -> Date {
        return Date(milliseconds: (j + 0.5 - J1970) * dayMS)
    }
    
    // Convert Date to Julian
    private func toJulian(date: Date) -> Double {
        return Double(date.millisecondsSince1970) / dayMS - 0.5 + J1970
    }
    
    private func julianCycle(d: Double, lw: Double) -> Double {
        return ((d - J0 - lw / (2.0 * pi)).rounded())
    }
    
    private func approxTransit(Ht: Double, lw: Double, n: Double) -> Double {
        return J0 + (Ht + lw) / (2.0 * pi) + n;
    }
    
    private func solarMeanAnomaly(ds: Double) -> Double {
        return rad * (357.5291 + 0.98560028 * ds)
    }
    
    private func eclipticLongitude(m: Double, d: Double) -> Double {
        let c: Double = rad * (1.9148 * sin(m) + 0.02 * sin(2.0 * m) + 0.0003 * sin(3.0 * m))
        let p: Double = rad * 102.9372
        
        return m + c + p + pi
    }
    
    private func declination(l: Double, b: Double) -> Double {
        return asin(sin(b) * cos(e) + cos(b) * sin(e) * sin(l))
    }
    
    private func solarTransitJ(ds: Double, M: Double, L: Double) -> Double {
        return J2000 + ds + 0.0053 * sin(M) - 0.0069 * sin(2.0 * L)
    }
    
    private func getJ(h: Double, lw: Double, phi: Double, dec: Double, n: Double, M: Double, L: Double) -> Double {
        let w: Double = hourAngle(h: h, phi: phi, dec: dec)
        let a: Double = approxTransit(Ht: w, lw: lw, n: n)
        
        return solarTransitJ(ds: a, M: M, L: L)
    }
    
    private func hourAngle(h: Double, phi: Double, dec: Double) -> Double {
        return acos((sin(h) - sin(phi) * sin(dec)) / (cos(phi) * cos(dec)))
    }
    
    
    // Returns all Salat times in a dictionary for later use.
    public func getTimes(date: Date, lat: Double, lng: Double) -> Dictionary<String, Date> {
        let lw: Double = rad * -lng
        let phi: Double = rad * lat
        
        let d: Double = toDays(date: date)
        let n: Double = julianCycle(d: d, lw: lw)
        let ds: Double = approxTransit(Ht: 0.0, lw: lw, n: n)
        
        let M: Double = solarMeanAnomaly(ds: ds)
        let L: Double = eclipticLongitude(m: M, d: d)
        let dec: Double = declination(l: L, b: 0.0)
        
        let shadowTime: Double = acot(1 + tan(abs(phi - dec)))
        
        let Jnoon: Double = solarTransitJ(ds: ds, M: M, L: L)
        let Jaftnoon: Double = getJ(h: shadowTime, lw: lw, phi: phi, dec: dec, n: n, M: M, L: L)
        
        var time: [Any], Jset: Double, Jrise: Double
        var result: Dictionary<String, Date> = [
            "Noon": fromJulian(j: Jnoon),
            "Afternoon": fromJulian(j: Jaftnoon)
        ]
        
        for i in 0...(listedtimes.count - 1) {
            time = listedtimes[i]
            
            Jset = getJ(h: (time[0] as! Double) * rad, lw: lw, phi: phi, dec: dec, n: n, M: M, L: L)
            Jrise = Jnoon - (Jset - Jnoon)
            
            result[time[1] as! String] = fromJulian(j: Jrise)
            result[time[2] as! String] = fromJulian(j: Jset)
        }
        return result
    }
    
    public func currentTime(times: Dictionary<String, Date>) -> String? {
        let filteredDates = times.values.filter{$0 <= Date()}
        let currentTime = filteredDates.max()
        return times.first(where: {$0.value == currentTime})?.key
    }
    
    public func nextTime(times: Dictionary<String, Date>) -> String? {
        let timeNames = ["Dawn", "Sunrise", "Noon", "Afternoon", "Sunset", "Night", "Dawn"]
        let filteredDates = times.values.filter{$0 <= Date()}
        let currentTime = filteredDates.max()
        guard let currentTimeName = times.first(where: {$0.value == currentTime})?.key else {return "Next Prayer"}
        guard let currentIndex = timeNames.firstIndex(of: currentTimeName) else {return "Next Prayer"}
        return timeNames[currentIndex + 1]
    }
}

fileprivate func acot(_ x: Double) -> Double {
    atan(1 / x)
}

fileprivate extension Date {
    var millisecondsSince1970: Int {
        return Int((self.timeIntervalSince1970 * 1000.0).rounded())
    }
    
    init(milliseconds: Double) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds / 1000))
    }
}
