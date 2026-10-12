//
//  Qibla.swift
//  Salat
//

import Foundation

enum Qibla {
    static let kaabaLatitude = 21.4225
    static let kaabaLongitude = 39.8262

    /// Direction of the Kaaba in degrees clockwise from north, in 0..<360.
    ///
    /// Latitude and longitude are treated as flat map coordinates (a Greenwich-centred
    /// map), so the bearing is the angle of the straight line from the user to the Kaaba
    /// on that map. This is the same result as the original three-point law-of-cosines
    /// calculation, but it is also defined directly at the Kaaba and on its meridian.
    static func bearing(latitude: Double, longitude: Double) -> Double {
        let north = kaabaLatitude - latitude
        let east = kaabaLongitude - longitude
        let degrees = atan2(east, north).degrees
        let wrapped = degrees < 0 ? degrees + 360 : degrees
        return wrapped >= 360 ? 0 : wrapped
    }

    /// 16-point compass name for a bearing in degrees ("E", "SSE", ...)
    static func compassPoint(for bearing: Double) -> String {
        let points = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                      "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let normalized = bearing.truncatingRemainder(dividingBy: 360)
        let positive = normalized < 0 ? normalized + 360 : normalized
        return points[Int((positive + 11.25) / 22.5) % 16]
    }
}
