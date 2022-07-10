//
//  ViewController.swift
//  Salat
//
//  Created by Parsa Saraydarpour on 4/10/21.
//

import UIKit
import CoreLocation
import MapKit

let salatTableView = UITableView(frame: .zero)
let compassImageView = UIImageView(frame: .zero)
let angleLabel = UILabel(frame: .zero)
let setLocationButton = UIButton(frame: .zero)
let locationPicker = MKMapView(frame: .zero)
let resetLocationButton = UIButton(frame: .zero)
let setDateButton = UIButton(frame: .zero)
let datePicker = UIDatePicker(frame: .zero)

let locationManager = CLLocationManager()

class ViewController: UIViewController {
    var datePickerTopAnchor: NSLayoutConstraint!
    var locationPickerTopAnchor: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor(named: "Background")
        
        salatTableView.register(UINib(nibName: "Cell", bundle: nil), forCellReuseIdentifier: "salatCell")
        salatTableView.isUserInteractionEnabled = false
        salatTableView.rowHeight = self.view.frame.height / 12
        salatTableView.separatorStyle = .none
        salatTableView.backgroundColor = .clear
        salatTableView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(salatTableView)
        NSLayoutConstraint.activate([
            salatTableView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            salatTableView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor, constant: -40),
            salatTableView.widthAnchor.constraint(equalTo: self.view.widthAnchor, multiplier: 0.75),
            salatTableView.heightAnchor.constraint(equalTo: self.view.heightAnchor, multiplier: 0.5)
        ])
        
        compassImageView.image = UIImage(systemName: "arrow.up")
        compassImageView.backgroundColor = UIColor(named: "Background")
        compassImageView.tintColor = .label
        compassImageView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(compassImageView)
        NSLayoutConstraint.activate([
            compassImageView.topAnchor.constraint(equalTo: salatTableView.bottomAnchor, constant: 10),
            compassImageView.centerXAnchor.constraint(equalTo: salatTableView.centerXAnchor),
            compassImageView.widthAnchor.constraint(equalTo: salatTableView.widthAnchor, multiplier: 0.5),
            compassImageView.heightAnchor.constraint(equalTo: salatTableView.widthAnchor, multiplier: 0.5)
        ])
        
        angleLabel.textColor = UIColor(named: "Background")
        angleLabel.textAlignment = .center
        angleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(angleLabel)
        NSLayoutConstraint.activate([
            angleLabel.centerXAnchor.constraint(equalTo: compassImageView.centerXAnchor),
            angleLabel.centerYAnchor.constraint(equalTo: compassImageView.centerYAnchor),
            angleLabel.widthAnchor.constraint(equalTo: compassImageView.widthAnchor)
        ])
        
        setLocationButton.translatesAutoresizingMaskIntoConstraints = false
        setLocationButton.setTitleColor(.label, for: .normal)
        setLocationButton.addTarget(self, action: #selector(pickLocation), for: .touchUpInside)
        self.view.addSubview(setLocationButton)
        NSLayoutConstraint.activate([
            setLocationButton.bottomAnchor.constraint(equalTo: salatTableView.topAnchor, constant: -30),
            setLocationButton.widthAnchor.constraint(equalTo: salatTableView.widthAnchor),
            setLocationButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor)
        ])
        
        locationPicker.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(locationPicked(_:))))
        locationPicker.layer.cornerRadius = 25
        locationPicker.clipsToBounds = true
        locationPicker.translatesAutoresizingMaskIntoConstraints = false
        locationPickerTopAnchor = locationPicker.topAnchor.constraint(equalTo: self.view.bottomAnchor)
        self.view.addSubview(locationPicker)
        NSLayoutConstraint.activate([
            locationPicker.widthAnchor.constraint(equalTo: salatTableView.widthAnchor),
            locationPicker.heightAnchor.constraint(equalTo: salatTableView.heightAnchor),
            locationPicker.centerXAnchor.constraint(equalTo: salatTableView.centerXAnchor),
            locationPickerTopAnchor
        ])
        
        setDateButton.translatesAutoresizingMaskIntoConstraints = false
        setDateButton.setTitleColor(.label, for: .normal)
        setDateButton.addTarget(self, action: #selector(pickDate), for: .touchUpInside)
        self.view.addSubview(setDateButton)
        NSLayoutConstraint.activate([
            setDateButton.bottomAnchor.constraint(equalTo: setLocationButton.topAnchor, constant: -20),
            setDateButton.widthAnchor.constraint(equalTo: salatTableView.widthAnchor),
            setDateButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor)
        ])
        
        datePicker.datePickerMode = UIDatePicker.Mode.date
        datePicker.preferredDatePickerStyle = .inline
        datePicker.backgroundColor = UIColor(named: "Secondary Background")
        datePicker.layoutMargins = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        datePicker.layer.cornerRadius = 25
        datePicker.clipsToBounds = true
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.addTarget(self, action: #selector(datePicked(_:)), for: UIControl.Event.valueChanged)
        datePickerTopAnchor = datePicker.topAnchor.constraint(equalTo: self.view.bottomAnchor)
        self.view.addSubview(datePicker)
        NSLayoutConstraint.activate([
            datePicker.widthAnchor.constraint(equalTo: salatTableView.widthAnchor),
            datePicker.heightAnchor.constraint(equalTo: salatTableView.heightAnchor),
            datePicker.centerXAnchor.constraint(equalTo: salatTableView.centerXAnchor),
            datePickerTopAnchor
        ])
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(false)
        
        locationManager.requestWhenInUseAuthorization()
        if locationManager.authorizationStatus == .authorizedWhenInUse {
            createResetLocationButton()
            locationManager.delegate = locationDelegate
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.headingOrientation = .portrait
            locationManager.startMonitoringSignificantLocationChanges()
            locationManager.startUpdatingHeading()
        } else {
            let dialogMessage = UIAlertController(title: "No Location Found", message: "Location is required to use this app.", preferredStyle: .alert)
            dialogMessage.addAction(UIAlertAction(title: "Select Location", style: .default, handler: { (action) -> Void in
                self.pickLocation()
            }))
            dialogMessage.addAction(UIAlertAction(title: "Enable Location", style: .default, handler: { (action) -> Void in
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            }))
            self.present(dialogMessage, animated: true, completion: nil)
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, YYYY"
        setDateButton.setTitle(dateFormatter.string(from: desiredDate), for: .normal)
    }
    
    func createResetLocationButton() {
        resetLocationButton.translatesAutoresizingMaskIntoConstraints = false
        resetLocationButton.clipsToBounds = true
        resetLocationButton.backgroundColor = UIColor(white: 0.8, alpha: 0.5)
        resetLocationButton.layer.cornerRadius = 5
        resetLocationButton.setTitle("Reset", for: .normal)
        resetLocationButton.setTitleColor(.label, for: .normal)
        resetLocationButton.addTarget(self, action: #selector(resetLocation), for: .touchUpInside)
        locationPicker.addSubview(resetLocationButton)
        NSLayoutConstraint.activate([
            resetLocationButton.topAnchor.constraint(equalTo: locationPicker.topAnchor, constant: 10),
            resetLocationButton.leftAnchor.constraint(equalTo: locationPicker.leftAnchor, constant: 10)
        ])
    }
    
    @objc func resetLocation() {
        if locationManager.authorizationStatus == .authorizedWhenInUse {
            locationManager.startMonitoringSignificantLocationChanges()
        }
    }
    
    @objc func pickDate() {
        locationPickerTopAnchor.constant = 0
        if datePickerTopAnchor.constant == 0 {
            datePickerTopAnchor.constant = salatTableView.frame.origin.y - self.view.frame.height
        } else {
            datePickerTopAnchor.constant = 0
        }
        UIView.animate(withDuration: 0.75, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 1, options: .curveEaseOut, animations: {
            self.view.layoutIfNeeded()
        })
    }
    
    @objc func datePicked(_ sender: UIDatePicker) {
        desiredDate = sender.date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, YYYY"
        setDateButton.setTitle(dateFormatter.string(from: desiredDate), for: .normal)
        sunTimes = SunTimes().getTimes(date: desiredDate, lat: desiredLocation.latitude, lng: desiredLocation.longitude)
        salatTableView.reloadData()
    }
    
    @objc func pickLocation() {
        datePickerTopAnchor.constant = 0
        if locationPickerTopAnchor.constant == 0 {
            locationPickerTopAnchor.constant = salatTableView.frame.origin.y - self.view.frame.height
        } else {
            locationPickerTopAnchor.constant = 0
        }
        UIView.animate(withDuration: 0.75, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 1, options: .curveEaseOut, animations: {
            self.view.layoutIfNeeded()
        })
    }
    
    @objc func locationPicked(_ gesture: UIGestureRecognizer) {
        let touchPoint = gesture.location(in: locationPicker)
        let touchCoords = locationPicker.convert(touchPoint, toCoordinateFrom: locationPicker)
        desiredLocation = CLLocationCoordinate2D(latitude: touchCoords.latitude, longitude: touchCoords.longitude)
        
        locationDelegate.setkaabaBearing()
        locationDelegate.setLocationName()
        let numberFormatter = NumberFormatter()
        numberFormatter.usesSignificantDigits = true
        numberFormatter.maximumSignificantDigits = 4
        if let angle = numberFormatter.string(for: kaabaBearing.degrees) {
            angleLabel.text = angle + "°"
        }
        
        
        locationPicker.removeAnnotations(locationPicker.annotations)
        let annotation = MKPointAnnotation()
        annotation.coordinate = desiredLocation
        locationPicker.addAnnotation(annotation)
        
        sunTimes = SunTimes().getTimes(date: desiredDate, lat: desiredLocation.latitude, lng: desiredLocation.longitude)
        salatTableView.reloadData()
    }
}

extension Double {
    var radians: Self { return self * Double.pi / 180 }
    var degrees: Self { return self * 180 / Double.pi }
}

