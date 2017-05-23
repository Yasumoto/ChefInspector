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

    func copy(sender: AnyObject?){
        var textToDisplayInPasteboard = ""
        let indexSet = hostnameTableView.selectedRowIndexes
        for (_, rowIndex) in indexSet.enumerated() {
            textToDisplayInPasteboard.append("\(viewableHostnames[rowIndex])\n")
        }
        let pasteBoard = NSPasteboard.general()
        pasteBoard.clearContents()

        pasteBoard.setString(textToDisplayInPasteboard, forType:NSPasteboardTypeString)
    }

    func updateHostList() {
        do {
            if let nodes = try chefClient.nodeList() {
                print("Found \(nodes.count) chef nodes")
                allHostnames = nodes.sorted()
                viewableHostnames = allHostnames
            } else {
                print("Did not retrieve any nodes")
                allHostnames = [String]()
            }
        } catch {
            print("Error when populating node list: \(error)")
        }
    }

    func displayHostAttributes(hostname: String) {
        //TODO(jmsmith): Next up is to use https://www.raywenderlich.com/123463/nsoutlineview-macos-tutorial for better display
        if self.attributes.index(forKey: hostname) != nil {
            self.attributesTextView.textStorage?.mutableString.setString("\(self.attributes[hostname]!)")
        } else {
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    if let output = try self.chefClient.retrieveNodeAttributes(nodeName: hostname) {
                        self.attributes[hostname] = "\(output)"
                        DispatchQueue.main.async {
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
        displayHostAttributes(hostname: viewableHostnames[sender.selectedRow])
    }

    @IBAction func searchHostAttributes(_ sender: NSSearchField) {
        self.viewableHostnames = ["Searching..."]
        self.hostnameTableView.reloadData()
        DispatchQueue.global(qos: .userInitiated).async {
            if sender.stringValue == "" {
                self.viewableHostnames = self.allHostnames
            } else if sender.stringValue.contains(":") {
                do {
                    self.viewableHostnames = try self.chefClient.searchNode(query: sender.stringValue.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!)
                } catch {
                    print("Error searching chef: \(error)")
                    self.viewableHostnames = []
                }
            } else {
                self.viewableHostnames = self.allHostnames.filter { $0.contains(sender.stringValue) }
            }
            DispatchQueue.main.async {
                self.hostnameTableView.reloadData()
            }
        }
    }
}


extension ViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return viewableHostnames.count
    }
}

extension ViewController: NSTableViewDelegate {

    fileprivate enum CellIdentifiers {
        static let HostNameCell = "HostNameCellID"
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let cell = tableView.make(withIdentifier: CellIdentifiers.HostNameCell, owner: nil) as? NSTableCellView {
            if row < viewableHostnames.count {
                cell.textField?.stringValue = viewableHostnames[row]
                return cell
            }
        } else {
            print("Couldn't make cell")
        }
        return nil
    }
    
}
