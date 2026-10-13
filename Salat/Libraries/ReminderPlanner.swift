//
//  ReminderPlanner.swift
//  Salat
//
//  Decides which prayer reminders should be pending on the device. Pure logic, so it is
//  easy to test; ReminderScheduler is what actually hands the result to iOS.
//
//  iOS keeps only the soonest 64 pending local notifications, so this plans about ten days
//  ahead and the app replans every time it is opened. Near the end of that window one
//  extra reminder asks the user to open Salat again.
//

import Foundation

struct PlannedReminder: Equatable {
    let identifier: String
    let fireDate: Date
    let title: String
    let body: String
}

enum ReminderPlanner {
    static let identifierPrefix = "salat."
    static let nudgeIdentifier = "salat.nudge"
    /// Each prayer reminder fires this long before the prayer begins
    static let leadTime: TimeInterval = 5 * 60
    /// iOS keeps 64; this leaves some room
    static let maxPending = 60
    static let unknownLocationName = "Last Known Location"

    private struct Moment {
        let name: String
        let date: Date
    }

    /// Prayer reminders from `now` onward at the location's prayer times, plus a nudge
    /// to open the app again once the plan is about a day from running out.
    static func plan(for location: SharedLocation,
                     now: Date,
                     calendar: Calendar = .current,
                     limit: Int = maxPending) -> [PlannedReminder] {
        let prayerSlots = max(limit - 1, 0)
        guard prayerSlots > 0 else { return [] }

        let salat = SalatTimes()
        let startOfToday = calendar.startOfDay(for: now)
        var moments: [Moment] = []
        // Yesterday is included so the first prayer of today knows what came before it
        for offset in -1...14 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday) else { continue }
            let times = salat.getTimes(date: day, lat: location.latitude, lng: location.longitude, calendar: calendar)
            for name in SalatTimes.names {
                if let date = times[name] { moments.append(Moment(name: name, date: date)) }
            }
        }
        moments.sort { $0.date < $1.date }

        let city = location.name ?? unknownLocationName
        var reminders: [PlannedReminder] = []
        for (previous, next) in zip(moments, moments.dropFirst()) {
            let fireDate = next.date.addingTimeInterval(-leadTime)
            // Already passed, or too close to schedule
            guard fireDate > now.addingTimeInterval(1) else { continue }
            let text = content(upcoming: next.name, ending: previous.name, city: city)
            reminders.append(PlannedReminder(identifier: "\(identifierPrefix)\(next.name).\(Int(fireDate.timeIntervalSince1970))",
                                             fireDate: fireDate, title: text.title, body: text.body))
            if reminders.count == prayerSlots { break }
        }

        if let nudge = nudge(after: reminders, moments: moments, now: now) {
            reminders.append(nudge)
        }
        return reminders.sorted { $0.fireDate < $1.fireDate }
    }

    /// `upcoming` begins in five minutes and `ending` is the period that ends with it.
    /// Sunrise is not a prayer, so nothing is said about it ending.
    static func content(upcoming: String, ending: String, city: String) -> (title: String, body: String) {
        let minutes = Int(leadTime / 60)
        let title = upcoming == "Sunrise"
            ? "Sunrise in \(minutes) minutes"
            : "\(upcoming) prayer in \(minutes) minutes"
        let body = ending == "Sunrise" ? city : "\(ending) prayer is ending · \(city)"
        return (title, body)
    }

    /// Midday, at least a day before the last planned reminder, so there is still a day
    /// of reminders left when the user sees it.
    private static func nudge(after reminders: [PlannedReminder], moments: [Moment], now: Date) -> PlannedReminder? {
        guard let last = reminders.last else { return nil }
        let latest = last.fireDate.addingTimeInterval(-24 * 3600)
        let fireDate = moments
            .filter { $0.name == "Noon" }
            .map { $0.date.addingTimeInterval(30 * 60) }
            .last { $0 <= latest && $0 > now.addingTimeInterval(1) }
        guard let date = fireDate else { return nil }
        return PlannedReminder(identifier: nudgeIdentifier, fireDate: date,
                               title: "Open Salat to keep reminders going",
                               body: "Prayer reminders will stop soon unless Salat is opened.")
    }

    /// Whether `pending` already matches `planned`, allowing a few seconds of drift in the
    /// times, which GPS jitter causes. Anything else (a different city, a prayer
    /// that moved by minutes) is a different plan.
    static func isEquivalent(_ pending: [PlannedReminder], _ planned: [PlannedReminder], tolerance: TimeInterval = 30) -> Bool {
        guard pending.count == planned.count else { return false }
        let a = pending.sorted { $0.fireDate < $1.fireDate }
        let b = planned.sorted { $0.fireDate < $1.fireDate }
        return zip(a, b).allSatisfy {
            $0.title == $1.title && $0.body == $1.body && abs($0.fireDate.timeIntervalSince($1.fireDate)) <= tolerance
        }
    }
}
