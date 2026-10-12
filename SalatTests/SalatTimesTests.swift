//
//  SalatTimesTests.swift
//  SalatTests
//

import XCTest

final class SalatTimesTests: XCTestCase {

    private let sf = (lat: 37.7749, lng: -122.4194)
    private let moscow = (lat: 55.7558, lng: 37.6173)

    private func calendar(_ id: String) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: id)!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0, in cal: Calendar) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    /// Seconds since local midnight, for readable comparisons
    private func secondsIntoDay(_ date: Date, in cal: Calendar) -> Double {
        date.timeIntervalSince(cal.startOfDay(for: date))
    }

    private func hms(_ h: Int, _ m: Int, _ s: Int = 0) -> Double { Double(h * 3600 + m * 60 + s) }

    // MARK: - Accuracy

    // Reference values are from an independent NOAA solar calculation. The SunCalc algorithm
    // runs about 1-2 minutes later than that, so the tolerance is 3 minutes.
    func testSanFranciscoMatchesIndependentReference() throws {
        let cal = calendar("America/Los_Angeles")
        let t = SalatTimes().getTimes(date: date(2026, 10, 11, in: cal), lat: sf.lat, lng: sf.lng, calendar: cal)
        let expected: [String: Double] = [
            "Dawn": hms(5, 47, 18), "Sunrise": hms(7, 14, 29), "Noon": hms(12, 56, 24),
            "Afternoon": hms(16, 7, 50), "Sunset": hms(18, 37, 35), "Night": hms(20, 4, 37)
        ]
        for (name, seconds) in expected {
            let time = try XCTUnwrap(t[name], name)
            XCTAssertEqual(secondsIntoDay(time, in: cal), seconds, accuracy: 180, name)
        }
    }

    func testMoscowAutumnMatchesIndependentReference() throws {
        let cal = calendar("Europe/Moscow")
        let t = SalatTimes().getTimes(date: date(2026, 10, 11, in: cal), lat: moscow.lat, lng: moscow.lng, calendar: cal)
        XCTAssertEqual(secondsIntoDay(try XCTUnwrap(t["Noon"]), in: cal), hms(12, 16, 15), accuracy: 180)
        XCTAssertEqual(secondsIntoDay(try XCTUnwrap(t["Sunset"]), in: cal), hms(17, 39, 39), accuracy: 180)
        XCTAssertEqual(secondsIntoDay(try XCTUnwrap(t["Dawn"]), in: cal), hms(4, 48, 37), accuracy: 180)
    }

    func testTimesAreInOrderThroughTheDay() throws {
        let cal = calendar("America/Los_Angeles")
        let t = SalatTimes().getTimes(date: date(2026, 3, 20, in: cal), lat: sf.lat, lng: sf.lng, calendar: cal)
        let ordered = try SalatTimes.names.map { try XCTUnwrap(t[$0], $0) }
        XCTAssertEqual(ordered, ordered.sorted())
    }

    // MARK: - Fixes

    func testTimesBelongToTheRequestedCalendarDayAtAnyHour() {
        // Between civil midnight and solar midnight this used to return the previous day
        let cal = calendar("America/Los_Angeles")
        let noon = SalatTimes().getTimes(date: date(2026, 10, 11, 12, 0, in: cal), lat: sf.lat, lng: sf.lng, calendar: cal)
        for (hour, minute) in [(0, 0), (0, 30), (0, 59), (1, 30), (23, 59)] {
            let t = SalatTimes().getTimes(date: date(2026, 10, 11, hour, minute, in: cal), lat: sf.lat, lng: sf.lng, calendar: cal)
            XCTAssertEqual(t, noon, "different times when asked at \(hour):\(minute)")
            for (name, time) in t {
                XCTAssertTrue(cal.isDate(time, inSameDayAs: date(2026, 10, 11, in: cal)), "\(name) is on the wrong day")
            }
        }
    }

    func testUndefinedTimesAreOmittedInsteadOfNaN() {
        // Moscow midsummer: the sun never gets 18° below the horizon
        let cal = calendar("Europe/Moscow")
        let t = SalatTimes().getTimes(date: date(2026, 6, 21, in: cal), lat: moscow.lat, lng: moscow.lng, calendar: cal)
        XCTAssertNil(t["Dawn"])
        XCTAssertNil(t["Night"])
        for name in ["Sunrise", "Noon", "Afternoon", "Sunset"] {
            XCTAssertNotNil(t[name], name)
        }
        XCTAssertFalse(t.values.contains { $0.timeIntervalSince1970.isNaN })
    }

    func testNoInvalidDatesAnywhereOnEarthAtAnySeason() {
        let cal = calendar("UTC")
        for lat in stride(from: -85.0, through: 85.0, by: 17.0) {
            for month in [3, 6, 9, 12] {
                let t = SalatTimes().getTimes(date: date(2026, month, 21, in: cal), lat: lat, lng: 10, calendar: cal)
                XCTAssertFalse(t.values.contains { $0.timeIntervalSince1970.isNaN }, "NaN at \(lat), month \(month)")
            }
        }
    }
}
