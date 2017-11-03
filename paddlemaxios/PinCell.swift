//
//  PinCell.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 10/10/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

import Foundation
import UIKit

protocol PinCellDelegate {
    
    func cellModeUpdated(_ sender: AnyObject)
    
}

enum PinState:Int{
    case low = 0
    case high
}

enum PinMode:Int{
    case unknown = -1
    case input
    case output
    case analog
    case pwm
    case servo
}

class PinCell: UITableViewCell {
    
    var delegate:PinCellDelegate?
    var pinLabel:UILabel!
    var modeLabel:UILabel!
    var valueLabel:UILabel!
    var toggleButton:UIButton!
    var modeControl:UISegmentedControl!
    var digitalControl:UISegmentedControl!
    var valueSlider:UISlider!
    
    var digitalPin:Int = -1 {
        didSet {
            if oldValue != self.digitalPin{
                updatePinLabel()
            }
        }
    }
    
    var analogPin:Int = -1 {
        didSet {
            if oldValue != self.analogPin{
                updatePinLabel()
            }
        }
    }
    
    var isDigital:Bool = false {
        didSet {
            if oldValue != self.isDigital {
                configureModeControl()
            }
        }
    }
    
    var isAnalog:Bool = false {
        didSet {
            if oldValue != self.isAnalog {
                configureModeControl()
            }
        }
    }
    
    var mode:PinMode! {
        didSet {
            //Change cell mode - Digital/Analog/PWM
            respondToNewMode(self.mode)
            
            if (oldValue != self.mode) {
                delegate!.cellModeUpdated(self)
            }
        }
    }
    
    var isPWM:Bool = false {
        didSet {
            if oldValue != self.isPWM {
                configureModeControl();
            }
        }
    }
    
    var isServo:Bool! = false
    
    
    required init() {
        super.init(style: UITableViewCellStyle.default, reuseIdentifier: nil)
    }
    
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }
    
    
    func updatePinLabel() {
        
        if analogPin == -1 {
            pinLabel.text = "Pin \(digitalPin)"
        }
        else {
            pinLabel.text = "Pin \(digitalPin), Analog \(analogPin)"
        }
        
    }
    
    
    func setDigitalValue(_ value:Int){
        
        //Set a cell's digital Low/High value
        
        if ((self.mode == PinMode.input) || (self.mode == PinMode.output)) {
            switch (value) {
            case 0:
                self.valueLabel.text = "Low"
//                printLog(self, funcName: "setDigitalValue", logString: "Setting pin \(self.digitalPin) LOW")
                break
            case 1:
                self.valueLabel.text = "High"
//                printLog(self, funcName: "setDigitalValue", logString: "Setting pin \(self.digitalPin) HIGH")
                break
            default:
//                printLog(self, funcName: "setDigitalValue", logString: "Attempting to set digital pin \(self.digitalPin) to analog value")
                break
            }
        }
            
        else{
            
//            printLog(self, funcName: "setDigitalValue", logString: "\(self.analogPin) to digital value")
        }
        
    }
    
    
    func setAnalogValue(_ value:Int){
        
        //Set a cell's analog value
        
        if (self.mode == PinMode.analog){
            
            self.valueLabel.text = "\(value)";
            
        }
            
        else {
            
            printLog(self, funcName: "setAnalogValue", logString: "\(self.digitalPin) to analog value")
        }
        
    }
    
    
    func setPwmValue(_ value:Int){
        
        //Set a cell's PWM value
        
        if (self.mode == PinMode.pwm){
            
            self.valueLabel.text = "\(value)"
            
        }
            
        else {
            
            printLog(self, funcName: "setPwmValue", logString: "\(self.digitalPin) to non-PWM value")
            
        }
        
    }
    
    
    func respondToNewMode(_ newValue:PinMode){
        
        //Set default display values & controls
        
        switch (newValue) {
        case PinMode.input:
            self.modeLabel.text = "Input"
            self.valueLabel.text = "Low"
            hideDigitalControl(true)
            hideValueSlider(true)
            break;
        case PinMode.output:
            self.modeLabel.text = "Output"
            self.valueLabel.text = "Low"
            hideDigitalControl(false)
            hideValueSlider(true)
            break;
        case PinMode.analog:
            self.modeLabel.text = "Analog"
            self.valueLabel.text = "0"
            hideDigitalControl(true)
            hideValueSlider(true)
            break;
        case PinMode.pwm:
            self.modeLabel.text = "PWM"
            self.valueLabel.text = "0"
            hideDigitalControl(true)
            hideValueSlider(false)
            break;
        case PinMode.servo:
            self.modeLabel.text = "Servo"
            self.valueLabel.text = "0"
            hideDigitalControl(true)
            hideValueSlider(false)
            break;
        default:
            self.modeLabel.text = ""
            self.valueLabel.text = ""
            hideDigitalControl(true)
            hideValueSlider(true)
            break;
        }
    }
    
    
    func hideDigitalControl(_ hide:Bool){
        
        self.digitalControl.isHidden = hide
        
        if (hide){
            self.digitalControl.selectedSegmentIndex = 0
        }
    }
    
    
    func hideValueSlider(_ hide:Bool){
    
        self.valueSlider.isHidden = hide
        
        if (hide) {
            self.valueSlider.value = 0.0
        }
    
    }
    
    
    func setMode(_ modeInt:UInt8) {
        
        switch modeInt {
        case 0:
            self.mode = PinMode.input
        case 1:
            self.mode = PinMode.output
        case 2:
            self.mode = PinMode.analog
        case 3:
            self.mode = PinMode.pwm
        case 4:
            self.mode = PinMode.servo
        default:
            printLog(self, funcName: (#function), logString: "Attempting to set pin mode w non-matching int")
        }
        
    }
    
    
    func setDefaultsWithMode(_ aMode:PinMode){
    
        //load initial default values
    
        modeControl.selectedSegmentIndex = aMode.rawValue
    
        mode = aMode
    
        digitalControl.selectedSegmentIndex = PinState.low.rawValue
    
        valueSlider.setValue(0.0, animated: false)
    
    }
    
    
    func configureModeControl(){
        
        //Configure Mode segmented control per pin capabilities …
        
        modeControl.removeAllSegments()
        
        if isDigital == true {
            modeControl.insertSegment(withTitle: "Input", at: 0, animated: false)
            modeControl.insertSegment(withTitle: "Output", at: 1, animated: false)
        }
        
        if isAnalog == true {
            modeControl.insertSegment(withTitle: "Analog", at: modeControl.numberOfSegments, animated: false)
        }
        
        if isPWM == true {
            modeControl.insertSegment(withTitle: "PWM", at: modeControl.numberOfSegments, animated: false)
        }
        
        if isServo == true {
            modeControl.insertSegment(withTitle: "Servo", at: modeControl.numberOfSegments, animated: false)
        }
        
        //    //Default to Output selected
        modeControl.selectedSegmentIndex = PinMode.input.rawValue
    }
    
}
