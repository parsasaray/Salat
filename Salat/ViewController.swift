//
//  ViewController.swift
//  Salat
//
//  Created by Parsa Saraydarpour on 4/10/21.
//

import UIKit
import MapKit

class ViewController: UIViewController {
    // A card that slides up over the table: hidden below the screen, or shown in the table's place
    private struct SlidePanel {
        let view: UIView
        let hiddenTop: NSLayoutConstraint
        let shownTop: NSLayoutConstraint

        var isShown: Bool { shownTop.isActive }

        init(view: UIView, hiddenTop: NSLayoutConstraint, shownTop: NSLayoutConstraint) {
            self.view = view
            self.hiddenTop = hiddenTop
            self.shownTop = shownTop
        }

        // Deactivates before activating so the two constraints never conflict
        func setShown(_ shown: Bool) {
            if shown {
                hiddenTop.isActive = false
                shownTop.isActive = true
            } else {
                shownTop.isActive = false
                hiddenTop.isActive = true
            }
        }
    }

    // The prayer list is centered on the screen at this fraction of its width and height,
    // and everything else is laid out relative to that area
    private static let contentWidthRatio: CGFloat = 0.75
    private static let contentHeightRatio: CGFloat = 0.5
    private static let rowCount: CGFloat = 6
    // The prayer list sits this fraction of the screen's height above that centered area, which
    // the status block, timeline and compass keep their places relative to
    private static let tableRaiseRatio: CGFloat = 0.02
    // The date/location selector sits this far below the safe area's top and in from the sides
    private static let headerTopInset: CGFloat = 12
    private static let headerSideInset: CGFloat = 24

    private let tableView = UITableView()
    private let timelineView = TimelineView()
    private let compassView = CompassView()
    // A darker disc the timeline's arc rides on the rim of, with the compass sitting on it
    private let underlayView = UIView()
    private let headerPill = HeaderPillView()
    private let locView = MKMapView()
    private let dateSelector = UIDatePicker()
    private let statusView = PrayerStatusView()
    private let contentGuide = UILayoutGuide()

    private let tableDataSource = TableDataSource()
    private var locPanel: SlidePanel!
    private var datePanel: SlidePanel!
    // True until a date other than today is picked. While true, the app keeps showing today.
    private var followsToday = true
    // The prayer the countdown is running to. Recomputed only when it has passed or the place changed.
    private var currentStatus: PrayerStatus?

    // Adds all visual elements to the View
    override func viewDidLoad() {
        super.viewDidLoad()

        setUpContentGuide()
        setUpTable()
        setUpCompassAndTimeline()
        setUpHeader()
        setUpStatus()
        setUpPanels()
        bindLocation()
        startTimers()
    }

    // The prayer list's row height follows its final size, including after a size change
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutUnderlay()
        let rowHeight = tableView.bounds.height / ViewController.rowCount
        if rowHeight > 0 && tableView.rowHeight != rowHeight {
            tableView.rowHeight = rowHeight
        }
    }

    // MARK: Layout

    // The disc is concentric with the timeline's arc and larger by the underlay margin, so its
    // rim runs the same distance above the arc along its whole length
    private func layoutUnderlay() {
        let width = timelineView.bounds.width
        guard width > 0 else { return }
        let margin = TimelineView.underlayMargin
        let radius = TimelineView.arcRadius(forWidth: width) + margin
        let apex = timelineView.frame.minY + TimelineView.apexY
        underlayView.frame = CGRect(x: timelineView.frame.midX - radius, y: apex - margin,
                                    width: 2 * radius, height: 2 * radius)
        underlayView.layer.cornerRadius = radius
    }

    private func setUpContentGuide() {
        self.view.addLayoutGuide(contentGuide)
        NSLayoutConstraint.activate([
            contentGuide.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            contentGuide.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
            contentGuide.widthAnchor.constraint(equalTo: self.view.widthAnchor, multiplier: ViewController.contentWidthRatio),
            contentGuide.heightAnchor.constraint(equalTo: self.view.heightAnchor, multiplier: ViewController.contentHeightRatio)
        ])
    }

    private func setUpTable() {
        tableView.register(UINib(nibName: "Cell", bundle: nil), forCellReuseIdentifier: "salatCell")
        tableView.dataSource = tableDataSource
        tableView.isUserInteractionEnabled = false
        tableView.rowHeight = self.view.frame.height * ViewController.contentHeightRatio / ViewController.rowCount
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(tableView)
        let raise = UILayoutGuide()
        self.view.addLayoutGuide(raise)
        NSLayoutConstraint.activate([
            raise.bottomAnchor.constraint(equalTo: contentGuide.bottomAnchor),
            raise.heightAnchor.constraint(equalTo: self.view.heightAnchor, multiplier: ViewController.tableRaiseRatio),
            tableView.bottomAnchor.constraint(equalTo: raise.topAnchor),
            tableView.heightAnchor.constraint(equalTo: contentGuide.heightAnchor),
            tableView.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor)
        ])
    }

    private func setUpCompassAndTimeline() {
        compassView.translatesAutoresizingMaskIntoConstraints = false
        compassView.backgroundColor = .clear
        self.view.addSubview(compassView)
        NSLayoutConstraint.activate([
            compassView.centerXAnchor.constraint(equalTo: contentGuide.centerXAnchor),
            compassView.widthAnchor.constraint(equalTo: contentGuide.widthAnchor, multiplier: 0.5),
            compassView.heightAnchor.constraint(equalTo: contentGuide.widthAnchor, multiplier: 0.5)
        ])

        underlayView.backgroundColor = UIColor(named: "Tertiary Background")
        underlayView.isUserInteractionEnabled = false
        self.view.insertSubview(underlayView, belowSubview: compassView)

        timelineView.translatesAutoresizingMaskIntoConstraints = false
        timelineView.backgroundColor = .clear
        self.view.addSubview(timelineView)
        NSLayoutConstraint.activate([
            // The timeline arcs over the compass, so it starts above it
            timelineView.topAnchor.constraint(equalTo: compassView.topAnchor, constant: -TimelineView.compassTop),
            timelineView.centerXAnchor.constraint(equalTo: contentGuide.centerXAnchor),
            timelineView.widthAnchor.constraint(equalTo: contentGuide.widthAnchor),
            timelineView.heightAnchor.constraint(equalToConstant: TimelineView.height)
        ])

        // The table is centered on the screen. The timeline and compass hang below it, placed so
        // the timeline's apex is exactly halfway between the table's bottom edge and the arrow's
        // top edge, whatever the screen size
        let aboveApex = UILayoutGuide()
        let belowApex = UILayoutGuide()
        self.view.addLayoutGuide(aboveApex)
        self.view.addLayoutGuide(belowApex)
        NSLayoutConstraint.activate([
            aboveApex.topAnchor.constraint(equalTo: contentGuide.bottomAnchor),
            aboveApex.bottomAnchor.constraint(equalTo: belowApex.topAnchor),
            belowApex.topAnchor.constraint(equalTo: timelineView.topAnchor, constant: TimelineView.apexY),
            belowApex.bottomAnchor.constraint(equalTo: compassView.arrowTopInset.bottomAnchor),
            aboveApex.heightAnchor.constraint(equalTo: belowApex.heightAnchor)
        ])
    }

    // The date, the app's glyph and the location, as one selector at the top
    private func setUpHeader() {
        headerPill.translatesAutoresizingMaskIntoConstraints = false
        headerPill.setDate(Date())
        headerPill.dateButton.addTarget(self, action: #selector(pickDate), for: .touchUpInside)
        headerPill.homeButton.addTarget(self, action: #selector(showHome), for: .touchUpInside)
        headerPill.locationButton.addTarget(self, action: #selector(pickLocation), for: .touchUpInside)
        self.view.addSubview(headerPill)

        NSLayoutConstraint.activate([
            headerPill.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: ViewController.headerTopInset),
            headerPill.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: ViewController.headerSideInset),
            headerPill.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -ViewController.headerSideInset),
            headerPill.heightAnchor.constraint(equalToConstant: HeaderPillView.height)
        ])
    }

    // The small widget's content, centered in the gap between the header and the table
    private func setUpStatus() {
        statusView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(statusView)
        let statusGap = UILayoutGuide()
        self.view.addLayoutGuide(statusGap)
        NSLayoutConstraint.activate([
            statusGap.topAnchor.constraint(equalTo: headerPill.bottomAnchor),
            statusGap.bottomAnchor.constraint(equalTo: contentGuide.topAnchor),
            statusView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            statusView.centerYAnchor.constraint(equalTo: statusGap.centerYAnchor)
        ])
        updateStatus()
    }

    // The map and the date picker, both hidden below the screen until asked for
    private func setUpPanels() {
        locView.layer.cornerRadius = 25
        locView.clipsToBounds = true
        locView.showsUserLocation = true
        locView.setUserTrackingMode(.follow, animated: true)
        locPanel = addPanel(locView)

        dateSelector.datePickerMode = UIDatePicker.Mode.date
        dateSelector.preferredDatePickerStyle = .inline
        dateSelector.backgroundColor = UIColor(named: "Secondary Background")
        dateSelector.layoutMargins = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        dateSelector.layer.cornerRadius = 25
        dateSelector.clipsToBounds = true
        dateSelector.addTarget(self, action: #selector(datePicked(_:)), for: UIControl.Event.valueChanged)
        datePanel = addPanel(dateSelector)
    }

    // Adds the view at the table's size, resting below the screen
    private func addPanel(_ panelView: UIView) -> SlidePanel {
        panelView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(panelView)
        let panel = SlidePanel(
            view: panelView,
            hiddenTop: panelView.topAnchor.constraint(equalTo: self.view.bottomAnchor),
            shownTop: panelView.topAnchor.constraint(equalTo: tableView.topAnchor)
        )
        NSLayoutConstraint.activate([
            panelView.widthAnchor.constraint(equalTo: contentGuide.widthAnchor),
            panelView.heightAnchor.constraint(equalTo: contentGuide.heightAnchor),
            panelView.centerXAnchor.constraint(equalTo: contentGuide.centerXAnchor),
            panel.hiddenTop
        ])
        return panel
    }

    // MARK: Data

    // Assigns LocationDelegate callback functions
    private func bindLocation() {
        let loc = LocationDelegate.shared
        loc.setLocationName = { [weak self] variants in
            self?.headerPill.setLocation(variants)
        }
        loc.onDataShouldReload = { [weak self] in
            self?.tableView.reloadData()
            self?.timelineView.setNeedsDisplay()
            self?.currentStatus = nil
            self?.updateStatus()
        }
    }

    private func startTimers() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateStatus()
        }

        // Keeps the current-time marker moving, and rolls over to the next day at midnight
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.followsToday && !Calendar.current.isDateInToday(self.tableDataSource.desiredDate) {
                self.refreshToNow()
            } else {
                self.timelineView.setNeedsDisplay()
            }
        }
    }

    // Shows the prayer in effect and counts down to the next one, from the real current time
    // whichever date is on show
    private func updateStatus() {
        let now = Date()
        if currentStatus == nil || now >= currentStatus!.nextStart,
           let coord = LocationDelegate.shared.currentLocation?.coordinate {
            currentStatus = PrayerSchedule.status(at: now, latitude: coord.latitude, longitude: coord.longitude)
        }
        statusView.update(status: currentStatus, now: now)
    }

    // MARK: Panels

    // Shows Date Picker on View
    @objc func pickDate() {
        toggle(datePanel, closing: locPanel)
    }

    // Shows Location Picker on View
    @objc func pickLocation() {
        toggle(locPanel, closing: datePanel)
    }

    // Puts both panels away and goes back to the prayer times
    @objc func showHome() {
        guard datePanel.isShown || locPanel.isShown else { return }
        UIImpactFeedbackGenerator().impactOccurred()
        datePanel.setShown(false)
        locPanel.setShown(false)
        animatePanels()
    }

    // Slides the panel in or out of the table's place, putting the other panel away first.
    // Tapping the panel that is already shown puts it away and returns to the prayer times.
    private func toggle(_ panel: SlidePanel, closing other: SlidePanel) {
        UIImpactFeedbackGenerator().impactOccurred()
        other.setShown(false)
        panel.setShown(!panel.isShown)
        animatePanels()
    }

    private func animatePanels() {
        headerPill.setSelection(datePanel.isShown ? .date : (locPanel.isShown ? .location : .home), animated: true)
        UIView.animate(withDuration: 0.75, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 1, options: .curveEaseOut, animations: {
            self.view.layoutIfNeeded()
        })
    }

    // Assigns picked Date to be used later and updates View accordingly
    @objc func datePicked(_ sender: UIDatePicker) {
        followsToday = Calendar.current.isDateInToday(sender.date)
        show(date: sender.date)
    }

    // Points the View back at the current moment unless a specific date was picked.
    // Used when the app returns to the foreground and when the day changes while open.
    func refreshToNow() {
        guard followsToday else { return }
        dateSelector.date = Date()
        show(date: dateSelector.date)
    }

    private func show(date: Date) {
        headerPill.setDate(date)

        tableDataSource.desiredDate = date
        timelineView.desiredDate = date

        tableView.reloadData()
        timelineView.setNeedsDisplay()
    }
}
