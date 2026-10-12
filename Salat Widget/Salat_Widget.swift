//
//  Salat_Widget.swift
//  Salat Widget
//
//  Created by Parsa Saraydarpour on 2/17/24.
//

import WidgetKit
import SwiftUI

// MARK: - The Timeline Entry
struct PrayerEntry: TimelineEntry {
    let snapshot: PrayerSnapshot
    var date: Date { snapshot.date }
}

// MARK: - The Timeline Provider
// The app saves its location to the shared App Group; the widget only reads it, then
// computes every prayer change for the next day or so. WidgetKit flips between the
// entries on its own, so nothing here needs to run again until the timeline ends.
struct PrayerProvider: TimelineProvider {
    private static let sampleLocation = SharedLocation(latitude: 37.7749, longitude: -122.4194,
                                                       name: "San Francisco, CA US", updatedAt: Date())

    private func sampleEntry() -> PrayerEntry {
        let snapshot = PrayerSchedule.timeline(for: Self.sampleLocation, now: Date()).first
        return PrayerEntry(snapshot: snapshot ?? .needsLocation(at: Date()))
    }

    func placeholder(in context: Context) -> PrayerEntry {
        sampleEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> ()) {
        guard let location = SharedLocationStore.load() else {
            completion(context.isPreview ? sampleEntry() : PrayerEntry(snapshot: .needsLocation(at: Date(), appGroupMissing: !SharedLocationStore.isGroupAvailable)))
            return
        }
        let snapshot = PrayerSchedule.timeline(for: location, now: Date()).first
        completion(PrayerEntry(snapshot: snapshot ?? .needsLocation(at: Date())))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> ()) {
        let now = Date()
        guard let location = SharedLocationStore.load() else {
            // The app reloads widgets as soon as it has a location; this is just a safety net
            let entry = PrayerEntry(snapshot: .needsLocation(at: now, appGroupMissing: !SharedLocationStore.isGroupAvailable))
            completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(15 * 60))))
            return
        }
        let entries = PrayerSchedule.timeline(for: location, now: now).map { PrayerEntry(snapshot: $0) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - The Widget Configurations
struct PrayerWidget: Widget {
    // Unchanged so widgets people already placed keep working
    let kind = "com.parsasaray.Salat.Salat-Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerProvider()) { entry in
            PrayerWidgetView(entry: entry)
        }
        .configurationDisplayName("Prayer Times")
        .description("The current prayer, what is next, and the day's times.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline
        ])
    }
}

struct QiblaWidget: Widget {
    let kind = "com.parsasaray.Salat.Qibla"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerProvider()) { entry in
            QiblaWidgetView(entry: entry)
        }
        .configurationDisplayName("Qibla")
        .description("The direction of the Qibla from where you are.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryInline
        ])
    }
}

@main struct SalatWidgets: WidgetBundle {
    var body: some Widget {
        PrayerWidget()
        QiblaWidget()
    }
}
