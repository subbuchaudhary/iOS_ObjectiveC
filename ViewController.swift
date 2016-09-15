import UIKit

class ViewController: UIViewController, UITableViewDataSource {
    
    
    let people = [
    ("Subbu", "California"),
    ("Nivas", "Texas")
    ]
    
    let technology = [
    ("UI Developer", "6 languages"),
    ("iOS Developer", "2 languages"),
    ("Oracle Applications Developer", "2 language")
    ]
    //return how many sections in your table
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    //return how many rows
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (section == 0) {
        return people.count
        }
        else {
        return technology.count
        }
    }
    //contents of each cell
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let name = UITableViewCell()
        if (indexPath.section == 0) {
        let (personName, _) = people[indexPath.row]
        name.textLabel?.text = personName
        }
        else {
            let (technologyName, _) = technology[indexPath.row]
            name.textLabel?.text = technologyName
        }
        return name
    }
    
    //Give name to each table section
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if (section == 0) {
            return "People Details"
        }
        else {
            return "Technology Details"
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
       
    }



}

