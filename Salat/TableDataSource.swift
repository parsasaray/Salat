//
//  TableDataSource.swift
//  Salat
//
//  Created by Parsa Saraydarpour on 6/17/21.
//

import UIKit

let tableDataSource = TableDataSource()

class TableDataSource: NSObject, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        6
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "salatCell") as! Cell
        let textStrings: [String] = ["Dawn", "Sunrise", "Noon", "Afternoon", "Sunset", "Night"]
        let sunTimes: [String: Date] = SunTimes().getTimes(date: desiredDate, lat: desiredLocation.latitude, lng: desiredLocation.longitude)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "h:mm"
        dateFormatter.timeZone = desiredTimeZone
        
        cell.nameLabel.text = textStrings[indexPath.row]
        cell.nameLabel.textColor = UIColor(named: textStrings[indexPath.row])
        cell.timeLabel.text = dateFormatter.string(from: sunTimes[textStrings[indexPath.row]]!)
        cell.backgroundColor = .clear
           
        return cell
    }
}

class Cell: UITableViewCell {
    
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var timeLabel: UILabel!
    
}
