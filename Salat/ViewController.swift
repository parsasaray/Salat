//
//  ViewController.swift
//  Salat
//
//  Created by Parsa Saraydarpour on 4/10/21.
//

import UIKit
import CoreLocation

let salatTableView = UITableView(frame: .zero)
let compassImageView = UIImageView(frame: .zero)
let locationTextField = UITextField(frame: .zero)

let locationManager = CLLocationManager()

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        salatTableView.translatesAutoresizingMaskIntoConstraints = false
        salatTableView.register(UINib(nibName: "Cell", bundle: nil), forCellReuseIdentifier: "salatCell")
        salatTableView.isUserInteractionEnabled = false
        salatTableView.separatorStyle = .none
        salatTableView.rowHeight = UIScreen.main.bounds.height/12
        self.view.addSubview(salatTableView)
        
        NSLayoutConstraint.activate([
            salatTableView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            salatTableView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor, constant: -50),
            salatTableView.widthAnchor.constraint(equalTo: self.view.widthAnchor, multiplier: 0.9),
            salatTableView.heightAnchor.constraint(equalTo: self.view.heightAnchor, multiplier: 0.5)
        ])
        
        compassImageView.translatesAutoresizingMaskIntoConstraints = false
        compassImageView.image = UIImage(systemName: "arrow.up")
        compassImageView.tintColor = .label
        self.view.addSubview(compassImageView)
        
        NSLayoutConstraint.activate([
            compassImageView.topAnchor.constraint(equalTo: salatTableView.bottomAnchor, constant: 20),
            compassImageView.centerXAnchor.constraint(equalTo: salatTableView.centerXAnchor),
            compassImageView.widthAnchor.constraint(equalTo: salatTableView.widthAnchor, multiplier: 0.5),
            compassImageView.heightAnchor.constraint(equalTo: salatTableView.widthAnchor, multiplier: 0.5)
        ])
        
        locationTextField.translatesAutoresizingMaskIntoConstraints = false
        locationTextField.isUserInteractionEnabled = false
        locationTextField.textAlignment = .center
        self.view.addSubview(locationTextField)
        
        NSLayoutConstraint.activate([
            locationTextField.bottomAnchor.constraint(equalTo: salatTableView.topAnchor, constant: -20),
            locationTextField.widthAnchor.constraint(equalTo: salatTableView.widthAnchor)
        ])
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(false)
        
        locationManager.requestWhenInUseAuthorization()
        if locationManager.authorizationStatus == .authorizedWhenInUse {
            locationManager.delegate = locationDelegate
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.headingOrientation = .portrait
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
        } else {
            self.view.isHidden = true
            let dialogMessage = UIAlertController(title: "No Location Found", message: "Location is required to use this app.", preferredStyle: .alert)
            dialogMessage.addAction(UIAlertAction(title: "Select Location", style: .default, handler: { (action) -> Void in
                print("location selector")
            }))
            dialogMessage.addAction(UIAlertAction(title: "Enable Location", style: .default, handler: { (action) -> Void in
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            }))
            self.present(dialogMessage, animated: true, completion: nil)
        }
    }
}

extension Double {
    var radians: Self { return self * Double.pi / 180 }
    var degrees: Self { return self * 180 / Double.pi }
}

