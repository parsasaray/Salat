//
//  LocationManager.swift
//  Salat
//
//  Created by Parsa Saraydarpour on 1/11/22.
//

import CoreLocation
import MapKit

let locationDelegate = LocationDelegate()
var currentLocation = CLLocationCoordinate2D()
let kaabaLocation = CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)
var kaabaBearing = CLLocationDirection()

class LocationDelegate: NSObject, CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last?.coordinate ?? CLLocationCoordinate2D(latitude: 0.0000, longitude: 0.0000)
        sunTimes = SunTimes().getTimes(date: Date(), lat: currentLocation.latitude, lng: currentLocation.longitude)
        
        let lat1 = currentLocation.latitude.radians
        let lon1 = currentLocation.longitude.radians

        let lat2 = kaabaLocation.latitude.radians
        let lon2 = kaabaLocation.longitude.radians

        let y = sin(lon2 - lon1) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(lon2 - lon1)
        kaabaBearing = atan2(y, x) + (Double.pi / 2)
        
        salatTableView.dataSource = tableDataSource
        salatTableView.reloadData()
        
        let address = CLGeocoder()
        address.reverseGeocodeLocation(CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)) { (placemarks, error) in
            guard let place = placemarks?[0] else { return }
            if let country = place.country, let state = place.administrativeArea, let town = place.locality {
                let location = "\(town), \(state) \(country)"
                locationTextField.text = location
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
        let kaabaDirection = kaabaBearing - heading.trueHeading.radians
        if kaabaDirection.degrees.rounded() == 0 {
            UIImpactFeedbackGenerator().impactOccurred()
        } else {
            UISelectionFeedbackGenerator().selectionChanged()
        }
        
        UIView.animate(withDuration: 0.1, animations: {
            compassImageView.transform = CGAffineTransform(rotationAngle: kaabaDirection)
        })
    }
}
