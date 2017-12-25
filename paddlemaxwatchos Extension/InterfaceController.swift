//
//  InterfaceController.swift
//  paddlemaxwatchos Extension
//
//  Created by Cole Inman on 11/30/17.
//  Copyright © 2017 Paddle Max. All rights reserved.
//

import WatchKit
import Foundation


class ConnectInterfaceController: WKInterfaceController {
    
    @IBOutlet var connectLabel: WKInterfaceLabel!
    @IBOutlet var deviceList: WKInterfaceTable!
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

}
