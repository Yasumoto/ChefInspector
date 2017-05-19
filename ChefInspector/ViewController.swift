//
//  ViewController.swift
//  ChefInspector
//
//  Created by Joseph Mehdi Smith on 5/16/17.
//  Copyright © 2017 Joe Smith. All rights reserved.
//

import Cocoa
import Gyutou

class ViewController: NSViewController {
    @IBOutlet weak var hostnameTableView: NSTableView!

    @IBOutlet var attributesTextView: NSTextView!
    let chefClient = GyutouClient()

    var hostnames = [String]()
    var hostOutput = [String]()

    func updateHostList() {
        do {
            if let nodes = try chefClient.nodeList() {
                print("Found \(nodes.count) chef nodes")
                hostnames = nodes.sorted()
            } else {
                print("Did not retrieve any nodes")
                hostnames = [String]()
            }
        } catch {
                print("Error when populating node list: \(error)")
        }
    }

    func displayHostAttributes(hostname: String) {
        do {
            if let output = try chefClient.retrieveNodeAttributes(nodeName: hostname) {
                self.attributesTextView.textStorage?.mutableString.setString("\(output)")
            }
        } catch {
            print("Warning! Failed to get node attributes:\n\(error)")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        updateHostList()
        hostnameTableView.delegate = self
        hostnameTableView.dataSource = self
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }

    @IBAction func clearView(_ sender: NSButton) {
        self.attributesTextView.textStorage?.mutableString.setString("")
        self.hostOutput = [String]()
        updateHostList()
    }

    @IBAction func filterHostAttribute(_ sender: NSSearchField) {
    }

    @IBAction func hostnameSelected(_ sender: NSTableView) {
        displayHostAttributes(hostname: hostnames[sender.selectedRow])
    }

    @IBAction func searchHostAttributes(_ sender: NSSearchField) {
        displayHostAttributes(hostname: sender.stringValue)
    }

    @IBAction func viewHostAttributes(_ sender: NSTextField) {
    }
}


extension ViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        print(hostnames.count)
        return hostnames.count
    }
}

extension ViewController: NSTableViewDelegate {

    fileprivate enum CellIdentifiers {
        static let HostNameCell = "HostNameCellID"
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let cell = tableView.make(withIdentifier: CellIdentifiers.HostNameCell, owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = hostnames[row]
            return cell
        } else {
            print("Couldn't make cell")
        }
        return nil
    }
    
}
