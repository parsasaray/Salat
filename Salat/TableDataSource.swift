//
//  TableDataSource.swift
//  Salat
//
//  Created by Parsa Saraydarpour on 6/17/21.
//

import UIKit

class TableDataSource: NSObject, UITableViewDataSource {
    let textStrings: [String] = ["Dawn", "Sunrise", "Noon", "Afternoon", "Sunset", "Night"]
    var desiredDate: Date = Date()
    
    // Generates row in TableView for each Salat
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        6
    }
    
    // Populates each generated row with the relevant Salat information
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "salatCell") as! Cell
        let name = textStrings[indexPath.row]
        if let location = LocationDelegate.shared.currentLocation,
           let time = SalatTimes().getTimes(date: desiredDate, lat: location.coordinate.latitude, lng: location.coordinate.longitude)[name] {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "h:mm"
            dateFormatter.timeZone = LocationDelegate.shared.currentTimeZone
            
            cell.timeLabel.text = dateFormatter.string(from: time)
        } else {
            // No location yet, or the sun never reaches this angle on this day
            cell.timeLabel.text = "--:--"
        }
        cell.nameLabel.text = textStrings[indexPath.row]
        cell.nameLabel.textColor = UIColor(named: textStrings[indexPath.row])
        cell.timeLabel.textColor = .ink
        cell.backgroundColor = .clear
           
        return cell
    }
}

class Cell: UITableViewCell {
    
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var timeLabel: UILabel!
    
}

extension UIColor {
    // Text and line color: navy in light mode, white in dark mode
    static let ink = UIColor(named: "Ink") ?? .label
}
