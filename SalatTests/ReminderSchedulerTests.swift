//
//  ReminderSchedulerTests.swift
//  SalatTests
//

import XCTest
import UserNotifications

private final class FakeReminderStore: ReminderStore {
    var status: UNAuthorizationStatus = .authorized
    var userAllowsWhenAsked = true
    var reminders: [PlannedReminder] = []
    var addCalls = 0
    var removeCalls = 0
    var authorizationRequests = 0

    func authorizationStatus(_ completion: @escaping (UNAuthorizationStatus) -> Void) { completion(status) }

    func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        authorizationRequests += 1
        status = userAllowsWhenAsked ? .authorized : .denied
        completion(userAllowsWhenAsked)
    }

    func pending(_ completion: @escaping ([PlannedReminder]) -> Void) { completion(reminders) }

    func remove(identifiers: [String]) {
        removeCalls += 1
        reminders.removeAll { identifiers.contains($0.identifier) }
    }

    func add(_ new: [PlannedReminder], completion: @escaping () -> Void) {
        addCalls += 1
        reminders += new
        completion()
    }
}

final class ReminderSchedulerTests: XCTestCase {

    private let sf = SharedLocation(latitude: 37.7749, longitude: -122.4194, name: "San Francisco, CA US", updatedAt: Date())
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()
    private lazy var now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 11, hour: 17))!

    private func makeScheduler(_ store: FakeReminderStore) -> ReminderScheduler {
        ReminderScheduler(store: store, now: { self.now }, calendar: calendar)
    }

    private func reconcile(_ scheduler: ReminderScheduler, _ location: SharedLocation) {
        let done = expectation(description: "reconciled")
        scheduler.reconcile(for: location) { done.fulfill() }
        wait(for: [done], timeout: 5)
    }

    func testSchedulesThePlanWhenAllowed() {
        let store = FakeReminderStore()
        reconcile(makeScheduler(store), sf)
        let plan = ReminderPlanner.plan(for: sf, now: now, calendar: calendar)
        XCTAssertEqual(store.reminders.count, plan.count)
        XCTAssertTrue(ReminderPlanner.isEquivalent(store.reminders, plan))
        XCTAssertEqual(store.authorizationRequests, 0)
    }

    func testReconcilingAgainWithTheSamePlaceChangesNothing() {
        let store = FakeReminderStore()
        let scheduler = makeScheduler(store)
        reconcile(scheduler, sf)
        var jittered = sf
        jittered.latitude += 0.001
        reconcile(scheduler, jittered)
        reconcile(scheduler, sf)
        XCTAssertEqual(store.addCalls, 1)
        XCTAssertEqual(store.removeCalls, 0)
    }

    func testANewCityReplacesTheOldRemindersWithoutDuplicates() {
        let store = FakeReminderStore()
        let scheduler = makeScheduler(store)
        reconcile(scheduler, sf)
        var seattle = SharedLocation(latitude: 47.6062, longitude: -122.3321, name: "Seattle, WA US", updatedAt: Date())
        reconcile(scheduler, seattle)
        let plan = ReminderPlanner.plan(for: seattle, now: now, calendar: calendar)
        XCTAssertEqual(store.reminders.count, plan.count)
        XCTAssertTrue(store.reminders.allSatisfy { !$0.body.contains("San Francisco") })
        seattle.name = nil
        reconcile(scheduler, seattle)
        XCTAssertTrue(store.reminders.contains { $0.body.contains("Last Known Location") })
    }

    func testDeniedRemovesEverythingAndSchedulesNothing() {
        let store = FakeReminderStore()
        let scheduler = makeScheduler(store)
        reconcile(scheduler, sf)
        XCTAssertFalse(store.reminders.isEmpty)

        store.status = .denied
        reconcile(scheduler, sf)
        XCTAssertTrue(store.reminders.isEmpty)
        XCTAssertEqual(store.authorizationRequests, 0)
    }

    func testAsksOnceWhenUndecidedThenSchedules() {
        let store = FakeReminderStore()
        store.status = .notDetermined
        let scheduler = makeScheduler(store)
        reconcile(scheduler, sf)
        XCTAssertEqual(store.authorizationRequests, 1)
        XCTAssertFalse(store.reminders.isEmpty)
        reconcile(scheduler, sf)
        XCTAssertEqual(store.authorizationRequests, 1)
    }

    func testDecliningThePromptSchedulesNothing() {
        let store = FakeReminderStore()
        store.status = .notDetermined
        store.userAllowsWhenAsked = false
        reconcile(makeScheduler(store), sf)
        XCTAssertEqual(store.authorizationRequests, 1)
        XCTAssertTrue(store.reminders.isEmpty)
        XCTAssertEqual(store.addCalls, 0)
    }

    func testRapidCallsEndWithTheLatestLocationAndNoDuplicates() {
        let store = FakeReminderStore()
        let scheduler = makeScheduler(store)
        let names = ["A, CA US", "B, CA US", "C, CA US", "D, CA US"]
        let done = expectation(description: "all reconciled")
        done.expectedFulfillmentCount = names.count
        for name in names {
            var location = sf
            location.name = name
            scheduler.reconcile(for: location) { done.fulfill() }
        }
        wait(for: [done], timeout: 5)
        let plan = ReminderPlanner.plan(for: SharedLocation(latitude: sf.latitude, longitude: sf.longitude, name: "D, CA US", updatedAt: Date()),
                                        now: now, calendar: calendar)
        XCTAssertEqual(store.reminders.count, plan.count)
        XCTAssertTrue(store.reminders.allSatisfy { $0.body.contains("D, CA US") || $0.identifier == ReminderPlanner.nudgeIdentifier })
    }
}
