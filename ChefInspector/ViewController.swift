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

    var allHostnames = [String]()
    var viewableHostnames = [String]()
    var hostOutput = [String]()
    var attributes = [String:String]()
    let hostQueue = DispatchQueue(label: "viewableHostsQueue")
    let chefQueue = DispatchQueue(label: "chefQueue")

    func updateHostList() {
        hostQueue.sync {
            viewableHostnames = ["Updating host list..."]
        }
        self.hostnameTableView.reloadData()
        self.chefQueue.async {
            do {
                print("Populating Chef Nodes")
                if let nodes = try self.chefClient.nodeList() {
                    print("Found \(nodes.count) chef nodes")
                    self.hostQueue.sync(flags: .barrier) {
                        self.allHostnames = nodes.sorted()
                        self.viewableHostnames = self.allHostnames
                        DispatchQueue.main.async {
                            print("Reloading node list after populating from chef")
                            self.hostnameTableView.reloadData()
                        }
                    }
                } else {
                    print("Did not retrieve any nodes")
                    self.allHostnames = [String]()
                }
            } catch {
                print("Error when populating node list: \(error)")
            }
        }
    }

    func displayHostAttributes(hostname: String) {
        //TODO(jmsmith): Next up is to use https://www.raywenderlich.com/123463/nsoutlineview-macos-tutorial for better display
        if self.attributes.index(forKey: hostname) != nil {
            print("Attributes for \(hostname) already found in cache")
            if let value = self.attributes[hostname] {
                self.attributesTextView.textStorage?.mutableString.setString("\(value)")
            } else {
                self.attributesTextView.textStorage?.mutableString.setString("Node not found in Chef.")
            }
        } else {
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    print("Querying chef for attributes for \(hostname)")
                    if let output = try self.chefClient.retrieveNodeAttributes(nodeName: hostname) {
                        self.attributes[hostname] = "\(output)"
                        DispatchQueue.main.async {
                            print("Updating attributes view to display \(hostname)")
                            self.attributesTextView.textStorage?.mutableString.setString("\(output)")
                        }
                    }
                } catch {
                    print("Warning! Failed to get node attributes for \(hostname):\n\(error)")
                }
            }
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
        self.attributes = [String: String]()
    }

    @IBAction func filterHostAttribute(_ sender: NSSearchField) {
    }

    @IBAction func hostnameSelected(_ sender: NSTableView) {
        var hostname: String = ""
        hostQueue.sync() {
            if sender.selectedRow < viewableHostnames.count && sender.selectedRow >= 0 {
                hostname = viewableHostnames[sender.selectedRow]
            }
        }
        if hostname != "" {
            displayHostAttributes(hostname: hostname)
        }
    }

    @IBAction func searchHostAttributes(_ sender: NSSearchField) {
        self.hostQueue.sync(flags: .barrier) {
            print("Temporarily updating hostlist")
            self.viewableHostnames = ["Searching..."]
        }
        print("Reloading tableview data")
        self.hostnameTableView.reloadData()
        chefQueue.async {
            if sender.stringValue == "" {
                print("Resetting tableview to all hostnames")
                self.viewableHostnames = self.allHostnames
            } else if sender.stringValue.contains(":") {
                    do {
                        if let searchQuery = sender.stringValue.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {
                            print("Performing chef search for \(searchQuery)")

                            let searchedHostnames = try self.chefClient.searchNode(query: searchQuery).sorted()
                            self.hostQueue.sync(flags: .barrier) {
                                self.viewableHostnames = searchedHostnames
                            }
                        }

                    } catch {
                        print("Error searching chef: \(error)")
                        self.viewableHostnames = []
                    }
            } else {
                self.hostQueue.sync(flags: .barrier) {
                    print("Taking a look at filtering current hostnames")
                    let hostnames = self.allHostnames.filter { $0.contains(sender.stringValue) }.sorted()
                    if hostnames.count < 1 {
                        self.viewableHostnames = [""]
                    } else {
                        self.viewableHostnames = hostnames
                    }
                }
            }
            DispatchQueue.main.sync {
                print("Reloading data after searching for a hostname")
                self.hostnameTableView.reloadData()
            }
        }
    }
}


extension ViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return hostQueue.sync {
            print("There are \(viewableHostnames.count) rows")
            return viewableHostnames.count
        }
    }
}

extension ViewController: NSTableViewDelegate {

    fileprivate enum CellIdentifiers {
        static let HostNameCell = "HostNameCellID"
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let cell = tableView.make(withIdentifier: CellIdentifiers.HostNameCell, owner: self) as? NSTableCellView {
            return hostQueue.sync() {
                if row < viewableHostnames.count {
                    cell.textField?.stringValue = viewableHostnames[row]
                    return cell
                }
                print("Row \(row) larger than index of \(viewableHostnames.count)")
                return nil
            }
        } else {
            print("Couldn't make cell")
        }
        return nil
    }
    
}
