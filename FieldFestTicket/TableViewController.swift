//
//  TableViewController.swift
//  FieldFestTicket
//
//  Created by Adam Dorogi-Kaposi on 12/2/18.
//  Copyright © 2018 Adam Dorogi-Kaposi. All rights reserved.
//

import UIKit

class TableViewController: UITableViewController {
    
    var ticketCodesArray = [String]()
    var clearButton = UIBarButtonItem()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.navigationBar.barStyle = .black

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
        
        let closeButton = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(close))
        closeButton.tintColor = .white
        navigationItem.leftBarButtonItem = closeButton
        
        clearButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(clear))
        clearButton.tintColor = .white
        navigationItem.rightBarButtonItem = clearButton
        
        // Update UI if 0 scanned tickets.
        if ticketCodesArray.count > 0 {
            navigationItem.title = "Leszkennelt jegyek (\(ticketCodesArray.count - 1))"
        } else {
            navigationItem.title = "Leszkennelt jegyek (0)"
        }
        
        clearButton.isEnabled = ticketCodesArray.count - 1 > 0
    }

    @objc func clear() {
        let alert = UIAlertController(title: "Törlés", message: "Biztosan törölni szeretnéd az összes leszkennelt jegyet?", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Nem", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Igen", style: .destructive, handler: { action in
            try! "".write(to: ViewController().fileURL!, atomically: false, encoding: .utf8)
            self.ticketCodesArray = []
            self.tableView.reloadData()
        }))

        present(alert, animated: true, completion: nil)
    }
    
    @objc func close() {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        do {
            let ticketCodes = try String(contentsOf: ViewController().fileURL!, encoding: .utf8)
            ticketCodesArray = ticketCodes.components(separatedBy: "\n")
            
            navigationItem.title = "Leszkennelt jegyek (\(ticketCodesArray.count - 1))"
            
            clearButton.isEnabled = ticketCodesArray.count - 1 > 0
            
            return ticketCodesArray.count - 1
        } catch {
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()

        // Configure the cell...
        cell.textLabel?.text = ticketCodesArray[indexPath.row]

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.cellForRow(at: indexPath)?.setSelected(false, animated: true)
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
