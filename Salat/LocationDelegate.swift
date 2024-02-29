//
//  LocationManager.swift
//  Salat
//
//  Created by Parsa Saraydarpour on 1/11/22.
//

import CoreLocation
import MapKit

let locationDelegate = LocationDelegate()

var desiredDate = Date()
var desiredLocation = CLLocationCoordinate2D()
var desiredTimeZone = TimeZone(identifier: "UTC")
let kaabaLocation = CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)
var kaabaBearing = CLLocationDirection()

class LocationDelegate: NSObject, CLLocationManagerDelegate {
    
    // Checks if the user allows location
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        // Asks for location permission
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        // Starts using location data
        case .authorizedAlways, .authorizedWhenInUse:
            Salat.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            Salat.locationManager.headingOrientation = .portrait
            Salat.locationManager.startMonitoringSignificantLocationChanges()
            Salat.locationManager.startUpdatingHeading()
        // Displays a popup explaining that location is disabled
        case .restricted, .denied:
            let dialogMessage = UIAlertController(title: "No Location Found", message: "Location is required to use this app.", preferredStyle: .alert)
            dialogMessage.addAction(UIAlertAction(title: "Select Location", style: .default, handler: { (action) -> Void in
                ViewController().pickLocation()
            }))
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
        desiredLocation = locations.last?.coordinate ?? CLLocationCoordinate2D(latitude: 0.0000, longitude: 0.0000)
        desiredTimeZone = TimeZone.current
        
        setkaabaBearing() {
            let numberFormatter = NumberFormatter()
            numberFormatter.usesSignificantDigits = true
            numberFormatter.maximumSignificantDigits = 4
            if let angle = numberFormatter.string(for: kaabaBearing.degrees) {
                angleLabel.text = angle + "°"
            }
        }
        
        setLocationName() {
            locationPicker.removeAnnotations(locationPicker.annotations)
            let annotation = MKPointAnnotation()
            annotation.coordinate = desiredLocation
            locationPicker.addAnnotation(annotation)
            salatTableView.reloadData()
            timelineView.setNeedsDisplay()
        }
    }
    
    // Updates the View when Device is rotated
    func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
        let kaabaDirection = kaabaBearing - heading.trueHeading.radians
        if kaabaDirection.degrees.rounded() == 0 {
            UIImpactFeedbackGenerator().impactOccurred()
        } else {
            UISelectionFeedbackGenerator().selectionChanged()
        }
        
        UIView.animate(withDuration: 0.1, animations: {
            compassImageView.transform = CGAffineTransform(rotationAngle: kaabaDirection)
            if kaabaDirection > 0 || kaabaDirection < -.pi {
                angleLabel.transform = CGAffineTransform(rotationAngle: kaabaDirection - .pi/2)
            } else {
                angleLabel.transform = CGAffineTransform(rotationAngle: kaabaDirection + .pi/2)
            }
        })
    }
    
    // Calculates and Sets the bearing for the Kaaba to be displayed
    func setkaabaBearing(completion: () -> Void) {
        // Point A is a point at the North Pole sharing the exact same Longitude as Point B
        // Point B is the current location of the user
        // Point C is the location of the Kaaba
        // Together, these points create a ray with the vertex at B and each line towards A and C which we can calculate the angle from.
        // https://stackoverflow.com/questions/1211212/how-to-calculate-an-angle-from-three-points
        
        let distAB = pow((90 - desiredLocation.latitude), 2) + pow((desiredLocation.longitude - desiredLocation.longitude), 2)
        let distBC = pow((desiredLocation.latitude - kaabaLocation.latitude), 2) + pow((desiredLocation.longitude - kaabaLocation.longitude), 2)
        let distAC = pow((90 - kaabaLocation.latitude), 2) + pow((desiredLocation.longitude - kaabaLocation.longitude), 2)

        kaabaBearing = acos((distAB + distBC - distAC) / (2 * sqrt(distAB) * sqrt(distBC)))
        completion()
    }
    
    // Finds location name from coordinates using Apples API
    func setLocationName(completion: @escaping () -> Void) {
        CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: desiredLocation.latitude, longitude: desiredLocation.longitude)) { (placemarks, error) in
            var location = String()
            if let place = placemarks?[0] {
                desiredTimeZone = place.timeZone
                if let city = place.locality { location += city + ", " }
                if let area = place.administrativeArea { location += area + " "}
                if let country = place.isoCountryCode { location += country}
                if location != "" {
                    setLocationButton.setTitle(location, for: .normal)
                } else {
                    let numberFormatter = NumberFormatter()
                    numberFormatter.usesSignificantDigits = true
                    numberFormatter.maximumSignificantDigits = 6
                    if let latitude = numberFormatter.string(for: desiredLocation.latitude),
                       let longitude = numberFormatter.string(for: desiredLocation.longitude) {
                        setLocationButton.setTitle("\(latitude)°, \(longitude)°", for: .normal)
                    }
                }
            }
            completion()
        }
    }
}
