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
        if let location = LocationDelegate.shared.currentLocation {
            let coord = location.coordinate
            let salatTimes: [String: Date] = SalatTimes().getTimes(date: desiredDate, lat: coord.latitude, lng: coord.longitude)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "h:mm"
            dateFormatter.timeZone = LocationDelegate.shared.currentTimeZone
            
            cell.timeLabel.text = dateFormatter.string(from: salatTimes[textStrings[indexPath.row]]!)
        } else {
            cell.timeLabel.text = "--:--"
        }
        cell.nameLabel.text = textStrings[indexPath.row]
        cell.nameLabel.textColor = UIColor(named: textStrings[indexPath.row])
        cell.backgroundColor = .clear
           
        return cell
    }
}

class Cell: UITableViewCell {
    
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var timeLabel: UILabel!
    
}
