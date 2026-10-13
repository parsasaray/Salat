//
//  WidgetTheme.swift
//  Salat Widget
//
//  The app's design language, for widgets: the pale-blue (navy in dark mode) background,
//  one color per prayer, semibold prayer names, regular times, and a thin day timeline
//  with a dot for each prayer and a sun for "now".
//

import SwiftUI
import WidgetKit

enum Theme {
    static let background = Color("Background")
    static let secondaryBackground = Color("Secondary Background")
    static let ink = Color("Ink")

    static func color(for prayer: String) -> Color { Color(prayer) }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        formatter.timeZone = .autoupdatingCurrent
        return formatter
    }()

    /// Same "h:mm" the app shows, or "--:--" when the time does not exist that day
    static func time(_ date: Date?) -> String {
        guard let date = date else { return "--:--" }
        return timeFormatter.string(from: date)
    }

    /// "95.8°" with the same precision the app's compass label uses
    static func degrees(_ bearing: Double) -> String {
        let formatter = NumberFormatter()
        formatter.usesSignificantDigits = true
        formatter.maximumSignificantDigits = 4
        return (formatter.string(for: bearing) ?? "\(Int(bearing))") + "°"
    }
}

/// A prayer's name in its color, like the rows of the app
struct PrayerNameText: View {
    let name: String
    var size: CGFloat = 30

    var body: some View {
        Text(name)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(Theme.color(for: name))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .layoutPriority(1)
    }
}

/// The thin line across the day with a colored dot per prayer and the sun at the entry's time
struct TimelineBar: View {
    let snapshot: PrayerSnapshot
    var dotSize: CGFloat = 10
    var sunSize: CGFloat = 16

    private func fraction(of date: Date) -> CGFloat {
        let start = Calendar.current.startOfDay(for: snapshot.date)
        return CGFloat(min(max(date.timeIntervalSince(start) / 86400, 0), 1))
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let midY = proxy.size.height / 2
            ZStack {
                Capsule()
                    .fill(.primary)
                    .frame(width: width, height: 2)
                    .position(x: width / 2, y: midY)
                ForEach(snapshot.rows, id: \.name) { row in
                    if let date = row.date {
                        Circle()
                            .fill(Theme.color(for: row.name))
                            .frame(width: dotSize, height: dotSize)
                            .position(x: fraction(of: date) * width, y: midY)
                    }
                }
                Image(systemName: "sun.max.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: sunSize, height: sunSize)
                    .widgetAccentable()
                    .position(x: fraction(of: snapshot.date) * width, y: midY)
            }
        }
        .frame(height: max(dotSize, sunSize) + 4)
        .accessibilityHidden(true)
    }
}

/// Counts down to `end` on its own, with no timeline reloads
struct Countdown: View {
    let from: Date
    let end: Date
    var size: CGFloat = 25

    var body: some View {
        Text(timerInterval: from...max(from, end), pauseTime: nil, countsDown: true, showsHours: true)
            .font(.system(size: size).monospacedDigit())
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Shown until the app has run once and shared a location
struct NeedsLocationView: View {
    let snapshot: PrayerSnapshot
    @Environment(\.widgetFamily) private var family

    private var message: String {
        if snapshot.appGroupMissing { return "App Group missing" }
        return snapshot.hasLocation ? "No prayer times today" : "Open Salat"
    }
    private var detail: String {
        if snapshot.appGroupMissing { return "Enable it for the app and the widget" }
        return snapshot.hasLocation ? "The sun does not reach these angles here" : "to set your location"
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            Label(message, systemImage: "location.slash")
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "location.slash")
            }
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Label(message, systemImage: "location.slash").font(.headline)
                Text(detail).font(.system(size: 13))
            }
        default:
            VStack(spacing: 8) {
                Image(systemName: "location.slash").font(.system(size: 28))
                Text(message).font(.system(size: 20, weight: .semibold))
                Text(detail).font(.system(size: 15)).multilineTextAlignment(.center)
            }
            .foregroundStyle(.primary)
        }
    }
}
