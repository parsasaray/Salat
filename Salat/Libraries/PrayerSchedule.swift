//
//  PrayerSchedule.swift
//  Salat
//
//  Everything the widgets display, computed up front as a list of snapshots.
//  WidgetKit then simply shows the right snapshot at the right time, with no
//  wake-ups and no location lookups in the extension.
//

import Foundation

struct PrayerMoment: Equatable {
    let name: String
    let date: Date
}

struct PrayerRow: Equatable {
    let name: String
    /// nil when the sun never reaches this prayer's angle on that day (high latitudes)
    let date: Date?
}

struct PrayerStatus: Equatable {
    let current: String
    let currentStart: Date
    let next: String
    let nextStart: Date

    /// How far through the current prayer's period `date` is, 0...1
    func progress(at date: Date) -> Double {
        let total = nextStart.timeIntervalSince(currentStart)
        guard total > 0 else { return 0 }
        return min(max(date.timeIntervalSince(currentStart) / total, 0), 1)
    }
}

struct PrayerSnapshot: Equatable {
    let date: Date
    let hasLocation: Bool
    let status: PrayerStatus?
    /// The six prayers of the civil day containing `date`, in order
    let rows: [PrayerRow]
    let locationName: String?
    let qiblaBearing: Double
    /// The widget could not reach the App Group at all, as opposed to the app not having
    /// shared a location yet
    var appGroupMissing = false

    static func needsLocation(at date: Date, appGroupMissing: Bool = false) -> PrayerSnapshot {
        PrayerSnapshot(date: date, hasLocation: false, status: nil, rows: [], locationName: nil,
                       qiblaBearing: 0, appGroupMissing: appGroupMissing)
    }
}

enum PrayerSchedule {
    static let names = SalatTimes.names

    /// SF Symbol shown next to each prayer
    static func glyph(for name: String) -> String {
        switch name {
        case "Dawn": return "moon.stars"
        case "Sunrise": return "sunrise.fill"
        case "Noon": return "sun.max.fill"
        case "Afternoon": return "sun.min.fill"
        case "Sunset": return "sunset.fill"
        case "Night": return "moon.fill"
        default: return "sun.max.fill"
        }
    }

    /// The prayer in effect at `date` and the one after it. Before the first prayer of
    /// the day this is still last night's "Night", because `moments` includes yesterday.
    static func status(at date: Date, moments: [PrayerMoment]) -> PrayerStatus? {
        guard let next = moments.first(where: { $0.date > date }),
              let current = moments.last(where: { $0.date <= date }) else { return nil }
        return PrayerStatus(current: current.name, currentStart: current.date, next: next.name, nextStart: next.date)
    }

    /// Snapshots from `now` through `horizon`: one at every prayer, one at every midnight
    /// (so the table rolls over to the new day), and one every `step` so the day's timeline
    /// marker and gauges keep moving.
    static func timeline(for location: SharedLocation,
                         now: Date,
                         calendar: Calendar = .current,
                         horizon: TimeInterval = 30 * 3600,
                         step: TimeInterval = 60 * 60) -> [PrayerSnapshot] {
        let salat = SalatTimes()
        let startOfToday = calendar.startOfDay(for: now)

        var timesByDay: [Date: [String: Date]] = [:]
        var moments: [PrayerMoment] = []
        for offset in -1...3 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday) else { continue }
            let times = salat.getTimes(date: day, lat: location.latitude, lng: location.longitude, calendar: calendar)
            timesByDay[calendar.startOfDay(for: day)] = times
            for name in names {
                if let date = times[name] { moments.append(PrayerMoment(name: name, date: date)) }
            }
        }
        moments.sort { $0.date < $1.date }

        let end = now.addingTimeInterval(horizon)
        var dates: Set<Date> = [now]
        var cursor = now.addingTimeInterval(step)
        while cursor <= end {
            dates.insert(cursor)
            cursor = cursor.addingTimeInterval(step)
        }
        for moment in moments where moment.date > now && moment.date <= end {
            dates.insert(moment.date)
        }
        for offset in 1...2 {
            if let midnight = calendar.date(byAdding: .day, value: offset, to: startOfToday), midnight > now, midnight <= end {
                dates.insert(midnight)
            }
        }

        let bearing = Qibla.bearing(latitude: location.latitude, longitude: location.longitude)
        return dates.sorted().map { date in
            let times = timesByDay[calendar.startOfDay(for: date)] ?? [:]
            return PrayerSnapshot(date: date,
                                  hasLocation: true,
                                  status: status(at: date, moments: moments),
                                  rows: names.map { PrayerRow(name: $0, date: times[$0]) },
                                  locationName: location.name,
                                  qiblaBearing: bearing)
        }
    }
}
