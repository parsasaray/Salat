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
        let sunStrings: [String] = ["Dawn", "Sunrise", "Noon", "Afternoon", "Sunset", "Night"]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "h:mm"
        
        cell.nameLabel.text = sunStrings[indexPath.row]
        cell.timeLabel.text = dateFormatter.string(from: sunTimes[sunStrings[indexPath.row]]!)
           
        return cell
    }
}

class Cell: UITableViewCell {
    
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var timeLabel: UILabel!
    
}
