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
            fatalError()
        }
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
        let kaabaDirection = kaabaBearing - heading.trueHeading.radians
        if kaabaDirection.degrees.rounded() == 0 {
            UIImpactFeedbackGenerator().impactOccurred()
        } else {
            UISelectionFeedbackGenerator().selectionChanged()
        }
        
        self.onCompassRotation?(kaabaDirection)
    }
    
    // Calculates and Sets the bearing for the Kaaba to be displayed
    func findkaabaBearing() {
        // Point A is a point at the North Pole sharing the exact same Longitude as Point B
        // Point B is the current location of the user
        // Point C is the location of the Kaaba
        // Together, these points create a ray with the vertex at B and each line towards A and C which we can calculate the angle from.
        // https://stackoverflow.com/questions/1211212/how-to-calculate-an-angle-from-three-points
        
        let kaabaLocation = CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)
        if let location = self.currentLocation {
            let coord = location.coordinate
            
            let distAB = pow((90 - coord.latitude), 2) + pow((coord.longitude - coord.longitude), 2)
            let distBC = pow((coord.latitude - kaabaLocation.latitude), 2) + pow((coord.longitude - kaabaLocation.longitude), 2)
            let distAC = pow((90 - kaabaLocation.latitude), 2) + pow((coord.longitude - kaabaLocation.longitude), 2)
            
            var angle: Double = acos((distAB + distBC - distAC) / (2 * sqrt(distAB) * sqrt(distBC)))
            
            // Kaaba is west -> angle should wrap clockwise from north (360° - angle)
            if kaabaLocation.longitude < coord.longitude {
                angle = 2 * .pi - angle
            }
            
            kaabaBearing = angle
            self.setKaabaBearing?(kaabaBearing.degrees)
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
                if let place = placemarks?[0] {
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
