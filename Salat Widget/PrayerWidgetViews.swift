//
//  PrayerWidgetViews.swift
//  Salat Widget
//

import SwiftUI
import WidgetKit

struct PrayerWidgetView: View {
    let entry: PrayerEntry
    @Environment(\.widgetFamily) private var family

    private var isAccessory: Bool {
        switch family {
        case .accessoryInline, .accessoryCircular, .accessoryRectangular: return true
        default: return false
        }
    }

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if isAccessory { Color.clear } else { Theme.background }
            }
    }

    @ViewBuilder
    private var content: some View {
        let snapshot = entry.snapshot
        if let status = snapshot.status {
            switch family {
            case .accessoryInline: InlinePrayerView(snapshot: snapshot, status: status)
            case .accessoryCircular: CircularPrayerView(snapshot: snapshot, status: status)
            case .accessoryRectangular: RectangularPrayerView(snapshot: snapshot, status: status)
            case .systemSmall: SmallPrayerView(snapshot: snapshot, status: status)
            case .systemMedium: MediumPrayerView(snapshot: snapshot, status: status)
            default: LargePrayerView(snapshot: snapshot, status: status)
            }
        } else {
            NeedsLocationView(snapshot: snapshot)
        }
    }
}

// MARK: - Lock screen

private struct InlinePrayerView: View {
    let snapshot: PrayerSnapshot
    let status: PrayerStatus

    var body: some View {
        Label("\(status.current) · \(status.next) \(Theme.time(status.nextStart))",
              systemImage: PrayerSchedule.glyph(for: status.current))
    }
}

private struct CircularPrayerView: View {
    let snapshot: PrayerSnapshot
    let status: PrayerStatus

    var body: some View {
        Gauge(value: status.progress(at: snapshot.date)) {
            Image(systemName: PrayerSchedule.glyph(for: status.current))
        } currentValueLabel: {
            Text(Theme.time(status.nextStart)).font(.system(size: 12, weight: .semibold))
        }
        .gaugeStyle(.accessoryCircular)
    }
}

private struct RectangularPrayerView: View {
    let snapshot: PrayerSnapshot
    let status: PrayerStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: PrayerSchedule.glyph(for: status.current))
                Text(status.current)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .widgetAccentable()
            Text("\(status.next) · \(Theme.time(status.nextStart))")
                .font(.system(size: 14))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            ProgressView(timerInterval: status.currentStart...status.nextStart, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
        }
        // The card's rounded corners cut into the content, so give the edges room
        .padding(.horizontal, 12)
    }
}

// MARK: - Home screen

private struct SmallPrayerView: View {
    let snapshot: PrayerSnapshot
    let status: PrayerStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: PrayerSchedule.glyph(for: status.current))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.color(for: status.current))
                PrayerNameText(name: status.current, size: 26)
            }
            HStack(spacing: 5) {
                Image(systemName: PrayerSchedule.glyph(for: status.next))
                    .font(.system(size: 14, weight: .semibold))
                Text("\(status.next) \(Theme.time(status.nextStart))")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(Theme.color(for: status.next))
            Spacer(minLength: 0)
            Countdown(from: snapshot.date, end: status.nextStart, size: 24)
            TimelineBar(snapshot: snapshot, dotSize: 8, sunSize: 14)
        }
    }
}

private struct PrayerRowView: View {
    let row: PrayerRow
    let isCurrent: Bool
    var nameSize: CGFloat
    var timeSize: CGFloat

    var body: some View {
        HStack {
            PrayerNameText(name: row.name, size: nameSize)
            Spacer(minLength: 4)
            Text(Theme.time(row.date))
                .font(.system(size: timeSize).monospacedDigit())
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background {
            if isCurrent {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.secondaryBackground)
            }
        }
    }
}

private struct MediumPrayerView: View {
    let snapshot: PrayerSnapshot
    let status: PrayerStatus

    private var left: [PrayerRow] { Array(snapshot.rows.prefix(3)) }
    private var right: [PrayerRow] { Array(snapshot.rows.suffix(3)) }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(snapshot.date.formatted(date: .abbreviated, time: .omitted))
                Spacer()
                if let name = snapshot.locationName { Text(name) }
            }
            .font(.system(size: 13))
            .lineLimit(1)

            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 2) {
                    ForEach(left, id: \.name) { row in
                        PrayerRowView(row: row, isCurrent: row.name == status.current, nameSize: 16, timeSize: 16)
                    }
                }
                VStack(spacing: 2) {
                    ForEach(right, id: \.name) { row in
                        PrayerRowView(row: row, isCurrent: row.name == status.current, nameSize: 16, timeSize: 16)
                    }
                }
            }

            TimelineBar(snapshot: snapshot, dotSize: 8, sunSize: 14)
        }
    }
}

private struct LargePrayerView: View {
    let snapshot: PrayerSnapshot
    let status: PrayerStatus

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 2) {
                Text(snapshot.date.formatted(date: .long, time: .omitted))
                    .font(.system(size: 17))
                if let name = snapshot.locationName {
                    Text(name).font(.system(size: 15))
                }
            }

            VStack(spacing: 2) {
                ForEach(snapshot.rows, id: \.name) { row in
                    PrayerRowView(row: row, isCurrent: row.name == status.current, nameSize: 24, timeSize: 21)
                }
            }

            TimelineBar(snapshot: snapshot)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(status.next) in")
                        .font(.system(size: 13))
                    Countdown(from: snapshot.date, end: status.nextStart, size: 22)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("Qibla")
                        .font(.system(size: 13))
                    Text("\(Theme.degrees(snapshot.qiblaBearing)) \(Qibla.compassPoint(for: snapshot.qiblaBearing))")
                        .font(.system(size: 22).monospacedDigit())
                }
                Image(systemName: "arrow.up")
                    .font(.system(size: 30, weight: .bold))
                    .rotationEffect(.degrees(snapshot.qiblaBearing))
            }
        }
    }
}
