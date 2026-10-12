//
//  QiblaTests.swift
//  SalatTests
//

import XCTest

final class QiblaTests: XCTestCase {

    private func bearing(_ lat: Double, _ lon: Double) -> Double {
        Qibla.bearing(latitude: lat, longitude: lon)
    }

    // MARK: - The directions the app is designed to show

    func testSanFranciscoPointsEastSlightlySouth() {
        let b = bearing(37.7749, -122.4194)
        XCTAssertEqual(b, 95.76, accuracy: 0.01)
        XCTAssertTrue(b > 90 && b < 135, "east, slightly south")
    }

    func testMoscowPointsSouth() {
        let b = bearing(55.7558, 37.6173)
        XCTAssertEqual(b, 176.32, accuracy: 0.01)
        XCTAssertTrue(b > 160 && b < 190, "south")
    }

    func testKnownCities() {
        XCTAssertEqual(bearing(40.7128, -74.0060), 99.62, accuracy: 0.01)   // New York
        XCTAssertEqual(bearing(51.5074, -0.1278), 126.98, accuracy: 0.01)   // London
        XCTAssertEqual(bearing(35.6892, 51.3890), 219.02, accuracy: 0.01)   // Tehran
        XCTAssertEqual(bearing(-26.2041, 28.0473), 13.89, accuracy: 0.01)   // Johannesburg
        XCTAssertEqual(bearing(-33.8688, 151.2093), 296.40, accuracy: 0.01) // Sydney
    }

    func testEastOfKaabaWrapsClockwiseFromNorth() {
        // Anything east of the Kaaba has to face west of north-south
        XCTAssertTrue(bearing(-6.2, 106.85) > 180)   // Jakarta
        XCTAssertTrue(bearing(-36.85, 174.76) > 180) // Auckland
    }

    // MARK: - Edge cases that used to produce NaN

    func testSameLongitudeSouthOfKaabaPointsNorth() {
        XCTAssertEqual(bearing(10, Qibla.kaabaLongitude), 0, accuracy: 1e-9)
    }

    func testSameLongitudeNorthOfKaabaPointsSouth() {
        XCTAssertEqual(bearing(50, Qibla.kaabaLongitude), 180, accuracy: 1e-9)
    }

    func testAtTheKaabaIsAValidNumber() {
        let b = bearing(Qibla.kaabaLatitude, Qibla.kaabaLongitude)
        XCTAssertFalse(b.isNaN)
        XCTAssertTrue(b >= 0 && b < 360)
    }

    func testAlwaysInRangeAcrossTheWholeWorld() {
        for lat in stride(from: -90.0, through: 90.0, by: 7.5) {
            for lon in stride(from: -180.0, through: 180.0, by: 7.5) {
                let b = bearing(lat, lon)
                XCTAssertFalse(b.isNaN, "NaN at \(lat), \(lon)")
                XCTAssertTrue(b >= 0 && b < 360, "\(b) out of range at \(lat), \(lon)")
            }
        }
    }

    // MARK: - Same answer as the original three-point formula

    /// The original implementation, kept here only to prove the replacement agrees with it.
    private func originalFormula(lat: Double, lon: Double) -> Double {
        let kLat = 21.4225, kLon = 39.8262
        let distAB = pow((90 - lat), 2) + pow((lon - lon), 2)
        let distBC = pow((lat - kLat), 2) + pow((lon - kLon), 2)
        let distAC = pow((90 - kLat), 2) + pow((lon - kLon), 2)
        var angle = acos((distAB + distBC - distAC) / (2 * sqrt(distAB) * sqrt(distBC)))
        if kLon < lon { angle = 2 * .pi - angle }
        return angle.degrees
    }

    func testMatchesOriginalFormulaWhereItWasDefined() {
        var compared = 0
        for lat in stride(from: -85.0, through: 85.0, by: 5.3) {
            for lon in stride(from: -179.0, through: 179.0, by: 5.7) {
                let old = originalFormula(lat: lat, lon: lon)
                guard !old.isNaN else { continue }
                XCTAssertEqual(bearing(lat, lon), old, accuracy: 1e-9, "at \(lat), \(lon)")
                compared += 1
            }
        }
        XCTAssertGreaterThan(compared, 1000)
    }
}

final class CompassAngleTests: XCTestCase {

    private func degrees(_ d: Double) -> Double { d.radians }

    func testWrapStaysInHalfTurn() {
        for deg in stride(from: -720.0, through: 720.0, by: 10.0) {
            let w = degrees(deg).wrappedToHalfTurn
            XCTAssertTrue(w > -.pi - 1e-12 && w <= .pi + 1e-12, "\(deg)° wrapped to \(w)")
            // Same direction as before
            XCTAssertEqual(cos(w), cos(degrees(deg)), accuracy: 1e-9)
            XCTAssertEqual(sin(w), sin(degrees(deg)), accuracy: 1e-9)
        }
    }

    func testWrapExamples() {
        XCTAssertEqual(degrees(350).wrappedToHalfTurn.degrees, -10, accuracy: 1e-9)
        XCTAssertEqual(degrees(-350).wrappedToHalfTurn.degrees, 10, accuracy: 1e-9)
        XCTAssertEqual(degrees(180).wrappedToHalfTurn.degrees, 180, accuracy: 1e-9)
        XCTAssertEqual(degrees(-180).wrappedToHalfTurn.degrees, 180, accuracy: 1e-9)
    }

    func testLabelIsNeverUpsideDown() {
        // The compass passes direction = qibla bearing - heading, which spans (-360°, 360°)
        for deg in stride(from: -359.0, through: 359.0, by: 1.0) {
            XCTAssertGreaterThanOrEqual(cos(degrees(deg).readableLabelRotation), -1e-9, "upside down at \(deg)°")
        }
    }

    func testLabelStillRunsAlongTheArrow() {
        // Rotation is always a quarter turn off the arrow, so the text lies along the shaft
        for deg in stride(from: -359.0, through: 359.0, by: 7.0) {
            let arrow = degrees(deg)
            let offset = (arrow.readableLabelRotation - arrow).wrappedToHalfTurn
            XCTAssertEqual(abs(offset), .pi / 2, accuracy: 1e-9, "at \(deg)°")
        }
    }

    func testLabelUnchangedWhereOldCodeWasAlreadyCorrect() {
        func old(_ d: Double) -> Double { (d > 0 || d < -.pi) ? d - .pi / 2 : d + .pi / 2 }
        for deg in stride(from: -359.0, through: 180.0, by: 1.0) {
            // Exactly -180° and +180° are the same direction; the old code gave them opposite labels
            if deg == -180 { continue }
            let d = degrees(deg)
            XCTAssertEqual(d.readableLabelRotation.wrappedToHalfTurn, old(d).wrappedToHalfTurn, accuracy: 1e-9, "at \(deg)°")
        }
    }
}
