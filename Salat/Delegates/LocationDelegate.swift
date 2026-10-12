//
//  LocationManager.swift
//  Salat
//
//  Created by Parsa Saraydarpour on 1/11/22.
//

import CoreLocation
import MapKit

class LocationDelegate: NSObject, CLLocationManagerDelegate {
    static let shared = LocationDelegate()
    private let locationManager = CLLocationManager()
    private(set) var currentLocation: CLLocation?
    private(set) var currentTimeZone: TimeZone?
    private var kaabaBearing = CLLocationDirection()
    
    var setLocationName: ((String) -> Void)?
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
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.headingOrientation = .portrait
            locationManager.startMonitoringSignificantLocationChanges()
            locationManager.startUpdatingHeading()
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
    
    // Asks for a fresh location, used when the app returns to the foreground because
    // significant location changes are not delivered reliably while the app is closed
    func refreshLocation() {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        default:
            break
        }
    }
    
    // A one-time location request can fail (e.g. no signal); the previous location stays on screen
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    }
    
    // Updates the View when Device's location significantly changes
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
        currentTimeZone = TimeZone.current
        
        findkaabaBearing()
        findLocationName()
    }
    
    // Updates the View when Device is rotated
    func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
        // A negative heading means the compass has no valid reading yet
        guard heading.trueHeading >= 0 else { return }
        
        let kaabaDirection = kaabaBearing - heading.trueHeading.radians
        if kaabaDirection.wrappedToHalfTurn.degrees.rounded() == 0 {
            UIImpactFeedbackGenerator().impactOccurred()
        } else {
            UISelectionFeedbackGenerator().selectionChanged()
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
            self.setLocationName?("\(lat)°, \(lon)°")
            
            CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: coord.latitude, longitude: coord.longitude)) { (placemarks, error) in
                var locationStr = ""
                if let place = placemarks?.first {
                    if let city = place.locality { locationStr += city + ", " }
                    if let area = place.administrativeArea { locationStr += area + " "}
                    if let country = place.isoCountryCode { locationStr += country}
                }
                guard !locationStr.isEmpty else { return }
                self.setLocationName?(locationStr)
            }
            self.onDataShouldReload?()
        }
    }
}
