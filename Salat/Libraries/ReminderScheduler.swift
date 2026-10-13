//
//  ReminderScheduler.swift
//  Salat
//
//  Keeps iOS's pending notifications in step with ReminderPlanner's plan. Asks for
//  notification permission the first time it has something to schedule; after that it
//  respects whatever the user chose in Settings.
//

import Foundation
import UserNotifications

/// The slice of UNUserNotificationCenter the scheduler needs, so tests can fake it
protocol ReminderStore {
    func authorizationStatus(_ completion: @escaping (UNAuthorizationStatus) -> Void)
    func requestAuthorization(_ completion: @escaping (Bool) -> Void)
    /// Only the reminders this app planned (identifiers starting with `ReminderPlanner.identifierPrefix`)
    func pending(_ completion: @escaping ([PlannedReminder]) -> Void)
    func remove(identifiers: [String])
    func add(_ reminders: [PlannedReminder], completion: @escaping () -> Void)
}

struct UserNotificationStore: ReminderStore {
    private var center: UNUserNotificationCenter { .current() }

    func authorizationStatus(_ completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { completion($0.authorizationStatus) }
    }

    func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in completion(granted) }
    }

    func pending(_ completion: @escaping ([PlannedReminder]) -> Void) {
        center.getPendingNotificationRequests { requests in
            completion(requests.compactMap { request in
                guard request.identifier.hasPrefix(ReminderPlanner.identifierPrefix),
                      let trigger = request.trigger as? UNCalendarNotificationTrigger,
                      let date = trigger.nextTriggerDate() else { return nil }
                return PlannedReminder(identifier: request.identifier, fireDate: date,
                                       title: request.content.title, body: request.content.body,
                                       isTimeSensitive: request.content.interruptionLevel == .timeSensitive)
            })
        }
    }

    func remove(identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func add(_ reminders: [PlannedReminder], completion: @escaping () -> Void) {
        let group = DispatchGroup()
        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            if reminder.isTimeSensitive {
                content.interruptionLevel = .timeSensitive
            }
            // Pinning the time zone keeps the fire time an absolute moment if the user travels
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second, .timeZone],
                                                             from: reminder.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            group.enter()
            center.add(UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger)) { _ in
                group.leave()
            }
        }
        group.notify(queue: .global(), execute: completion)
    }
}

final class ReminderScheduler {
    static let shared = ReminderScheduler(store: UserNotificationStore())

    private let store: ReminderStore
    private let now: () -> Date
    private let calendar: Calendar

    // Everything below is only touched on `queue`. Only one pass runs at a time, and
    // calls that arrive during a pass collapse into one more pass for the latest location,
    // so overlapping calls can never leave duplicate reminders behind.
    private let queue = DispatchQueue(label: "com.psaray.salat.reminders")
    private var isRunning = false
    private var queued: SharedLocation?
    private var completions: [() -> Void] = []

    init(store: ReminderStore, now: @escaping () -> Date = Date.init, calendar: Calendar = .current) {
        self.store = store
        self.now = now
        self.calendar = calendar
    }

    /// Makes the pending reminders match `location`. `completion` runs once the pass that
    /// covers this call (or a later one) has finished.
    func reconcile(for location: SharedLocation, completion: (() -> Void)? = nil) {
        queue.async {
            self.queued = location
            if let completion = completion { self.completions.append(completion) }
            if !self.isRunning { self.drain() }
        }
    }

    private func drain() {
        guard let location = queued else { return }
        queued = nil
        isRunning = true
        let waiting = completions
        completions = []
        run(location) {
            self.queue.async {
                self.isRunning = false
                waiting.forEach { $0() }
                if self.queued != nil { self.drain() }
            }
        }
    }

    private func run(_ location: SharedLocation, done: @escaping () -> Void) {
        store.authorizationStatus { status in
            switch status {
            case .notDetermined:
                self.store.requestAuthorization { granted in
                    if granted { self.apply(location, done: done) } else { done() }
                }
            case .authorized, .provisional, .ephemeral:
                self.apply(location, done: done)
            default:
                // Turned off in Settings: leave nothing behind that could still fire
                self.store.pending { existing in
                    self.store.remove(identifiers: existing.map(\.identifier))
                    done()
                }
            }
        }
    }

    private func apply(_ location: SharedLocation, done: @escaping () -> Void) {
        store.pending { existing in
            let plan = ReminderPlanner.plan(for: location, now: self.now(), calendar: self.calendar)
            if ReminderPlanner.isEquivalent(existing, plan) {
                done()
                return
            }
            if !existing.isEmpty { self.store.remove(identifiers: existing.map(\.identifier)) }
            self.store.add(plan, completion: done)
        }
    }
}
