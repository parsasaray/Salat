//
//  LocationManager.swift
//  Salat
//
//  Created by Parsa Saraydarpour on 1/11/22.
//

import CoreLocation
import MapKit
import WidgetKit

class LocationDelegate: NSObject, CLLocationManagerDelegate {
    static let shared = LocationDelegate()
    private let locationManager = CLLocationManager()
    private(set) var currentLocation: CLLocation?
    private(set) var currentTimeZone: TimeZone?
    private var kaabaBearing = CLLocationDirection()
    private var locationName: String?
    // Where `locationName` was resolved, so it is never attached to a different place
    private var locationNameCoordinate: CLLocationCoordinate2D?

    /// The place's name from longest to shortest, so a narrow display can pick the one that fits
    var setLocationName: (([String]) -> Void)?
    var setKaabaBearing: ((Double) -> Void)?
    var onCompassRotation: ((Double) -> Void)?
    var onDataShouldReload: (() -> Void)?
    
    override init() {
        super.init()
        locationManager.delegate = self
    }
    
    // Checks if the user allows location
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        // Asks for location permission
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        // Starts using location data
        case .authorizedAlways, .authorizedWhenInUse:
            // Prayer times and Qibla only need a rough position, so keep this cheap
            locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
            locationManager.distanceFilter = 1000
            locationManager.headingOrientation = .portrait
            locationManager.startMonitoringSignificantLocationChanges()
            locationManager.startUpdatingHeading()
            startForegroundUpdates()
        // Displays a popup explaining that location is disabled
        case .restricted, .denied:
            let dialogMessage = UIAlertController(title: "No Location Found", message: "Location is required to use this app.", preferredStyle: .alert)
            dialogMessage.addAction(UIAlertAction(title: "Enable Location", style: .default, handler: { (action) -> Void in
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            }))
            mainWindow?.rootViewController?.present(dialogMessage, animated: true, completion: nil)
        @unknown default:
            break
        }
    }
    
    // True heading (needed to point at the Qibla) is only valid while location updates are
    // running, and significant location changes alone are not delivered reliably. So location
    // updates run whenever the app is on screen, which also gives a fresh location on return.
    func startForegroundUpdates() {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
        default:
            break
        }
    }
    
    func stopForegroundUpdates() {
        locationManager.stopUpdatingLocation()
    }
    
    // Location can be briefly unavailable (e.g. no signal); the previous location stays on screen
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    }
    
    // Updates the View when Device's location changes
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
        currentTimeZone = TimeZone.current
        
        findkaabaBearing()
        findLocationName()
        
        // The heading only reports changes, so a phone held still would keep showing the
        // arrow from before this location (or before true heading was available).
        if let heading = manager.heading {
            updateCompass(with: heading, givingFeedback: false)
        }
    }
    
    // Updates the View when Device is rotated
    func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
        updateCompass(with: heading, givingFeedback: true)
    }
    
    private func updateCompass(with heading: CLHeading, givingFeedback: Bool) {
        // A negative heading means the compass has no valid reading yet
        guard heading.trueHeading >= 0 else { return }
        
        let kaabaDirection = kaabaBearing - heading.trueHeading.radians
        if givingFeedback {
            if kaabaDirection.wrappedToHalfTurn.degrees.rounded() == 0 {
                UIImpactFeedbackGenerator().impactOccurred()
            } else {
                UISelectionFeedbackGenerator().selectionChanged()
            }
        }
        
        self.onCompassRotation?(kaabaDirection)
    }
    
    // Calculates and Sets the bearing for the Kaaba to be displayed
    func findkaabaBearing() {
        if let coord = self.currentLocation?.coordinate {
            let bearing = Qibla.bearing(latitude: coord.latitude, longitude: coord.longitude)
            kaabaBearing = bearing.radians
            self.setKaabaBearing?(bearing)
        }
    }
    
    // Finds location name from coordinates using Apples API
    func findLocationName() {
        if let location = self.currentLocation {
            let coord = location.coordinate
            let nf = NumberFormatter()
            nf.usesSignificantDigits = true
            nf.maximumSignificantDigits = 6
            let lat = nf.string(for: coord.latitude) ?? "\(coord.latitude)"
            let lon = nf.string(for: coord.longitude) ?? "\(coord.longitude)"
            self.setLocationName?(["\(lat)°, \(lon)°"])
            
            CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: coord.latitude, longitude: coord.longitude)) { (placemarks, error) in
                var locationStr = ""
                var variants = [String]()
                if let place = placemarks?.first {
                    if let city = place.locality { locationStr += city + ", " }
                    if let area = place.administrativeArea { locationStr += area + " "}
                    if let country = place.isoCountryCode { locationStr += country}
                    // Shortened by dropping the country, then the state or province
                    let city = place.locality, area = place.administrativeArea
                    variants = [locationStr.trimmingCharacters(in: CharacterSet(charactersIn: ", ")),
                                [city, area].compactMap { $0 }.joined(separator: ", "),
                                city ?? area ?? ""]
                        .filter { !$0.isEmpty }
                        .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
                }
                guard !locationStr.isEmpty else { return }
                self.setLocationName?(variants)
                self.locationName = locationStr
                self.locationNameCoordinate = coord
                self.publishToWidgets()
            }
            self.onDataShouldReload?()
            self.publishToWidgets()
        }
    }
    
    // Shares the location with the widgets (they never ask for it themselves) and
    // refreshes them, but only when it changed enough to matter. `force` always writes
    // and refreshes, so a widget stuck on an old "Open Salat" recovers when the app opens.
    func publishToWidgets(force: Bool = false) {
        refreshReminders()
        guard let coord = currentLocation?.coordinate else { return }
        let location = SharedLocation(latitude: coord.latitude, longitude: coord.longitude, name: knownName(at: coord), updatedAt: Date())
        if !force, let saved = SharedLocationStore.load(),
           abs(saved.latitude - location.latitude) < 0.01,
           abs(saved.longitude - location.longitude) < 0.01,
           saved.name == location.name {
            return
        }
        SharedLocationStore.save(location)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // Keeps the prayer reminders in step with where the user is. This runs on every launch,
    // foreground and location change, which is what keeps the reminders from running out.
    // Before the first fix of a launch it replans from the last saved location instead.
    private func refreshReminders() {
        if let coord = currentLocation?.coordinate {
            ReminderScheduler.shared.reconcile(for: SharedLocation(latitude: coord.latitude, longitude: coord.longitude,
                                                                   name: knownName(at: coord), updatedAt: Date()))
        } else if let saved = SharedLocationStore.load() {
            ReminderScheduler.shared.reconcile(for: saved)
        }
    }
    
    // The city name resolves after the fix does, so it is only used for the place it was
    // resolved for. Falls back to the saved name for the same place (e.g. while offline), and
    // otherwise to nil rather than naming the wrong city.
    private func knownName(at coord: CLLocationCoordinate2D) -> String? {
        if let name = locationName, let at = locationNameCoordinate, isSamePlace(at, coord) {
            return name
        }
        if let saved = SharedLocationStore.load(),
           isSamePlace(CLLocationCoordinate2D(latitude: saved.latitude, longitude: saved.longitude), coord) {
            return saved.name
        }
        return nil
    }
    
    private func isSamePlace(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
        abs(a.latitude - b.latitude) < 0.01 && abs(a.longitude - b.longitude) < 0.01
    }
}
