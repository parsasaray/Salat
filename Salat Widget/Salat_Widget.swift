//
//  Salat_Widget.swift
//  Salat Widget
//
//  Created by Parsa Saraydarpour on 2/17/24.
//

import WidgetKit
import SwiftUI
import CoreLocation

// MARK: - The Timeline Entry
struct WidgetEntry: TimelineEntry {
    let date: Date
    let currentSalat: String
    let nextSalat: String
    let timeGlyph: String
}

// MARK: - The Widget View
struct WidgetView : View {
    let entry: WidgetEntry
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground().cornerRadius(10)
            VStack {
                HStack {
                    Image(systemName: entry.timeGlyph)
                    Text(entry.currentSalat).font(.system(size: 20, weight: .heavy))
                }
                Text(entry.nextSalat).font(.system(size: 14))
            }
        }
    }
}

// MARK: - The Timeline Provider
struct WidgetTimelineProvider: TimelineProvider {
    let locationManager = LocationManager()
    
    func placeholder(in context: Context) -> WidgetEntry {
        return WidgetEntry(date: Date(), currentSalat: "Current Salat", nextSalat: "Next Salat", timeGlyph: "sun.max.fill")
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> ()) {
        let entry = WidgetEntry(date: Date(), currentSalat: "Current Salat", nextSalat: "Next Salat", timeGlyph: "sun.max.fill")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> ()) {
        locationManager.onUpdateLocation = { currentSalat, nextSalat, nextSalatTime in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "h:mm"
            let nextTimeString = dateFormatter.string(from: nextSalatTime)
            
            let timeGlyphs = ["Dawn": "moon.stars", "Sunrise": "sunrise.fill", "Noon": "sun.max.fill", "Afternoon": "sun.min.fill", "Sunset": "sunset.fill", "Night": "moon.fill"]
            let timeGlyph = timeGlyphs[currentSalat]!
            
            let entry = WidgetEntry(date: Date(), currentSalat: currentSalat, nextSalat: "\(nextSalat) - \(nextTimeString)", timeGlyph: timeGlyph)
            let timeline = Timeline(entries: [entry], policy: .after(nextSalatTime))
            completion(timeline)
        }
    }
}

// MARK: - The Widget Configuration
@main struct SalatWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.parsasaray.Salat.Salat-Widget", provider: WidgetTimelineProvider()) { entry in
            WidgetView(entry: entry)
        }
        .configurationDisplayName("Salat Widget")
        .description("Show Salat times in a widget.")
        .supportedFamilies([
            .accessoryRectangular,
            .systemSmall
        ])
    }
}

class LocationManager: NSObject, CLLocationManagerDelegate {
    let locationManager = CLLocationManager()
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    var onUpdateLocation:((String, String, Date) -> Void)?
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let desiredLocation = locations.last?.coordinate else {return}
        let salatTimes = SalatTimes().getTimes(date: Date(), lat: desiredLocation.latitude, lng: desiredLocation.longitude)
        guard let currentSalat = SalatTimes().currentTime(times: salatTimes) else {return}
        guard let nextSalat = SalatTimes().nextTime(times: salatTimes) else {return}
        guard let nextSalatTimes = salatTimes[nextSalat] else {return}
        onUpdateLocation?(currentSalat, nextSalat, nextSalatTimes)
    }
}
