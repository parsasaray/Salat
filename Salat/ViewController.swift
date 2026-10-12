//
//  ViewController.swift
//  Salat
//
//  Created by Parsa Saraydarpour on 4/10/21.
//

import UIKit
import MapKit

class ViewController: UIViewController {
//    private let settingsButton = UIButton()
    private let tableView = UITableView()
    private let timelineView = TimelineView()
    private let compassView = CompassView()
    private let locButton = UIButton()
    private let locView = MKMapView()
    private let dateButton = UIButton()
    private let dateSelector = UIDatePicker()
    
    private let tableDataSource = TableDataSource()
    private var dateSelectorTopAnchor: NSLayoutConstraint!
    private var locViewTopAnchor: NSLayoutConstraint!
    // True until a date other than today is picked. While true, the app keeps showing today.
    private var followsToday = true
    
    // Adds all visual elements to the View
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(UINib(nibName: "Cell", bundle: nil), forCellReuseIdentifier: "salatCell")
        tableView.dataSource = tableDataSource
        tableView.isUserInteractionEnabled = false
        tableView.rowHeight = self.view.frame.height / (6/0.5)
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            tableView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor, constant: -45),
            tableView.widthAnchor.constraint(equalTo: self.view.widthAnchor, multiplier: 0.75),
            tableView.heightAnchor.constraint(equalTo: self.view.heightAnchor, multiplier: 0.5)
        ])
        
//        settingsButton.setImage(UIImage(systemName: "gearshape"), for: .normal)
//        settingsButton.tintColor = .white
//        settingsButton.translatesAutoresizingMaskIntoConstraints = false
//        self.view.addSubview(settingsButton)
//        NSLayoutConstraint.activate([
//            settingsButton.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 25),
//            settingsButton.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -10),
//            settingsButton.widthAnchor.constraint(equalToConstant: 100),
//            settingsButton.heightAnchor.constraint(equalToConstant: 30)
//        ])
        
        timelineView.translatesAutoresizingMaskIntoConstraints = false
        timelineView.backgroundColor = .clear
        self.view.addSubview(timelineView)
        NSLayoutConstraint.activate([
            timelineView.topAnchor.constraint(equalTo: tableView.bottomAnchor, constant: 25),
            timelineView.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            timelineView.widthAnchor.constraint(equalTo: tableView.widthAnchor),
            timelineView.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        compassView.translatesAutoresizingMaskIntoConstraints = false
        compassView.backgroundColor = .clear
        self.view.addSubview(compassView)
        NSLayoutConstraint.activate([
            compassView.topAnchor.constraint(equalTo: timelineView.bottomAnchor, constant: 40),
            compassView.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            compassView.widthAnchor.constraint(equalTo: tableView.widthAnchor, multiplier: 0.5),
            compassView.heightAnchor.constraint(equalTo: tableView.widthAnchor, multiplier: 0.5)
        ])
        
        locButton.translatesAutoresizingMaskIntoConstraints = false
        locButton.setTitleColor(.label, for: .normal)
        locButton.addTarget(self, action: #selector(pickLocation), for: .touchUpInside)
        self.view.addSubview(locButton)
        NSLayoutConstraint.activate([
            locButton.bottomAnchor.constraint(equalTo: tableView.topAnchor, constant: -35),
            locButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor)
        ])
        
        locView.layer.cornerRadius = 25
        locView.clipsToBounds = true
        locView.translatesAutoresizingMaskIntoConstraints = false
        locViewTopAnchor = locView.topAnchor.constraint(equalTo: self.view.bottomAnchor)
        locView.showsUserLocation = true
        locView.setUserTrackingMode(.follow, animated: true)
        self.view.addSubview(locView)
        NSLayoutConstraint.activate([
            locView.widthAnchor.constraint(equalTo: tableView.widthAnchor),
            locView.heightAnchor.constraint(equalTo: tableView.heightAnchor),
            locView.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            locViewTopAnchor
        ])
        
        dateButton.translatesAutoresizingMaskIntoConstraints = false
        dateButton.setTitleColor(.label, for: .normal)
        dateButton.setTitle(Date().formatted(date: .long, time: .omitted), for: .normal)
        dateButton.addTarget(self, action: #selector(pickDate), for: .touchUpInside)
        self.view.addSubview(dateButton)
        NSLayoutConstraint.activate([
            dateButton.bottomAnchor.constraint(equalTo: locButton.topAnchor, constant: 5),
            dateButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor)
        ])
        
        dateSelector.datePickerMode = UIDatePicker.Mode.date
        dateSelector.preferredDatePickerStyle = .inline
        dateSelector.backgroundColor = UIColor(named: "Secondary Background")
        dateSelector.layoutMargins = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        dateSelector.layer.cornerRadius = 25
        dateSelector.clipsToBounds = true
        dateSelector.translatesAutoresizingMaskIntoConstraints = false
        dateSelector.addTarget(self, action: #selector(datePicked(_:)), for: UIControl.Event.valueChanged)
        dateSelectorTopAnchor = dateSelector.topAnchor.constraint(equalTo: self.view.bottomAnchor)
        self.view.addSubview(dateSelector)
        NSLayoutConstraint.activate([
            dateSelector.widthAnchor.constraint(equalTo: tableView.widthAnchor),
            dateSelector.heightAnchor.constraint(equalTo: tableView.heightAnchor),
            dateSelector.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            dateSelectorTopAnchor
        ])
        
        //Assign LocationDelegate callback functions
        let loc = LocationDelegate.shared
        loc.setLocationName = { [weak self] name in
            self?.locButton.setTitle(name, for: .normal)
        }
        loc.onDataShouldReload = { [weak self] in
            self?.tableView.reloadData()
            self?.timelineView.setNeedsDisplay()
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
    
    // Shows Date Picker on View
    @objc func pickDate() {
        UIImpactFeedbackGenerator().impactOccurred()
        locViewTopAnchor.constant = 0
        dateSelectorTopAnchor.constant = (dateSelectorTopAnchor.constant == 0)
            ? (tableView.frame.origin.y - self.view.frame.height)
            : 0
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
        dateButton.setTitle(date.formatted(date: .long, time: .omitted), for: .normal)
        
        tableDataSource.desiredDate = date
        timelineView.desiredDate = date
        
        tableView.reloadData()
        timelineView.setNeedsDisplay()
    }
    
    // Shows Location Picker on View
    @objc func pickLocation() {
        UIImpactFeedbackGenerator().impactOccurred()
        dateSelectorTopAnchor.constant = 0
        locViewTopAnchor.constant = (locViewTopAnchor.constant == 0)
            ? (tableView.frame.origin.y - self.view.frame.height)
            : 0
        UIView.animate(withDuration: 0.75, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 1, options: .curveEaseOut, animations: {
            self.view.layoutIfNeeded()
        })
    }
}

