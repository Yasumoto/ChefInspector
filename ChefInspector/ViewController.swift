//
//  ViewController.swift
//  ChefInspector
//
//  Created by Joseph Mehdi Smith on 5/16/17.
//  Copyright © 2017 Joe Smith. All rights reserved.
//

import Cocoa
import Gyutou

struct Node {
    let name: String
    let children: Any?
}

class ViewController: NSViewController {
    @IBOutlet weak var hostnameTableView: NSTableView!

    @IBOutlet weak var attributesOutlineView: NSOutlineView!
    let chefClient = try! GyutouClient()

    var allHostnames = [String]()
    var viewableHostnames = [String]()
    var hostOutput = [String:Any]()
    var filteredHostOutput = [String:Any]()
    var attributes = [String:Any]()
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
            if let value = self.attributes[hostname] as? [String: Any] {
                self.hostOutput = value
                self.filteredHostOutput = value
            } else {
                self.hostOutput = ["Could not read hostname in cache": ""]
                self.filteredHostOutput = ["Could not read hostname in cache": ""]
            }
            self.attributesOutlineView.setNeedsDisplay()
        } else {
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    print("Querying chef for attributes for \(hostname)")
                    if let output = try self.chefClient.retrieveNodeAttributes(nodeName: hostname) {
                        self.attributes[hostname] = output
                        DispatchQueue.main.async {
                            print("Updating attributes view to display \(hostname)")
                            if let formattedOutput = output as? [String:Any] {
                                self.hostOutput = formattedOutput
                                self.filteredHostOutput = self.hostOutput
                            } else {
                                print("Problem parsing \(output)")
                                self.hostOutput = [String:Any]()
                                self.filteredHostOutput = [String:Any]()
                            }
                            self.attributesOutlineView.reloadData()
                            self.attributesOutlineView.setNeedsDisplay()
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
        attributesOutlineView.delegate = self
        attributesOutlineView.dataSource = self
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }

    @IBAction func clearView(_ sender: NSButton) {
        self.hostOutput = [String:Any]()
        self.filteredHostOutput = [String:Any]()
        updateHostList()
        self.attributes = [String: Any]()
    }

    func searchString(_ keyword: String, found value: Any) -> Any? {
        if let contents = value as? [String: Any] {
            var newFilteredOutput = [String: Any]()
            for (key, value) in contents {
                if key.contains(keyword) {
                    newFilteredOutput[key] = value
                } else {
                    if let found = searchString(keyword, found: value) {
                        newFilteredOutput[key] = found
                    }
                }
            }
            if newFilteredOutput.count > 0 {
                return newFilteredOutput
            }
        } else if let contents = value as? [Any] {
            var newFilteredOutput = [Any]()
            for value in contents {
                if let found = searchString(keyword, found: value) {
                    newFilteredOutput.append(found)
                }
            }
            if newFilteredOutput.count > 0 {
                return newFilteredOutput
            }
        } else if let contents = value as? CustomStringConvertible {
            if contents.description.contains(keyword) {
                return contents
            }
        }
        return nil
    }

    @IBAction func filterHostAttribute(_ sender: NSSearchField) {
        var expand = false
        if let search = sender.recentSearches.first {
            if search == "" {
                filteredHostOutput = hostOutput
            } else if let found = searchString(search, found: hostOutput) as? [String: Any] {
                filteredHostOutput = found
                expand = true
            } else {
                filteredHostOutput = [String:Any]()
            }
            self.attributesOutlineView.reloadData()
            self.attributesOutlineView.expandItem(nil, expandChildren: expand)
            self.attributesOutlineView.setNeedsDisplay()
        }
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
        if sender.stringValue == "" {
            chefQueue.async {
                print("Resetting tableview to all hostnames")
                self.viewableHostnames = self.allHostnames
            }
        } else if sender.stringValue.contains(":") {
            chefQueue.async {
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
        DispatchQueue.main.async {
            print("Reloading data after searching for a hostname")
            self.hostnameTableView.reloadData()
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
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifiers.HostNameCell), owner: self) as? NSTableCellView {
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

extension ViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        print("Counting children")
        if item == nil {
            return filteredHostOutput.keys.count
        }
        if let node = item as? Node {
            if let list = node.children as? [Any] {
                return list.count
            } else if let dict = node.children as? [String: Any] {
                return dict.keys.count
            } else if let _ = node.children as? CustomStringConvertible {
                return 1
            }
            //TODO(Yasumoto): Maybe we need to check [Int: Any] and others as well?
        }
        print("Not a leaf or section so assuming end")
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        print("Getting item for outline")
        if item == nil {
            print("Root item, returning output")
            let nameIndex = filteredHostOutput.keys.index(filteredHostOutput.keys.startIndex, offsetBy: index)
            let name = filteredHostOutput.keys[nameIndex]
            return Node(name: name, children: filteredHostOutput[name])
        }
        if let node = item as? Node {
            if let section = node.children as? [String: Any] {
                let nameIndex = section.keys.index(section.keys.startIndex, offsetBy: index)
                let name = section.keys[nameIndex]
                return Node(name: name, children: section[name])
            } else if let section = node.children as? [Any] {
                let nameIndex = section.index(section.startIndex, offsetBy: index)
                if let value = section[nameIndex] as? CustomStringConvertible {
                    return Node(name: value.description, children: nil)
                } //TODO(Yasumoto): Handle more than just lists of strings!
            } else if let section = node.children as? CustomStringConvertible {
                return Node(name: section.description, children: nil)
            }
        }
        return "MISSED PARSING"
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        print("Checking if outline is expandable")
        if let node = item as? Node {
            if let _ = node.children {
                return true
            }
        }
        return false
    }

    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        if let node = item as? Node {
            print("Getting the value of \(node)")
            return node.name
        }
        return "Error: Failed to get objectValue!"
    }
}

extension ViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        print("Generating outline view")
        var view: NSTableCellView?
        var attribute = ""
        if let attempt = item as? Node {
            attribute = attempt.name
        } else if let attempt = item as? CustomStringConvertible {
            attribute = attempt.description
        }
        view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "AttributeCell"), owner: self) as? NSTableCellView
        if let textField = view?.textField {
            textField.stringValue = attribute
            textField.sizeToFit()
        }
        return view
    }
}
