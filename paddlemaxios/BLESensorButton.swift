//
//  BLESensorButton.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 2/3/15.
//  Copyright (c) 2015 Adafruit Industries. All rights reserved.
//

import UIKit

class BLESensorButton: UIButton {

//    override init() {
//        dimmed = false
//        super.init()
//        self.customizeButton()
//    }
    
    override init(frame: CGRect) {
        dimmed = false
        super.init(frame: frame)
        self.customizeButton()
    }

    required init(coder aDecoder: NSCoder) {
        dimmed = false
        super.init(coder: aDecoder)!
        self.customizeButton()
    }
    
    
    let offColor = bleBlueColor
    let onColor = UIColor.white
    
    var dimmed: Bool {    // Highlighted is used as an interactive disabled state
        willSet(newValue) {
            if newValue == false {
                self.layer.borderColor = bleBlueColor.cgColor
                self.setTitleColor(offColor, for: UIControlState())
                self.setTitleColor(onColor, for: UIControlState.selected)
            }
            else {
                self.layer.borderColor = UIColor.lightGray.cgColor
                self.setTitleColor(UIColor.lightGray, for: UIControlState())
                self.setTitleColor(UIColor.lightGray, for: UIControlState.selected)
            }
        }
    }
    
    
    func customizeButton(){
        
        self.titleLabel?.font = UIFont.systemFont(ofSize: 14.0)
        self.setTitle("OFF", for: UIControlState())
        self.setTitle("ON", for: UIControlState.selected)
        self.setTitleColor(offColor, for: UIControlState())
        self.setTitleColor(onColor, for: UIControlState.selected)
        self.setTitleColor(UIColor.lightGray, for: UIControlState.highlighted)
        self.backgroundColor = UIColor.white
        self.setBackgroundImage(UIImage(named: "ble_blue_1px.png"), for: UIControlState.selected)
        self.layer.cornerRadius = 8.0
        self.clipsToBounds = true
        self.layer.borderColor = offColor.cgColor
        self.layer.borderWidth = 1.0
        
    }

}
