//
//  HeaderPillView.swift
//  Salat
//
//  The date, the app's glyph and the location as one three-way selector. The glyph is "home"
//  (the prayer times); the date and location open their panels. A side that has to be
//  shortened to fit grows to its full text while it is selected.
//

import UIKit

class HeaderPillView: UIView {
    enum Selection { case date, home, location }

    static let height: CGFloat = 48

    let dateButton = UIButton(type: .custom)
    let homeButton = UIButton(type: .custom)
    let locationButton = UIButton(type: .custom)

    private(set) var selection: Selection = .home

    private let highlight = UIView()
    private var dateVariants: [String] = []
    private var locationVariants: [String] = []

    private static let padding: CGFloat = 4
    private static let gap: CGFloat = 4
    private static let homeWidth: CGFloat = 52
    private static let textInset: CGFloat = 12
    private static let glyphSize: CGFloat = 26
    private static let font = UIFont.systemFont(ofSize: 16, weight: .medium)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(named: "Pill Background")

        highlight.backgroundColor = UIColor(named: "Secondary Background")
        highlight.layer.borderWidth = 1
        highlight.layer.borderColor = UIColor.ink.withAlphaComponent(0.18).cgColor
        highlight.isUserInteractionEnabled = false
        addSubview(highlight)

        for button in [dateButton, locationButton] {
            button.titleLabel?.font = HeaderPillView.font
            button.titleLabel?.lineBreakMode = .byTruncatingTail
            addSubview(button)
        }
        dateButton.accessibilityLabel = "Date"
        locationButton.accessibilityLabel = "Location"

        homeButton.setImage(HeaderPillView.glyphImage(), for: .normal)
        homeButton.accessibilityLabel = "Prayer times"
        addSubview(homeButton)

        applyColors()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: HeaderPillView.height)
    }

    // MARK: Content

    /// The longest form first: the full month, the short month, then all digits
    func setDate(_ date: Date) {
        dateVariants = [date.formatted(date: .long, time: .omitted),
                        date.formatted(date: .abbreviated, time: .omitted),
                        date.formatted(date: .numeric, time: .omitted)]
        setNeedsLayout()
    }

    /// The longest form first, each one shorter than the one before
    func setLocation(_ variants: [String]) {
        locationVariants = variants
        setNeedsLayout()
    }

    func setSelection(_ newSelection: Selection, animated: Bool) {
        guard newSelection != selection else { return }
        selection = newSelection
        applyColors()
        setNeedsLayout()
        guard animated else { return }
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.4,
                       options: [.allowUserInteraction]) {
            self.layoutIfNeeded()
        }
    }

    // MARK: Layout

    private static func width(of text: String) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width) + 2 * textInset
    }

    // The first form that fits, or the shortest one (which then truncates with an ellipsis)
    private static func fitting(_ variants: [String], in width: CGFloat) -> String {
        variants.first { self.width(of: $0) <= width } ?? variants.last ?? ""
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let p = HeaderPillView.padding, g = HeaderPillView.gap, mid = HeaderPillView.homeWidth
        let height = bounds.height - 2 * p
        let sides = bounds.width - 2 * p - 2 * g - mid
        guard sides > 0, height > 0 else { return }

        // Equal sides, unless the selected one is truncated: then it takes what its full text
        // needs, down to the least the other side can be shortened to
        var dateWidth = sides / 2
        var locationWidth = sides / 2
        func widen(_ variants: [String], otherVariants: [String]) -> (selected: CGFloat, other: CGFloat)? {
            guard let full = variants.first, let shortestOther = otherVariants.last else { return nil }
            let need = HeaderPillView.width(of: full)
            guard need > sides / 2 else { return nil }
            let minOther = min(HeaderPillView.width(of: shortestOther), sides / 2)
            let selected = min(need, sides - minOther)
            return (selected, sides - selected)
        }
        switch selection {
        case .date:
            if let w = widen(dateVariants, otherVariants: locationVariants) { (dateWidth, locationWidth) = w }
        case .location:
            if let w = widen(locationVariants, otherVariants: dateVariants) { (locationWidth, dateWidth) = w }
        case .home:
            break
        }

        dateButton.frame = CGRect(x: p, y: p, width: dateWidth, height: height)
        homeButton.frame = CGRect(x: dateButton.frame.maxX + g, y: p, width: mid, height: height)
        locationButton.frame = CGRect(x: homeButton.frame.maxX + g, y: p, width: locationWidth, height: height)

        dateButton.setTitle(HeaderPillView.fitting(dateVariants, in: dateWidth), for: .normal)
        locationButton.setTitle(HeaderPillView.fitting(locationVariants, in: locationWidth), for: .normal)

        let selectedFrame: CGRect
        switch selection {
        case .date: selectedFrame = dateButton.frame
        case .home: selectedFrame = homeButton.frame
        case .location: selectedFrame = locationButton.frame
        }
        highlight.frame = selectedFrame
        highlight.layer.cornerRadius = height / 2
        layer.cornerRadius = bounds.height / 2
    }

    // MARK: Appearance

    // The selected segment's content is fully opaque, the others are a little dimmer
    private func applyColors() {
        let dim: CGFloat = 0.7
        dateButton.setTitleColor(UIColor.ink.withAlphaComponent(selection == .date ? 1 : dim), for: .normal)
        locationButton.setTitleColor(UIColor.ink.withAlphaComponent(selection == .location ? 1 : dim), for: .normal)
        homeButton.tintColor = UIColor.ink.withAlphaComponent(selection == .home ? 1 : dim)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        highlight.layer.borderColor = UIColor.ink.withAlphaComponent(0.18).cgColor
    }

    private static func glyphImage() -> UIImage? {
        guard let source = UIImage(named: "MosqueGlyph") else { return nil }
        let size = CGSize(width: glyphSize, height: glyphSize)
        return UIGraphicsImageRenderer(size: size).image { _ in
            source.draw(in: CGRect(origin: .zero, size: size))
        }.withRenderingMode(.alwaysTemplate)
    }
}
