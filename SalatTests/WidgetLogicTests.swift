//
//  WidgetLogicTests.swift
//  SalatTests
//

import XCTest

final class PrayerScheduleTests: XCTestCase {

    private let sf = SharedLocation(latitude: 37.7749, longitude: -122.4194, name: "San Francisco, CA US", updatedAt: Date())
    private let moscow = SharedLocation(latitude: 55.7558, longitude: 37.6173, name: "Moscow, Moscow RU", updatedAt: Date())

    private func calendar(_ id: String) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: id)!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0, in cal: Calendar) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    // MARK: - Shape of the timeline

    func testTimelineStartsNowAndIsStrictlyIncreasing() {
        let cal = calendar("America/Los_Angeles")
        let now = date(2026, 10, 11, 17, 0, in: cal)
        let t = PrayerSchedule.timeline(for: sf, now: now, calendar: cal)
        XCTAssertEqual(t.first?.date, now)
        for (a, b) in zip(t, t.dropFirst()) {
            XCTAssertLessThan(a.date, b.date)
        }
        XCTAssertLessThanOrEqual(t.last!.date, now.addingTimeInterval(30 * 3600))
        XCTAssertLessThan(t.count, 120)
    }

    func testThereIsAnEntryAtEveryPrayerChange() throws {
        let cal = calendar("America/Los_Angeles")
        let now = date(2026, 10, 11, 17, 0, in: cal)
        let t = PrayerSchedule.timeline(for: sf, now: now, calendar: cal)
        var seenCurrent = [String]()
        for snapshot in t {
            let current = try XCTUnwrap(snapshot.status?.current)
            if seenCurrent.last != current { seenCurrent.append(current) }
        }
        // 5pm Oct 11 is in Afternoon; the next 30 hours cover Sunset, Night, then the next day
        XCTAssertEqual(Array(seenCurrent.prefix(6)), ["Afternoon", "Sunset", "Night", "Dawn", "Sunrise", "Noon"])
    }

    func testEntryAtAPrayerTimeShowsThatPrayerAsCurrent() throws {
        let cal = calendar("America/Los_Angeles")
        let now = date(2026, 10, 11, 17, 0, in: cal)
        let t = PrayerSchedule.timeline(for: sf, now: now, calendar: cal)
        let sunsetDate = try XCTUnwrap(t.first!.rows.first { $0.name == "Sunset" }?.date)
        let entry = try XCTUnwrap(t.first { $0.date == sunsetDate })
        XCTAssertEqual(entry.status?.current, "Sunset")
        XCTAssertEqual(entry.status?.next, "Night")
    }

    func testBeforeDawnIsStillNightAndNextIsDawn() throws {
        let cal = calendar("America/Los_Angeles")
        let now = date(2026, 10, 11, 3, 0, in: cal)
        let s = try XCTUnwrap(PrayerSchedule.timeline(for: sf, now: now, calendar: cal).first?.status)
        XCTAssertEqual(s.current, "Night")
        XCTAssertEqual(s.next, "Dawn")
        XCTAssertLessThan(s.currentStart, now)
        XCTAssertGreaterThan(s.nextStart, now)
    }

    func testEveryStatusIsConsistent() throws {
        let cal = calendar("America/Los_Angeles")
        for hour in stride(from: 0, to: 24, by: 3) {
            let now = date(2026, 10, 11, hour, 10, in: cal)
            for snapshot in PrayerSchedule.timeline(for: sf, now: now, calendar: cal) {
                let s = try XCTUnwrap(snapshot.status)
                XCTAssertLessThanOrEqual(s.currentStart, snapshot.date)
                XCTAssertGreaterThan(s.nextStart, snapshot.date)
                XCTAssertTrue((0...1).contains(s.progress(at: snapshot.date)))
                XCTAssertEqual(snapshot.rows.map(\.name), SalatTimes.names)
            }
        }
    }

    func testTableRollsOverToTheNewDayAtMidnight() throws {
        let cal = calendar("America/Los_Angeles")
        let now = date(2026, 10, 11, 22, 0, in: cal)
        let t = PrayerSchedule.timeline(for: sf, now: now, calendar: cal)
        let before = try XCTUnwrap(t.last { cal.component(.day, from: $0.date) == 11 })
        let after = try XCTUnwrap(t.first { cal.component(.day, from: $0.date) == 12 })
        XCTAssertEqual(after.date, date(2026, 10, 12, 0, 0, in: cal), "an entry lands exactly on midnight")
        for row in before.rows { XCTAssertTrue(cal.isDate(row.date!, inSameDayAs: before.date), row.name) }
        for row in after.rows { XCTAssertTrue(cal.isDate(row.date!, inSameDayAs: after.date), row.name) }
    }

    // MARK: - Edge cases

    func testHighLatitudeSummerSkipsMissingPrayers() throws {
        let cal = calendar("Europe/Moscow")
        let now = date(2026, 6, 21, 22, 0, in: cal)
        let t = PrayerSchedule.timeline(for: moscow, now: now, calendar: cal)
        let first = try XCTUnwrap(t.first)
        XCTAssertNil(first.rows.first { $0.name == "Dawn" }?.date)
        XCTAssertNil(first.rows.first { $0.name == "Night" }?.date)
        let status = try XCTUnwrap(first.status)
        XCTAssertEqual(status.current, "Sunset")
        XCTAssertEqual(status.next, "Sunrise")
        for snapshot in t {
            XCTAssertFalse(snapshot.rows.contains { $0.date?.timeIntervalSince1970.isNaN == true })
        }
    }

    func testDoesNotCrashAnywhereOnEarth() {
        let cal = calendar("UTC")
        let now = date(2026, 6, 21, 12, 0, in: cal)
        for lat in stride(from: -88.0, through: 88.0, by: 22.0) {
            let loc = SharedLocation(latitude: lat, longitude: 20, name: nil, updatedAt: now)
            let t = PrayerSchedule.timeline(for: loc, now: now, calendar: cal)
            XCTAssertFalse(t.isEmpty, "lat \(lat)")
        }
    }

    func testNeedsLocationSnapshot() {
        let now = Date()
        let s = PrayerSnapshot.needsLocation(at: now)
        XCTAssertFalse(s.hasLocation)
        XCTAssertNil(s.status)
        XCTAssertEqual(s.date, now)
        XCTAssertFalse(s.appGroupMissing)
    }

    func testNeedsLocationCanBlameTheAppGroup() {
        let s = PrayerSnapshot.needsLocation(at: Date(), appGroupMissing: true)
        XCTAssertTrue(s.appGroupMissing)
        XCTAssertFalse(s.hasLocation)
    }

    func testQiblaBearingIsCarriedIntoEverySnapshot() {
        let cal = calendar("America/Los_Angeles")
        let t = PrayerSchedule.timeline(for: sf, now: date(2026, 10, 11, 12, 0, in: cal), calendar: cal)
        XCTAssertTrue(t.allSatisfy { abs($0.qiblaBearing - 95.76) < 0.01 })
        XCTAssertTrue(t.allSatisfy { $0.locationName == "San Francisco, CA US" })
    }

    func testGlyphsExistForEveryPrayer() {
        for name in SalatTimes.names {
            XCTAssertFalse(PrayerSchedule.glyph(for: name).isEmpty)
        }
    }
}

final class SharedLocationTests: XCTestCase {

    private func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "SalatTests-\(UUID().uuidString)")!
    }

    func testRoundTrip() {
        let defaults = isolatedDefaults()
        let location = SharedLocation(latitude: 37.7749, longitude: -122.4194, name: "San Francisco, CA US",
                                      updatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertNil(SharedLocationStore.load(from: defaults))
        XCTAssertTrue(SharedLocationStore.save(location, to: defaults))
        XCTAssertEqual(SharedLocationStore.load(from: defaults), location)
    }

    func testSavingAgainReplacesThePreviousLocation() {
        let defaults = isolatedDefaults()
        let a = SharedLocation(latitude: 1, longitude: 2, name: "A", updatedAt: Date())
        let b = SharedLocation(latitude: 3, longitude: 4, name: nil, updatedAt: Date())
        SharedLocationStore.save(a, to: defaults)
        SharedLocationStore.save(b, to: defaults)
        XCTAssertEqual(SharedLocationStore.load(from: defaults)?.latitude, 3)
        XCTAssertNil(SharedLocationStore.load(from: defaults)?.name)
    }

    func testCorruptDataIsIgnored() {
        let defaults = isolatedDefaults()
        defaults.set(Data([0x01, 0x02]), forKey: "lastKnownLocation")
        XCTAssertNil(SharedLocationStore.load(from: defaults))
    }
}

final class CompassPointTests: XCTestCase {
    func testCardinalPoints() {
        XCTAssertEqual(Qibla.compassPoint(for: 0), "N")
        XCTAssertEqual(Qibla.compassPoint(for: 90), "E")
        XCTAssertEqual(Qibla.compassPoint(for: 180), "S")
        XCTAssertEqual(Qibla.compassPoint(for: 270), "W")
    }

    func testExamplesFromTheApp() {
        XCTAssertEqual(Qibla.compassPoint(for: 95.76), "E")   // San Francisco
        XCTAssertEqual(Qibla.compassPoint(for: 176.32), "S")  // Moscow
        XCTAssertEqual(Qibla.compassPoint(for: 126.98), "SE") // London
    }

    func testWrapsAround() {
        XCTAssertEqual(Qibla.compassPoint(for: 359), "N")
        XCTAssertEqual(Qibla.compassPoint(for: -10), "N")
        XCTAssertEqual(Qibla.compassPoint(for: 360), "N")
    }
}

import ImageIO

final class WidgetAssetTests: XCTestCase {

    /// WidgetKit refuses to archive a timeline containing an image with more than about
    /// 523,000 pixels in total. The widget then never gets a timeline and shows only its
    /// placeholder, so every image bundled with the widget has to stay well below that.
    func testWidgetImagesAreSmallEnoughToArchive() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // SalatTests
            .deletingLastPathComponent()   // repo root
        let catalog = repoRoot.appendingPathComponent("Salat Widget/Assets.xcassets")
        let files = FileManager.default.enumerator(at: catalog, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { ["png", "jpg", "jpeg"].contains($0.pathExtension.lowercased()) } ?? []

        let maxPixels = 400_000
        for file in files {
            let source = try XCTUnwrap(CGImageSourceCreateWithURL(file as CFURL, nil), file.lastPathComponent)
            let props = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
            let w = try XCTUnwrap(props[kCGImagePropertyPixelWidth] as? Int)
            let h = try XCTUnwrap(props[kCGImagePropertyPixelHeight] as? Int)
            XCTAssertLessThanOrEqual(w * h, maxPixels, "\(file.lastPathComponent) is \(w)x\(h)")
        }
    }
}
