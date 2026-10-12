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
        .containerBackground(.background, for: .widget)
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
        locationManager.requestLocation { coordinate in
            let timeGlyphs = ["Dawn": "moon.stars", "Sunrise": "sunrise.fill", "Noon": "sun.max.fill", "Afternoon": "sun.min.fill", "Sunset": "sunset.fill", "Night": "moon.fill"]
            
            guard let coordinate = coordinate,
                  let status = SalatTimes().status(lat: coordinate.latitude, lng: coordinate.longitude) else {
                // No location (or no usable times): show a hint and try again soon
                let entry = WidgetEntry(date: Date(), currentSalat: "Salat", nextSalat: "Location needed", timeGlyph: "location.slash")
                completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
                return
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "h:mm"
            let nextTimeString = dateFormatter.string(from: status.nextDate)
            
            let entry = WidgetEntry(date: Date(), currentSalat: status.current, nextSalat: "\(status.next) - \(nextTimeString)", timeGlyph: timeGlyphs[status.current] ?? "sun.max.fill")
            completion(Timeline(entries: [entry], policy: .after(status.nextDate)))
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
    private var pending: [(CLLocationCoordinate2D?) -> Void] = []
    
    override init() {
        super.init()
        locationManager.delegate = self
    }
    
    // Asks for a single location fix. `completion` is called exactly once, with nil on failure.
    func requestLocation(completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        pending.append(completion)
        if pending.count == 1 {
            locationManager.requestWhenInUseAuthorization()
            locationManager.requestLocation()
        }
    }
    
    private func finish(with coordinate: CLLocationCoordinate2D?) {
        let handlers = pending
        pending = []
        handlers.forEach { $0(coordinate) }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        finish(with: locations.last?.coordinate)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(with: nil)
    }
}
