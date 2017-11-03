//
//  PinIOViewController.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 10/6/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

import Foundation
import UIKit

protocol PinIOViewControllerDelegate: HelpViewControllerDelegate {
    
    func sendData(_ newData: Data)
    
}


class PinIOViewController : UIViewController, UITableViewDataSource, UITableViewDelegate, PinCellDelegate {
    
    fileprivate let SYSEX_START:UInt8 = 0xF0
    fileprivate let SYSEX_END:UInt8 = 0xF7
    fileprivate let SECTION_COUNT = 2
    fileprivate let HEADER_HEIGHT:CGFloat = 40.0
    fileprivate let ROW_HEIGHT_INPUT:CGFloat = 110.0
    fileprivate let ROW_HEIGHT_OUTPUT:CGFloat = 150.0
    fileprivate let DEFAULT_CELL_COUNT = 20
    fileprivate let DIGITAL_PIN_SECTION = 0
    fileprivate let ANALOG_PIN_SECTION = 1
    fileprivate let FIRST_DIGITAL_PIN = 3
    fileprivate let LAST_DIGITAL_PIN = 8
    fileprivate let FIRST_ANALOG_PIN = 14
    fileprivate let LAST_ANALOG_PIN = 19
    fileprivate let PORT_COUNT = 3
    fileprivate let CAPABILITY_QUERY_TIMEOUT = 5.0
    
    var delegate : PinIOViewControllerDelegate!
    @IBOutlet var pinTable : UITableView!
    @IBOutlet var headerLabel : UILabel!
    @IBOutlet var digitalPinCell : PinCell!
    @IBOutlet var helpViewController : HelpViewController!
    @IBOutlet var debugConsole : UITextView? = nil
    
    
    fileprivate let invalidCellPath = IndexPath(item: -1, section: -1)
    fileprivate var openCellPath : IndexPath = IndexPath(item: -1, section: -1)
    fileprivate var cells : [PinCell?] = []
    fileprivate var tableVisibleBounds : CGRect = CGRect.zero
    fileprivate var tableOffScreenBounds : CGRect = CGRect.zero
    fileprivate var pinTableAnimating : Bool = false
    fileprivate var readReportsSent : Bool =  false
    fileprivate var capabilityQueryAlert : UIAlertController?
    fileprivate var pinQueryTimer : Timer?
    
    fileprivate var lastTime : Double = 0.0
    fileprivate var portMasks = [UInt8](repeating: 0, count: 3)
    
    fileprivate enum PinQueryStatus:Int {
        case notStarted
        case capabilityInProgress
        case analogMappingInProgress
        case complete
    }
    fileprivate var pinQueryStatus:PinQueryStatus = PinQueryStatus.notStarted
    fileprivate var capabilityQueryData:[UInt8] = []
    fileprivate var analogMappingData:[UInt8] = []
    
    
    convenience init(delegate aDelegate:PinIOViewControllerDelegate){
        
        //Separate NIBs for iPhone 3.5", iPhone 4", & iPad
        var nibName:NSString
        
        if IS_IPHONE {
            nibName = "PinIOViewController_iPhone"
        }
        else {
            nibName = "PinIOViewController_iPad"
        }
        
        self.init(nibName: nibName as String, bundle: Bundle.main)
        
        self.delegate = aDelegate
        self.title = "Pin I/O"
        self.helpViewController?.title = "Pin I/O Help"
        readReportsSent = false
        
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        helpViewController!.delegate = self.delegate
//        initializeCells()
        
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        //reset firmata
        self.systemReset()
        
        //query device pin capabilities & wait for response
        delay(0.1) { () -> () in
            if self.pinQueryStatus != PinQueryStatus.complete {
                self.capabilityQueryAlert = UIAlertController(title: "Querying pin capabilities …", message: "\n\n", preferredStyle: UIAlertControllerStyle.alert)
                
                let indicator = UIActivityIndicatorView()
                indicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.gray
                indicator.translatesAutoresizingMaskIntoConstraints = false
                self.capabilityQueryAlert!.view.addSubview(indicator)
                
                let views = ["alert" : self.capabilityQueryAlert!.view, "indicator" : indicator]
                var constraints = NSLayoutConstraint.constraints(withVisualFormat: "V:[indicator]-(25)-|", options: NSLayoutFormatOptions.alignAllCenterX, metrics: nil, views: views)
                constraints += NSLayoutConstraint.constraints(withVisualFormat: "H:|[indicator]|", options: NSLayoutFormatOptions.alignAllCenterX, metrics: nil, views: views)
                self.capabilityQueryAlert!.view.addConstraints(constraints)
                
                indicator.isUserInteractionEnabled = false
                indicator.startAnimating()
                
                self.present(self.capabilityQueryAlert!, animated: true) { () -> Void in
                    self.queryCapabilities()
                }
            }
        }
    }
    
    
    //MARK: Connection & Initialization
    
    func didConnect(){
    
    //Respond to device connection
    
    }
    
    
    func initializeDefaultCells(_ reloadTable:Bool){
        
        //••Default to this function when no capability response received••
        
        //Create & configure each table view cell
        
        var newCells:[PinCell?] = []
        
        for i in 0 ..< DEFAULT_CELL_COUNT {
            
            var cell:PinCell?

            //unused pins
            if (i > LAST_DIGITAL_PIN) && (i < FIRST_ANALOG_PIN) {
                cell = nil
            }
            
            //PWM pins
            else if ((i == 3) || (i == 5) || (i == 6)) {
                //setup PWM pin
                cell = createPinCell(i, isDigital: true, isAnalog: false, isPWM: true)
            }

            //Digital pins
            else if (i >= FIRST_DIGITAL_PIN && i <= LAST_DIGITAL_PIN) {
                //setup digital pin
                cell = createPinCell(i, isDigital: true, isAnalog: false, isPWM: false)
                
            }
                
                //Analog pins
            else if (i >= FIRST_ANALOG_PIN && i <= LAST_ANALOG_PIN){
                //setup analog pin
                cell = createPinCell(i, isDigital: true, isAnalog: true, isPWM: false)
                cell?.analogPin = i - FIRST_ANALOG_PIN
            }
            
            if cell != nil {
                newCells.append(cell)
            }
            
        }
        
        cells = newCells
        
        if reloadTable {
            pinTable.reloadData()
        }
        
    }
    
    
    func createPinCell(_ digitalPinNumber:Int, isDigital:Bool, isAnalog:Bool, isPWM:Bool)->PinCell {
        
        let cellData = NSKeyedArchiver.archivedData(withRootObject: digitalPinCell!)
        let cell:PinCell = NSKeyedUnarchiver.unarchiveObject(with: cellData) as! PinCell
        
        //Assign properties via tags
        cell.pinLabel = cell.viewWithTag(100) as! UILabel
        cell.modeLabel = cell.viewWithTag(101) as! UILabel
        cell.valueLabel = cell.viewWithTag(102) as! UILabel
        
        cell.toggleButton = cell.viewWithTag(103) as! UIButton
        cell.toggleButton.addTarget(self, action: #selector(PinIOViewController.cellButtonTapped(_:)), for: UIControlEvents.touchUpInside)
        //set tag to indicate digital pin number
        cell.toggleButton.tag = digitalPinNumber
        
        cell.modeControl = cell.viewWithTag(104) as! UISegmentedControl
        cell.modeControl.addTarget(self, action: #selector(PinIOViewController.modeControlChanged(_:)), for: UIControlEvents.valueChanged)
        //set tag to indicate digital pin number
        cell.modeControl.tag = digitalPinNumber
        
        cell.digitalControl = cell.viewWithTag(105) as! UISegmentedControl
        cell.digitalControl.addTarget(self, action: #selector(PinIOViewController.digitalControlChanged(_:)), for: UIControlEvents.valueChanged)
        //set tag to indicate digital pin number
        cell.digitalControl.tag = digitalPinNumber
        
        cell.valueSlider = cell.viewWithTag(106) as! UISlider
        cell.valueSlider.addTarget(self, action: #selector(PinIOViewController.valueControlChanged(_:)), for: UIControlEvents.valueChanged)
        //set tag to indicate digital pin number
        cell.valueSlider.tag = digitalPinNumber
        
        cell.delegate = self
        
        cell.digitalPin = digitalPinNumber
        cell.isDigital = isDigital
        cell.isPWM = isPWM
        cell.isAnalog = isAnalog
        cell.setDefaultsWithMode(PinMode.input)
        
        return cell
        
    }
    
    
    func queryCapabilities(){
        
        printLog(self, funcName: (#function), logString: "BEGIN PIN QUERY")
        
        //start timeout timer
        pinQueryTimer = Timer(timeInterval: CAPABILITY_QUERY_TIMEOUT, target: self, selector: #selector(PinIOViewController.abortCapabilityQuery), userInfo: nil, repeats: false)
        pinQueryTimer!.tolerance = 2.0
        RunLoop.current.add(pinQueryTimer!, forMode: RunLoopMode.defaultRunLoopMode)
        
        //send command 0xF0 0x6B 0xF7
        let bytes:[UInt8] = [SYSEX_START, 0x6B, SYSEX_END]
        let newData:Data = Data(bytes: UnsafePointer<UInt8>(bytes), count: 3)
        delegate!.sendData(newData)
        
    }
    
    
    func queryAnalogPinMapping(){
        
//        printLog(self, funcName: (#function), logString: "ANALOG MAPPING QUERY")
        
        //send command 0xF0 0x69 0xF7
        let bytes:[UInt8] = [SYSEX_START, 0x69, SYSEX_END]
        let newData:Data = Data(bytes: UnsafePointer<UInt8>(bytes), count: 3)
        delegate!.sendData(newData)
        
    }
    
    
    func abortCapabilityQuery(){
        
        //stop receiving query data
        pinQueryStatus = PinQueryStatus.complete
        
        //initialize default cells for arduino uno
        
        
        //dismiss prev alert
        capabilityQueryAlert?.dismiss(animated: false, completion: nil)
        
        //notify user
        let message = "assuming default pin format \n(Arduino Uno)"
        let alert = UIAlertController(title: "No response to capability query", message: message, preferredStyle: UIAlertControllerStyle.alert)
        let aOk = UIAlertAction(title: "OK", style: UIAlertActionStyle.default) { (action:UIAlertAction) -> Void in
            
        }
        alert.addAction(aOk)
        self.present(alert, animated: true) { () -> Void in
            self.initializeDefaultCells(true)
            self.enableReadReports()
        }
        
    }
    
    
    func enableReadReports(){
        
        printLog(self, funcName: (#function), logString: nil)
        
        //Set individual pin read reports
//        for cell in cells {
//            if (cell?.digitalPin >= 0) { //placeholder cells are -1
//                   setDigitalStateReportingForPin(UInt8(cell!.digitalPin), enabled: true)
//            }
//        }
        
        //Enable Read Reports by port
        let ports:[UInt8] = [0,1,2]
        for port in ports {
            let data0:UInt8 = 0xD0 + port        //start port 0 digital reporting (0xD0 + port#)
            let data1:UInt8 = 1                  //enable
            let bytes:[UInt8] = [data0, data1]
            let newData = Data(bytes: UnsafePointer<UInt8>(bytes), count: 2)
            delegate!.sendData(newData)
        }
        
        
        //Set all pin modes active
        for cell in cells {
            modeControlChanged(cell!.modeControl)
        }
        
        
        //Request mode and state for each pin
//        let data0:UInt8 = SYSEX_START
//        let data1:UInt8 = 0x6D
//        let data3:UInt8 = SYSEX_END
//        for cell in cells {
//            let data2:UInt8 = UInt8(cell!.digitalPin)
//            let bytes:[UInt8] = [data0, data1, data2, data3]
//            let newData = NSData(bytes: bytes, length: 3)
//            self.delegate!.sendData(newData)
//        }
        
        
        
    }
    
    
    func setDigitalStateReportingForPin(_ digitalPin:UInt8, enabled:Bool){
    
        //Enable input/output for a digital pin
        
        printLog(self, funcName: (#function), logString: " \(digitalPin)")
        
        //port 0: digital pins 0-7
        //port 1: digital pins 8-15
        //port 2: digital pins 16-23
        
        //find port for pin
        let port:UInt8 = digitalPin/8
        let pin:UInt8 = digitalPin - (port*8)
    
        let data0:UInt8 = 0xd0 + port        //start port 0 digital reporting (0xd0 + port#)
        var data1:UInt8 = UInt8(portMasks[Int(port)])    //retrieve saved pin mask for port;
    
        if (enabled){
            data1 |= 1<<pin
        }
        else{
            data1 ^= 1<<pin
        }
    
        let bytes:[UInt8] = [data0, data1]
        let newData = Data(bytes: UnsafePointer<UInt8>(bytes), count: 2)
    
        portMasks[Int(port)] = data1    //save new pin
    
        delegate!.sendData(newData)
    
    }
    
    
    func setDigitalStateReportingForPort(_ port:UInt8, enabled:Bool) {
        
        //Enable input/output for a digital pin
        
        //Enable by port
        let data0:UInt8 = 0xd0 + port  //start port 0 digital reporting (207 + port#)
        var data1:UInt8 = 0 //Enable
        if enabled {data1 = 1}
        
        let bytes:[UInt8] = [data0, data1]
        let newData = Data(bytes: UnsafePointer<UInt8>(bytes), count: 2)
        delegate!.sendData(newData)
        
    }
    
    
    func setAnalogValueReportingforPin(_ pin:Int, enabled:Bool){
        
        //Enable analog read for a pin
        
        //Enable by pin
        let data0:UInt8 = 0xC0 + UInt8(pin)          //start analog reporting for pin (192 + pin#)
        var data1:UInt8 = 0    //Enable
        if enabled {data1 = 1}
        
        let bytes:[UInt8] = [data0, data1]
        
        let newData = Data(bytes: UnsafePointer<UInt8>(bytes), count:2)
        
        delegate!.sendData(newData)
    }
    
    
    func systemReset() {
        
        //reset firmata
        let bytes:[UInt8] = [0xFF]
        let newData:Data = Data(bytes: UnsafePointer<UInt8>(bytes), count: 1)
        delegate!.sendData(newData)
        
    }
    
      
    //MARK: Pin I/O Controls
    
    func digitalControlChanged(_ sender:UISegmentedControl){
    
    //Respond to user setting a digital pin high/low
    
    //Change relevant cell's value label
        let cell:PinCell? = pinCellForPin(Int(sender.tag))
        if cell == nil {
            return
        }
    
    let state = Int(sender.selectedSegmentIndex)
    
        cell?.setDigitalValue(state)
    
    //Send value change to BLEBB
        let pin = cell?.digitalPin
        writePinState(pinStateForInt(Int(state)), pin: UInt8(pin!))
        
//        printLog(self, "digitalControlChanged", "state = \(state) : pin = \(pin)")
    
    }
    
    
    func pinStateForInt(_ stateInt:Int) ->PinState{
        
        var state:PinState
        
        switch stateInt {
         
        case PinState.high.rawValue:
            state = PinState.high
            break
        case PinState.low.rawValue:
            state = PinState.low
            break
        default:
            state = PinState.high
            break
        }
        
        return state
    }
    
    
    func cellButtonTapped(_ sender:UIButton!){
        
        //Respond to user tapping a cell's top area to open/close cell
        
        //find relevant indexPath
        let indexPath:IndexPath = indexPathForSubview(sender)
        
        //if same button is tapped as previous, close the cell
        if ((indexPath as NSIndexPath).compare(openCellPath) == ComparisonResult.orderedSame) {
            openCellPath = invalidCellPath
        }
        else {
            openCellPath = indexPath
        }
        
        updateTable()
        
        //if opening, scroll table until cell is visible after delay
        delay(0.25, closure: { () -> () in
            self.scrollToIndexPath(indexPath)
            return
        })
        
    }
    
    
    func modeControlChanged(_ sender:UISegmentedControl){
        
        //Change relevant cell's mode
        
        let cell:PinCell? = pinCellForPin(sender.tag)!
        
        if (cell == nil) {
            return
        }
        
        let mode:PinMode = pinModeforControl(sender)
        let prevMode:PinMode = cell!.mode
        cell?.mode = mode
        
        //Write pin
        writePinMode(mode, pin: UInt8(cell!.digitalPin))
        
        //Update reporting for Analog pins
        if cell?.mode == PinMode.analog {
            setAnalogValueReportingforPin(Int(cell!.analogPin), enabled: true)
//            setAnalogValueReportingforPin(Int(cell!.digitalPin), enabled: true)
        }
        else if prevMode == PinMode.analog{
            setAnalogValueReportingforPin(Int(cell!.analogPin), enabled: false)
//            setAnalogValueReportingforPin(Int(cell!.digitalPin), enabled: false)
        }
        
    }
    
    
    @IBAction func toggleDebugConsole(_ sender:AnyObject) {
    
    //For debugging in development
    
        if debugConsole?.isHidden == true{
            debugConsole?.isHidden = false
        }
        else{
            debugConsole?.isHidden = true
        }
    
    }
    
    
    func pinModeforControl(_ control:UISegmentedControl)->PinMode{
        
        //Convert segmented control selection to pin state
        
        let modeString:String = control.titleForSegment(at: control.selectedSegmentIndex)!
        
        var mode:PinMode = PinMode.unknown
        
        if modeString == "Input" {
            mode = PinMode.input
        }
        else if modeString == "Output" {
            mode = PinMode.output
        }
        else if modeString == "Analog" {
            mode = PinMode.analog
        }
        else if modeString == "PWM" {
            mode = PinMode.pwm
        }
        else if modeString == "Servo" {
            mode = PinMode.servo
        }
        
        return mode
    }
    
    
    func valueControlChanged(_ sender:UISlider){
        
        //Respond to PWM value slider changes
        
        //Limit the amount of messages we send over BLE
        let time = CACurrentMediaTime() //Get current time
        if (time - lastTime < 0.05) {       //Bail if we're trying to send a value too soon
            return
        }
        
        lastTime = time
        
        //Find relevant cell based on slider control's tag
        let cell:PinCell = pinCellForPin(sender.tag)!
        
        //Bail if we have a redundant value
        if (Int(cell.valueLabel.text!) == Int(sender.value)) {
            return
        }
        
        //Update the cell UI for the new value
        cell.setPwmValue(Int(sender.value))
        
        //Send the new value over BLE
        writePWMValue(UInt8(sender.value), pin: UInt8(cell.digitalPin))
        
    }
    
    
    //MARK: Outgoing Data
    
    func writePinState(_ newState: PinState, pin:UInt8){
        
        
        printLog(self, funcName: (#function), logString: "writing to pin: \(pin)")
        
        //Set an output pin's state
        
        var data0:UInt8  //Status
        var data1:UInt8  //LSB of bitmask
        var data2:UInt8  //MSB of bitmask
        
        //Status byte == 144 + port#
        let port:UInt8 = pin / 8
        data0 = 0x90 + port
        
        //Data1 == pin0State + 2*pin1State + 4*pin2State + 8*pin3State + 16*pin4State + 32*pin5State
        let pinIndex:UInt8 = pin - (port*8)
        var newMask = UInt8(newState.rawValue * Int(powf(2, Float(pinIndex))))
        
        portMasks[Int(port)] &= ~(1 << pinIndex) //prep the saved mask by zeroing this pin's corresponding bit
        newMask |= portMasks[Int(port)] //merge with saved port state
        portMasks[Int(port)] = newMask
        data1 = newMask<<1; data1 >>= 1  //remove MSB
        data2 = newMask >> 7 //use data1's MSB as data2's LSB
        
        let bytes:[UInt8] = [data0, data1, data2]
        let newData:Data = Data(bytes: UnsafePointer<UInt8>(bytes), count: 3)
        delegate!.sendData(newData)
        
        printLog(self, funcName: "setting pin states -->", logString: "[\(binaryforByte(portMasks[0]))] [\(binaryforByte(portMasks[1]))] [\(binaryforByte(portMasks[2]))]")
        
    }
    
    
    func writePWMValue(_ value:UInt8, pin:UInt8) {
        
        //Set an PWM output pin's value
        
        var data0:UInt8  //Status
        var data1:UInt8  //LSB of bitmask
        var data2:UInt8  //MSB of bitmask
        
        //Analog (PWM) I/O message
        data0 = 0xe0 + pin;
        data1 = value & 0x7F;   //only 7 bottom bits
        data2 = value >> 7;     //top bit in second byte
        
        let bytes:[UInt8] = [data0, data1, data2]
        let newData:Data = Data(bytes: UnsafePointer<UInt8>(bytes),count: 3)
        
        delegate!.sendData(newData)
        
    }
    
    
    func writePinMode(_ newMode:PinMode, pin:UInt8) {
    
        //Set a pin's mode
    
        let data0:UInt8 = 0xf4        //Status byte == 244
        let data1:UInt8 = pin        //Pin#
        let data2:UInt8 = UInt8(newMode.rawValue)    //Mode
    
        let bytes:[UInt8] = [data0, data1, data2]
        let newData:Data = Data(bytes: UnsafePointer<UInt8>(bytes), count: 3)
    
        delegate!.sendData(newData)
    
    }
    
    
    //MARK: Incoming Data
    
    func receiveData(_ newData:Data){
        
        //Respond to incoming data
        
//        printLog(self, funcName: (#function), logString: "length = \(newData.length)")
        
        
        var data = [UInt8](repeating: 0, count: 20)
        var buf = [UInt8](repeating: 0, count: 512)  //static only works on classes & structs in swift
        var length:Int = 0                               //again, was static
        let dataLength:Int = newData.count
        
        (newData as NSData).getBytes(&data, length: dataLength)
        
        
        //debugging digital pin reporting
//        print("Pin I/O receiveData: ", terminator:"")
//        for (var i = 0; i < newData.length; i++) {
//            if i == 0 {
//                print("PORT:\(Int(data[i]) - 0x90) ")
//            }
//            else { print("[\(binaryforByte(data[i]))] ", terminator: "") }
//        }
//        print("")
        //^^^^end of debugging digital pin reporting^^^^
        
        
//        if (dataLength < 20){
        
            memcpy(&buf, data, Int(dataLength))
            length += dataLength
            processInputData(buf, length: length)
//            length = 0
//        }
            
//        else if (dataLength == 20){
//            
//            memcpy(&buf, data, 20)
//            length += dataLength
//            
//            if (length >= 64){
//                processInputData(buf, length: length)
//                length = 0;
//            }
//        }
        
    }
    
    
    func processInputData(_ data:[UInt8], length:Int) {
        
        //Parse data we received
    
        printLog(self, funcName: "processInputData", logString: "data[0] = \(data[0]) : length = \(length)")
        
        if ((pinQueryStatus == PinQueryStatus.notStarted) ||
            (pinQueryStatus == PinQueryStatus.capabilityInProgress) ||
            (pinQueryStatus == PinQueryStatus.analogMappingInProgress)) {
            
            //Capability query response - starts w 0xF0 0x6C
            if ((pinQueryStatus == PinQueryStatus.notStarted && (data[0] == SYSEX_START && data[1] == 0x6C)) ||
                (pinQueryStatus == PinQueryStatus.capabilityInProgress)) {
                    
                    printLog(self, funcName: (#function), logString: "CAPABILITY QUERY DATA RECEIVED")
                    pinQueryStatus = PinQueryStatus.capabilityInProgress
                    parseIncomingCapabilityData(data, length: length)
                    
                    //Example Capability report …
                    //0xF0 0x6C                             start report
                    //0x0 0x0   0x1 0x0   0x7F              pin 0 can do i/o
                    //0x0 0x0   0x1 0x0   0x2 0xA   0x7F    pin 1 can do i/o + analog (10 bit)
                    //0x0 0x0   0x1 0x0   0x3 0x8   0x7F    pin 2 can do i/o + pwm (8 bit)
                    //0x7F                                  pin 3 is unavailable
                    //0xF7                                  end report
                    
                    return
                    
            }
                //Analog pin mapping query response - starts w 0xF0 0x6A
            else if ((pinQueryStatus == PinQueryStatus.capabilityInProgress && (data[0] == SYSEX_START && data[1] == 0x6A)) ||
                (pinQueryStatus == PinQueryStatus.analogMappingInProgress)){
                    printLog(self, funcName: (#function), logString: "ANALOG MAPPING DATA RECEIVED")
                    pinQueryStatus = PinQueryStatus.analogMappingInProgress
                    parseIncomingAnalogMappingData(data, length: length)
                    return
            }
            
            return
        }
        
        //Individual pin state response
        else if (data[0] == SYSEX_START && data[1] == 0x6E) {
            /* pin state response
            * -------------------------------
            * 0  START_SYSEX (0xF0) (MIDI System Exclusive)
            * 1  pin state response (0x6E)
            * 2  pin (0 to 127)
            * 3  pin mode (the currently configured mode)
            * 4  pin state, bits 0-6
            * 5  (optional) pin state, bits 7-13
            * 6  (optional) pin state, bits 14-20
            ...  additional optional bytes, as many as needed
            * N  END_SYSEX (0xF7)
            */
            
            printLog(self, funcName: (#function), logString: "INDIVIDUAL PIN STATE RECEIVED")
            let pin = data[2]
            let pinMode = data[3]
            let pinState = data[4]
            
            for cell in cells {
                if cell?.digitalPin == Int(pin) {
                    cell?.setMode(pinMode)
                    
                    if (pinMode > 1 ) && (data.count > 5){
                        let val = Int(data[4]) + (Int(data[5])<<7);
                        cell?.setAnalogValue(val)
                    }
                    else {
                        cell?.setDigitalValue(Int(pinState))
                    }
                }
            }
            return
        }
        
        //each pin state message is 3 bytes long
        for i in stride(from: 0, to: length, by: 3) {
            
            //Digital Reporting (per port)
            if ((data[i] >= 0x90) && (data[i] <= 0x9F)){
                var pinStates = Int(data[i+1])
                let port = Int(data[i]) - 0x90
                pinStates |= Int(data[i+2]) << 7    //PORT 0: use LSB of third byte for pin7, PORT 1: pins 14 & 15
                updateForPinStates(pinStates, port: port)
            }
            
            //Analog Reporting (per pin)
            else if ((data[i] >= 0xE0) && (data[i] <= 0xEF)) {
                let pin = Int(data[i]) - 0xE0
                let val = Int(data[i+1]) + (Int(data[i+2])<<7);
                let cell:PinCell? = pinCellForAnalogPin(Int(pin))
                cell?.setAnalogValue(val)
            }
        }
        
    }
    
    
    func parseIncomingCapabilityData(_ data:[UInt8], length:Int){
        
        for i in 0 ..< length {
            
            //skip start bytes
            if data[i] == SYSEX_START || data[i] == 0x6C {
                continue
            }
            
            //check for end byte
            else if data[i] == SYSEX_END {
                printLog(self, funcName: (#function), logString: "CAPABILITY QUERY ENDED")
                //capabilities complete, query analog pin mapping
                pinQueryStatus = PinQueryStatus.analogMappingInProgress
                queryAnalogPinMapping()
                
            }
            else {
                capabilityQueryData.append(data[i])
            }
        }
        
    }
    
    
    func endPinQuery() {
        
        printLog(self, funcName: (#function), logString: "END PIN QUERY")
        
        pinQueryTimer?.invalidate()  //stop timeout timer
        pinQueryStatus = PinQueryStatus.complete
        
        capabilityQueryAlert?.dismiss(animated: true, completion: { () -> Void in
            //code on completion
            self.parseCompleteCapabilityData()
            self.parseCompleteAnalogMappingData()
        })
        
    }
    
    
    func parseCompleteCapabilityData() {
        
        var allPins:[[UInt8]] = []
        var pinData:[UInt8] = []
        for i in 0 ..< capabilityQueryData.count {
            
            if capabilityQueryData[i] != 0x7F {
                pinData.append(capabilityQueryData[i])
            }
            else {
                allPins.append(pinData)
                pinData = []
            }
        }
        
        //print collected pin data
        var message = ""
        var pinNumber = 0
        var isAvailable = true, isInput = false, isOutput = false, isAnalog = false, isPWM = false
        var newCells:[PinCell?] = []
        for p in allPins {
            
            var str = ""
            if p.count == 0 {   //unavailable pin
                isAvailable = false
                str = " unavailable"
            }
            else {
                for var i in 0..<p.count {
                    let b = p[i]
//                    switch (b>>4) {
                    switch (b) {
                    case 0x00:
                        isInput = true
                        str += " input"
                        i += 1 //skip resolution byte
                    case 0x01:
                        isOutput = true
                        str += " output"
                        i += 1 //skip resolution byte
                    case 0x02:
                        isAnalog = true
                        str += " analog"
                        i += 1 //skip resolution byte
                    case 0x03:
                        isPWM = true
                        str += " pwm"
                        i += 1 //skip resolution byte
                    case 0x04:
//                        isServo = true
                        str += " servo"
                        i += 1 //skip resolution byte
                    case 0x06:
//                        isI2C = true
                        str += " I2C"
                        i += 1 //skip resolution byte
                    default:
                        break
                    }
                }
            }
            
            //string for debug
            let pinStr = "pin\(pinNumber):\(str)"
            message += pinStr + "\n"
            str = ""
            
            //create cell for pin and add to array
            if isAvailable {
                newCells.append(createPinCell(pinNumber, isDigital: (isInput && isOutput), isAnalog: isAnalog, isPWM: isPWM))
            }
            
            //prep vars for next cell
            isAvailable = true; isInput = false; isOutput = false; isAnalog = false; isPWM = false
            pinNumber += 1
        }
        
        cells = newCells
        
        //debug
//        print(message)
//        //debug with alert view
//        let paragraphStyle = NSMutableParagraphStyle()
//        paragraphStyle.alignment = NSTextAlignment.Left
//        let messageText = NSMutableAttributedString(
//            string: message,
//            attributes: [
//                NSParagraphStyleAttributeName: paragraphStyle,
//                NSFontAttributeName : UIFont.preferredFontForTextStyle(UIFontTextStyleCaption1),
//                NSForegroundColorAttributeName : UIColor.blackColor()
//            ]
//        )
//        let alert = UIAlertController(title: "received pin capabilities:", message: nil, preferredStyle: UIAlertControllerStyle.Alert)
//        alert.setValue(messageText, forKey: "attributedMessage")
//        let aOk = UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil)
//        alert.addAction(aOk)
//        self.presentViewController(alert, animated: true, completion: nil)
        //end debug
        
    }
    
    
    func parseIncomingAnalogMappingData(_ data:[UInt8], length:Int){
        
        for i in 0 ..< length {
            
            //skip start bytes
            if data[i] == SYSEX_START || data[i] == 0x6A {
                continue
            }
                
                //check for end byte
            else if data[i] == SYSEX_END {
                printLog(self, funcName: (#function), logString: "ANALOG MAPPING QUERY ENDED")
                endPinQuery()
            }
            else {
                analogMappingData.append(data[i])
            }
        }
        
    }
    
    
    func parseCompleteAnalogMappingData() {
        
        for i in 0 ..< analogMappingData.count {
            
            if analogMappingData[i] != 0x7F {
                let analogPin = analogMappingData[i]
//                printLog(self, funcName: (#function), logString: "pin\(i) = \(analogPin)")
                pinCellForPin(i)?.analogPin = Int(analogPin)
            }
        }
        
        self.enableReadReports()
        
        //reload table cells after delay
        delay(0.5) { () -> () in
            self.pinTable.reloadData()
        }
        
    }
    
    
    func updateDebugConsoleWithData(_ newData:Data) {
    
        //For debugging in dev
    
        let hexString:NSString = newData.hexRepresentationWithSpaces(true)
    
        debugConsole!.text = debugConsole!.text + "\n \(hexString)"
    
        //scroll output to bottom
        if (debugConsole!.isHidden == false) {
            let range = NSMakeRange(debugConsole!.text.characters.count, 0)
            debugConsole!.scrollRangeToVisible(range)
            
            debugConsole!.isScrollEnabled = false
            debugConsole!.isScrollEnabled = true
        }
    
    }
    
    
    func updateForPinStates(_ pinStates:Int, port:Int) {
        
        printLog(self, funcName: "getting pin states <--", logString: "[\(binaryforByte(portMasks[0]))] [\(binaryforByte(portMasks[1]))] [\(binaryforByte(portMasks[2]))]")
        
        //Update pin table with new pin values received
        
        let offset = 8 * port
        
        //Iterate through all  pins
        for i in stride(from: 0, to: 8, by: 1) {
            
            var state = pinStates
            let mask = 1 << i
            state = state & mask
            state = state >> i
            
            let cellIndex = i + Int(offset)
            
            pinCellForPin(cellIndex)?.setDigitalValue(state)
        }
        
        //Save reference state mask
        portMasks[port] = UInt8(pinStates)
        
    }
    
    
    //MARK: Table view data source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        return 1
    }
    
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {

            return "Available Pins"
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return cells.count;
        
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        //Return appropriate cell for a row index
        
        var cell:PinCell?
        
        if indexPath.row < cells.count {
//            print("requesting cell for row \(indexPath.row)")
            cell = cells[indexPath.row]
        }
        
        if (cell == nil){
//            print("-------> making a placeholder cell")
            cell = PinCell()
        }
        
        return cell!
    }
    
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        //Return height appropriate for cell state - open/closed
        
        var height = pinTable?.rowHeight
        let cellIndex = indexPath.row
        
        if (cellIndex >= cells.count) {
            return 0
        }
        
        var cell:PinCell?
        cell = cells[cellIndex]
        
        if (cell == nil) {
            return 0
        }
        
        //selected
        if ((indexPath as NSIndexPath).compare(openCellPath) == ComparisonResult.orderedSame) {
            let mode = cell?.mode
            if (mode == PinMode.input || mode == PinMode.analog) {
                height = ROW_HEIGHT_INPUT
            }
            else {
                height = ROW_HEIGHT_OUTPUT
            }
            
            cell?.backgroundColor = UIColor.white
        }
        
        //not selected
        else {
            cell?.backgroundColor = UIColor(white: 0.8, alpha: 1.0)
        }
        
        return height!
    }
    
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        //return height for title rows
        return HEADER_HEIGHT
        
    }
    
    
    func pinCellForPin(_ pin:Int) -> PinCell?{
        
        //Retrieve appropriate cell for a pin number
        
        var matchingCell:PinCell?
        
        for cell in cells {
            
            if cell == nil {
                continue
            }
            if Int(cell!.digitalPin) == pin {
                matchingCell = cell
                break
            }
        }
        
//        if matchingCell == nil {
//            printLog(self, funcName: "pinCellForPin", logString: "unable to find matching cell for pin \(pin)")
//        }
        
        return matchingCell
        
    }
    
    
    func pinCellForAnalogPin(_ pin:Int) -> PinCell?{
        
        //Retrieve appropriate cell for a pin number
        
        var matchingCell:PinCell?
        
        for cell in cells {
            
            if cell == nil {
                continue
            }
            if Int(cell!.analogPin) == pin {
                matchingCell = cell
                break
            }
        }
        
        //        if matchingCell == nil {
        //            printLog(self, funcName: "pinCellForPin", logString: "unable to find matching cell for pin \(pin)")
        //        }
        
        return matchingCell
        
    }
    
    
    //MARK: Helper methods
    
    func indexPathForSubview(_ theView:UIView) ->IndexPath{
        
        //Find the indexpath for the cell which contains theView
        
        var indexPath: IndexPath?
        var counter = 0
        let limit = 20
        var aView:UIView? = theView
        
        while (indexPath == nil) {
            if (counter > limit) {
                break
            }
            if aView?.superview is UITableViewCell {
                let theCell = aView?.superview as! UITableViewCell
                indexPath = pinTable?.indexPath(for: theCell)
            }
            else {
                aView = theView.superview
            }
            counter += 1;
        }
        
        return indexPath!
        
    }

    
    func updateTable(){
        
        //Animate row height changes for user selection
        
        pinTable!.beginUpdates()
        pinTable!.endUpdates()
        
    }
    
    
    func scrollToIndexPath(_ indexPath:IndexPath){
        
        //Scroll to a particular row on the table
        
        pinTable!.scrollToRow(at: indexPath, at: UITableViewScrollPosition.none, animated: true)
    }
    
    
    func cellModeUpdated(_ sender:AnyObject){
        
        //Respond to mode change for a cell
        
        self.updateTable()
        
    }
    
    
    func stringForPinMode(_ mode:PinMode)->NSString{
    
        var modeString: NSString
        
        switch mode {
        case PinMode.input:
            modeString = "Input"
            break
        case PinMode.output:
            modeString = "Output"
            break
        case PinMode.analog:
            modeString = "Analog"
            break
        case PinMode.pwm:
            modeString = "PWM"
            break
        case PinMode.servo:
            modeString = "Servo"
            break
        default:
            modeString = "NOT FOUND"
            break
        }
    
    return modeString
    
    }
    
}
