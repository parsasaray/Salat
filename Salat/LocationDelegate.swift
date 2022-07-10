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
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        desiredLocation = locations.last?.coordinate ?? CLLocationCoordinate2D(latitude: 0.0000, longitude: 0.0000)
        desiredTimeZone = TimeZone.current
        sunTimes = SunTimes().getTimes(date: desiredDate, lat: desiredLocation.latitude, lng: desiredLocation.longitude)
        setkaabaBearing()
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = desiredLocation
        locationPicker.addAnnotation(annotation)
        
        let numberFormatter = NumberFormatter()
        numberFormatter.usesSignificantDigits = true
        numberFormatter.maximumSignificantDigits = 4
        if let angle = numberFormatter.string(for: kaabaBearing.degrees) {
            angleLabel.text = angle + "°"
        }
        
        salatTableView.dataSource = tableDataSource
        salatTableView.reloadData()
        
        setLocationName()
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
            if kaabaDirection > 0 || kaabaDirection < -.pi {
                angleLabel.transform = CGAffineTransform(rotationAngle: kaabaDirection - .pi/2)
            } else {
                angleLabel.transform = CGAffineTransform(rotationAngle: kaabaDirection + .pi/2)
            }
        })
    }
    
    func setkaabaBearing() {
        let distABx = pow((90 - desiredLocation.latitude), 2)
        let distACx = pow((90 - kaabaLocation.latitude), 2)
        let distBCx = pow((desiredLocation.latitude - kaabaLocation.latitude), 2)
        
        let distABy = pow((desiredLocation.longitude - desiredLocation.longitude), 2)
        let distACy = pow((desiredLocation.longitude - kaabaLocation.longitude), 2)
        let distBCy = pow((desiredLocation.longitude - kaabaLocation.longitude), 2)

        let e = (distABx + distABy + distBCx + distBCy - distACx - distACy)
        let f = (2 * sqrt(distABx + distABy) * sqrt(distBCx + distBCy))
        kaabaBearing = acos(e / f)
    }
    
    func setLocationName() {
        CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: desiredLocation.latitude, longitude: desiredLocation.longitude)) { (placemarks, error) in
            var location = String()
            if let place = placemarks?[0] {
                desiredTimeZone = place.timeZone
                if let city = place.locality { location += city + ", " }
                if let area = place.administrativeArea { location += area + " "}
                if let country = place.isoCountryCode { location += country}
                setLocationButton.setTitle(location, for: .normal)
            }
        }
    }
}
