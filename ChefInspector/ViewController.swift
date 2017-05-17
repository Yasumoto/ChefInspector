//
//  ViewController.swift
//  ChefInspector
//
//  Created by Joseph Mehdi Smith on 5/16/17.
//  Copyright © 2017 Joe Smith. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    @IBOutlet weak var hostnameTableCellView: NSTableCellView!
    @IBOutlet var attributesTextView: NSTextView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    @IBAction func clearView(_ sender: NSButton) {
    }

    @IBAction func searchHostAttributes(_ sender: NSSearchField) {
    }

    @IBAction func viewHostAttributes(_ sender: NSTextField) {
    }
}

