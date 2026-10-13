//
//  CompassView.swift
//  Salat
//
//  Created by Parsa Saraydarpour on 1/29/26.
//

import UIKit

class CompassView: UIView {
    /// The symbol has built-in padding: how far the visible arrow ends sit inside the view's top
    /// and bottom, as a fraction of its height
    static let arrowInsetRatio: CGFloat = 0.063
    /// Its bottom edge is where the arrow visibly begins
    let arrowTopInset = UILayoutGuide()
    /// Its top edge is where the arrow visibly ends
    let arrowBottomInset = UILayoutGuide()
    
    private let compassImageView = UIImageView()
    private let angleLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addLayoutGuide(arrowTopInset)
        addLayoutGuide(arrowBottomInset)
        NSLayoutConstraint.activate([
            arrowTopInset.topAnchor.constraint(equalTo: topAnchor),
            arrowTopInset.heightAnchor.constraint(equalTo: heightAnchor, multiplier: CompassView.arrowInsetRatio),
            arrowBottomInset.bottomAnchor.constraint(equalTo: bottomAnchor),
            arrowBottomInset.heightAnchor.constraint(equalTo: heightAnchor, multiplier: CompassView.arrowInsetRatio)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
    
    override func draw(_ rect: CGRect) {
        // Looks the same on every device: always drawn the way Bold Text draws it, never heavier
        compassImageView.image = UIImage(systemName: "arrow.up")
        compassImageView.traitOverrides.legibilityWeight = .bold
        compassImageView.backgroundColor = .clear
        compassImageView.tintColor = .ink
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
                self?.angleLabel.transform = CGAffineTransform(rotationAngle: direction.readableLabelRotation)
            })
        }
    }
}
