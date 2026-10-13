//
//  PrayerStatusView.swift
//  Salat
//
//  The small widget's content: the prayer in effect and a countdown to the one after it.
//

import UIKit

class PrayerStatusView: UIView {
    private let currentGlyph = UIImageView()
    private let currentName = UILabel()
    private let nextGlyph = UIImageView()
    private let nextLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        currentName.font = .systemFont(ofSize: 32, weight: .semibold)
        currentGlyph.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        nextLabel.font = .monospacedDigitSystemFont(ofSize: 19, weight: .semibold)
        nextGlyph.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)

        let current = UIStackView(arrangedSubviews: [currentGlyph, currentName])
        current.spacing = 6
        let next = UIStackView(arrangedSubviews: [nextGlyph, nextLabel])
        next.spacing = 5
        for row in [current, next] {
            row.alignment = .center
        }
        let stack = UIStackView(arrangedSubviews: [current, next])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        isUserInteractionEnabled = false
        update(status: nil, now: Date())
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// `status` is nil while there is no location. The countdown always runs to the real next prayer.
    func update(status: PrayerStatus?, now: Date) {
        guard let status = status, status.nextStart > now else {
            currentGlyph.image = nil
            currentName.text = " "
            nextGlyph.image = nil
            nextLabel.text = " "
            return
        }
        let currentColor = UIColor(named: status.current) ?? .ink
        currentGlyph.image = UIImage(systemName: PrayerSchedule.glyph(for: status.current))
        currentGlyph.tintColor = currentColor
        currentName.text = status.current
        currentName.textColor = currentColor

        let nextColor = UIColor(named: status.next) ?? .ink
        nextGlyph.image = UIImage(systemName: PrayerSchedule.glyph(for: status.next))
        nextGlyph.tintColor = nextColor
        let seconds = Int(status.nextStart.timeIntervalSince(now).rounded(.up))
        let remaining = String(format: "%d:%02d:%02d", seconds / 3600, seconds % 3600 / 60, seconds % 60)
        nextLabel.text = "\(status.next) in \(remaining)"
        nextLabel.textColor = nextColor
    }
}
