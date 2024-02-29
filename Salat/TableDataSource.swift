//
//  TableDataSource.swift
//  Salat
//
//  Created by Parsa Saraydarpour on 6/17/21.
//

import UIKit

let tableDataSource = TableDataSource()

class TableDataSource: NSObject, UITableViewDataSource {
    let textStrings: [String] = ["Dawn", "Sunrise", "Noon", "Afternoon", "Sunset", "Night"]
    
    // Generates row in TableView for each Salat
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        6
    }
    
    // Populates each generated row with the relevant Salat information
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "salatCell") as! Cell
        let salatTimes: [String: Date] = SalatTimes().getTimes(date: desiredDate, lat: desiredLocation.latitude, lng: desiredLocation.longitude)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "h:mm"
        dateFormatter.timeZone = desiredTimeZone
        
        cell.nameLabel.text = textStrings[indexPath.row]
        cell.nameLabel.textColor = UIColor(named: textStrings[indexPath.row])
        cell.timeLabel.text = dateFormatter.string(from: salatTimes[textStrings[indexPath.row]]!)
        cell.backgroundColor = .clear
           
        return cell
    }
}

class Cell: UITableViewCell {
    
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var timeLabel: UILabel!
    
}
