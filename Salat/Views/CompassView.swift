//
//  CompassView.swift
//  Salat
//
//  Created by Parsa Saraydarpour on 1/29/26.
//

import UIKit

class CompassView: UIView {
    private let compassImageView = UIImageView()
    private let angleLabel = UILabel()
    
    override func draw(_ rect: CGRect) {
        compassImageView.image = UIImage(systemName: "arrow.up")
        compassImageView.backgroundColor = .clear
        compassImageView.tintColor = .label
        compassImageView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(compassImageView)
        
        angleLabel.textColor = UIColor(named: "Background")
        angleLabel.textAlignment = .center
        angleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(angleLabel)
        
        NSLayoutConstraint.activate([
            angleLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            angleLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            angleLabel.widthAnchor.constraint(equalTo: self.widthAnchor),
            compassImageView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            compassImageView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            compassImageView.widthAnchor.constraint(equalTo: self.widthAnchor),
            compassImageView.heightAnchor.constraint(equalTo: self.heightAnchor)
        ])
        
        let loc = LocationDelegate.shared
        loc.setKaabaBearing = { [weak self] bearing in
            let numberFormatter = NumberFormatter()
            numberFormatter.usesSignificantDigits = true
            numberFormatter.maximumSignificantDigits = 4
            if let angle = numberFormatter.string(for: bearing) {
                self?.angleLabel.text = angle + "°"
            }
        }
        loc.onCompassRotation = { [weak self] direction in
            UIView.animate(withDuration: 0.1, animations: { [self] in
                self?.compassImageView.transform = CGAffineTransform(rotationAngle: direction)
                if direction > 0 || direction < -.pi {
                    self?.angleLabel.transform = CGAffineTransform(rotationAngle: direction - .pi/2)
                } else {
                    self?.angleLabel.transform = CGAffineTransform(rotationAngle: direction + .pi/2)
                }
            })
        }
    }
}
