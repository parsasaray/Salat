//
//  ReminderPlannerTests.swift
//  SalatTests
//

import XCTest

final class ReminderPlannerTests: XCTestCase {

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

    private func prayerReminders(_ plan: [PlannedReminder]) -> [PlannedReminder] {
        plan.filter { $0.identifier != ReminderPlanner.nudgeIdentifier }
    }

    // MARK: - Shape of the plan

    func testPlanIsOrderedInTheFutureAndWithinTheLimit() {
        let cal = calendar("America/Los_Angeles")
        let now = date(2026, 10, 11, 17, 0, in: cal)
        let plan = ReminderPlanner.plan(for: sf, now: now, calendar: cal)
        XCTAssertEqual(plan.count, ReminderPlanner.maxPending)
        XCTAssertLessThan(plan.count, 64)
        XCTAssertGreaterThan(plan.first!.fireDate, now)
        for (a, b) in zip(plan, plan.dropFirst()) {
            XCTAssertLessThan(a.fireDate, b.fireDate)
        }
        XCTAssertEqual(Set(plan.map(\.identifier)).count, plan.count)
    }

    func testEveryReminderFiresFiveMinutesBeforeAPrayerTime() {
        let cal = calendar("America/Los_Angeles")
        let now = date(2026, 10, 11, 17, 0, in: cal)
        let salat = SalatTimes()
        var prayerTimes = Set<Date>()
        for offset in -1...14 {
            let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now))!
            let times = salat.getTimes(date: day, lat: sf.latitude, lng: sf.longitude, calendar: cal)
            prayerTimes.formUnion(times.values)
        }
        for reminder in prayerReminders(ReminderPlanner.plan(for: sf, now: now, calendar: cal)) {
            XCTAssertTrue(prayerTimes.contains(reminder.fireDate.addingTimeInterval(5 * 60)), reminder.title)
        }
    }

    func testCoversAboutTenDays() {
        let cal = calendar("America/Los_Angeles")
        let now = date(2026, 10, 11, 17, 0, in: cal)
        let plan = prayerReminders(ReminderPlanner.plan(for: sf, now: now, calendar: cal))
        let days = plan.last!.fireDate.timeIntervalSince(now) / 86_400
        XCTAssertGreaterThan(days, 9)
        XCTAssertLessThan(days, 11)
    }

    // MARK: - Wording

    func testWordingAtEachBoundary() throws {
        let cal = calendar("America/Los_Angeles")
        let now = date(2026, 10, 11, 17, 0, in: cal)
        let plan = prayerReminders(ReminderPlanner.plan(for: sf, now: now, calendar: cal))
        func reminder(_ title: String) throws -> PlannedReminder {
            try XCTUnwrap(plan.first { $0.title == title }, title)
        }
        let city = "San Francisco, CA US"
        XCTAssertEqual(try reminder("Dawn prayer in 5 minutes").body, "Night prayer is ending · \(city)")
        XCTAssertEqual(try reminder("Sunrise in 5 minutes").body, "Dawn prayer is ending · \(city)")
        // Sunrise is not a prayer, so Noon's reminder only names the city
        XCTAssertEqual(try reminder("Noon prayer in 5 minutes").body, city)
        XCTAssertEqual(try reminder("Afternoon prayer in 5 minutes").body, "Noon prayer is ending · \(city)")
        XCTAssertEqual(try reminder("Sunset prayer in 5 minutes").body, "Afternoon prayer is ending · \(city)")
        XCTAssertEqual(try reminder("Night prayer in 5 minutes").body, "Sunset prayer is ending · \(city)")
    }

    func testUnknownCityIsLabelledLastKnownLocation() {
        let cal = calendar("America/Los_Angeles")
        let now = date(2026, 10, 11, 17, 0, in: cal)
        var unnamed = sf
        unnamed.name = nil
        let plan = prayerReminders(ReminderPlanner.plan(for: unnamed, now: now, calendar: cal))
        XCTAssertFalse(plan.isEmpty)
        XCTAssertTrue(plan.allSatisfy { $0.body.hasSuffix("Last Known Location") })
        XCTAssertTrue(plan.contains { $0.title == "Noon prayer in 5 minutes" && $0.body == "Last Known Location" })
    }

    // MARK: - What gets skipped

    func testAReminderThatShouldAlreadyHaveFiredIsSkipped() throws {
        let cal = calendar("America/Los_Angeles")
        let early = date(2026, 10, 11, 12, 0, in: cal)
        let sunset = try XCTUnwrap(SalatTimes().getTimes(date: early, lat: sf.latitude, lng: sf.longitude, calendar: cal)["Sunset"])
        // Four minutes before Sunset, its five-minute reminder is already in the past
        let plan = prayerReminders(ReminderPlanner.plan(for: sf, now: sunset.addingTimeInterval(-4 * 60), calendar: cal))
        XCTAssertEqual(plan.first?.title, "Night prayer in 5 minutes")
        XCTAssertFalse(plan.contains { $0.fireDate < sunset })
    }

    func testPrayersTheSunNeverReachesAreLeftOut() {
        // Late June in Moscow: the sun never gets 18° below the horizon
        let cal = calendar("Europe/Moscow")
        let now = date(2026, 6, 21, 12, 0, in: cal)
        let plan = prayerReminders(ReminderPlanner.plan(for: moscow, now: now, calendar: cal))
        XCTAssertGreaterThan(plan.count, 30)
        for (a, b) in zip(plan, plan.dropFirst()) {
            XCTAssertLessThan(a.fireDate, b.fireDate)
        }
        // Nothing for Dawn or Night during the first days, when they do not occur
        let firstDays = plan.filter { $0.fireDate < now.addingTimeInterval(3 * 86_400) }
        XCTAssertFalse(firstDays.contains { $0.title == "Dawn prayer in 5 minutes" })
        XCTAssertFalse(firstDays.contains { $0.title == "Night prayer in 5 minutes" })
    }

    // MARK: - The nudge

    func testNudgeComesAtMiddayAtLeastADayBeforeTheLastReminder() throws {
        let cal = calendar("America/Los_Angeles")
        let now = date(2026, 10, 11, 17, 0, in: cal)
        let plan = ReminderPlanner.plan(for: sf, now: now, calendar: cal)
        let nudge = try XCTUnwrap(plan.first { $0.identifier == ReminderPlanner.nudgeIdentifier })
        let last = try XCTUnwrap(prayerReminders(plan).last)
        XCTAssertLessThanOrEqual(nudge.fireDate, last.fireDate.addingTimeInterval(-24 * 3600))
        XCTAssertGreaterThan(nudge.fireDate, now)
        let hour = cal.component(.hour, from: nudge.fireDate)
        XCTAssertTrue((11...14).contains(hour), "nudge at hour \(hour)")
        XCTAssertEqual(plan.filter { $0.identifier == ReminderPlanner.nudgeIdentifier }.count, 1)
    }

    func testNoNudgeWhenThereIsNothingScheduled() {
        let cal = calendar("America/Los_Angeles")
        let now = date(2026, 10, 11, 17, 0, in: cal)
        XCTAssertTrue(ReminderPlanner.plan(for: sf, now: now, calendar: cal, limit: 0).isEmpty)
        XCTAssertTrue(ReminderPlanner.plan(for: sf, now: now, calendar: cal, limit: 1).isEmpty)
    }

    // MARK: - Time Sensitive

    func testPrayerRemindersAreTimeSensitiveAndTheNudgeIsNot() {
        let cal = calendar("America/Los_Angeles")
        let now = date(2026, 10, 11, 17, 0, in: cal)
        let plan = ReminderPlanner.plan(for: sf, now: now, calendar: cal)
        let prayers = prayerReminders(plan)
        XCTAssertFalse(prayers.isEmpty)
        XCTAssertTrue(prayers.allSatisfy(\.isTimeSensitive))
        XCTAssertEqual(plan.first { $0.identifier == ReminderPlanner.nudgeIdentifier }?.isTimeSensitive, false)
    }

    func testRemindersScheduledBeforeTimeSensitivityGetReplaced() {
        let cal = calendar("America/Los_Angeles")
        let now = date(2026, 10, 11, 17, 0, in: cal)
        let plan = ReminderPlanner.plan(for: sf, now: now, calendar: cal)
        let old = plan.map {
            PlannedReminder(identifier: $0.identifier, fireDate: $0.fireDate, title: $0.title, body: $0.body, isTimeSensitive: false)
        }
        XCTAssertFalse(ReminderPlanner.isEquivalent(old, plan))
    }

    // MARK: - Equivalence

    func testSmallDriftIsEquivalentButDifferentTextIsNot() {
        let cal = calendar("America/Los_Angeles")
        let now = date(2026, 10, 11, 17, 0, in: cal)
        let plan = ReminderPlanner.plan(for: sf, now: now, calendar: cal)
        func shifted(by seconds: TimeInterval) -> [PlannedReminder] {
            plan.map { PlannedReminder(identifier: $0.identifier, fireDate: $0.fireDate.addingTimeInterval(seconds), title: $0.title, body: $0.body, isTimeSensitive: $0.isTimeSensitive) }
        }
        XCTAssertTrue(ReminderPlanner.isEquivalent(plan, shifted(by: 10)))
        XCTAssertFalse(ReminderPlanner.isEquivalent(plan, shifted(by: 120)))

        var elsewhere = sf
        elsewhere.name = "Seattle, WA US"
        let other = ReminderPlanner.plan(for: elsewhere, now: now, calendar: cal)
        XCTAssertFalse(ReminderPlanner.isEquivalent(plan, other))
        XCTAssertFalse(ReminderPlanner.isEquivalent(plan, Array(plan.dropLast())))
    }
}
