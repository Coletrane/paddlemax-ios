//
//  ControllerViewController.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 11/25/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

import UIKit
import CoreMotion
import CoreLocation

protocol ControllerViewControllerDelegate: HelpViewControllerDelegate {
    
    func sendData(_ newData:Data)
    
}

class ControllerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, CLLocationManagerDelegate {
    
    
    var delegate:UARTViewControllerDelegate?
    @IBOutlet var helpViewController:HelpViewController!
    @IBOutlet var controlPadViewController:UIViewController!
    @IBOutlet var buttons:[UIButton]!
    @IBOutlet var exitButton:UIButton!
    @IBOutlet var controlTable:UITableView!
    @IBOutlet var valueCell:SensorValueCell!
    
    var accelButton:BLESensorButton!
    var gyroButton: BLESensorButton!
    var magnetometerButton: BLESensorButton!
    var gpsButton:BLESensorButton!
    var quatButton:BLESensorButton!
    var buttonColor:UIColor!
    var exitButtonColor:UIColor!
    
    enum SensorType:Int {   //raw values used for reference
        case qtn
        case accel
        case gyro
        case mag
        case gps
    }
    
    struct Sensor {
        var type:SensorType
        var data:Data?
        var prefix:String
        var valueCells:[SensorValueCell]
        var toggleButton:BLESensorButton
        var enabled:Bool
    }
    
//    struct gpsData {
//        var x:Double
//        var y:Double
//        var z:Double
//    }
    
    fileprivate let cmm = CMMotionManager()
    fileprivate var locationManager:CLLocationManager?
    fileprivate let accelDataPrefix = "!A"
    fileprivate let gyroDataPrefix  = "!G"
    fileprivate let magDataPrefix   = "!M"
    fileprivate let gpsDataPrefix   = "!L"
    fileprivate let qtnDataPrefix   = "!Q"
    fileprivate let updateInterval  = 0.1
    fileprivate let pollInterval    = 0.1     //nonmatching update & poll intervals can interfere w switch animation even when using qeueus & timer tolerance
    fileprivate let gpsInterval     = 30.0
    fileprivate var gpsFlag         = false
    fileprivate var lastGPSData:Data?
    var sensorArray:[Sensor]!
    fileprivate var sendSensorIndex = 0
    fileprivate var sendTimer:Timer?
    fileprivate var gpsTimer:Timer?   //send gps data at interval even if it hasn't changed
    fileprivate let buttonPrefix = "!B"
    fileprivate let colorPrefix = "!C"
//    private let sensorQueue = dispatch_queue_create("com.adafruit.bluefruitconnect.sensorQueue", DISPATCH_QUEUE_SERIAL)
    fileprivate var locationAlert:UIAlertController?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        //setup help view
        self.helpViewController.title = "Controller Help"
        self.helpViewController.delegate = delegate
        
        
        
        //button stuff
        buttonColor = buttons[0].backgroundColor
        for b in buttons {
            b.layer.cornerRadius = 4.0
        }
        exitButtonColor = exitButton.backgroundColor
        exitButton.layer.cornerRadius = 4.0
        
        sensorArray = [
            Sensor(type: SensorType.qtn,
                data: nil, prefix: qtnDataPrefix,
                valueCells:[newValueCell("x"), newValueCell("y"), newValueCell("z"), newValueCell("w")],
                toggleButton: self.newSensorButton(0),
                enabled: false),
            Sensor(type: SensorType.accel,
                data: nil, prefix: accelDataPrefix,
                valueCells:[newValueCell("x"), newValueCell("y"), newValueCell("z")],
                toggleButton: self.newSensorButton(1),
                enabled: false),
            Sensor(type: SensorType.gyro,
                data: nil, prefix: gyroDataPrefix,
                valueCells:[newValueCell("x"), newValueCell("y"), newValueCell("z")],
                toggleButton: self.newSensorButton(2),
                enabled: false),
            Sensor(type: SensorType.mag,
                data: nil, prefix: magDataPrefix,
                valueCells:[newValueCell("x"), newValueCell("y"), newValueCell("z")],
                toggleButton: self.newSensorButton(3),
                enabled: false),
            Sensor(type: SensorType.gps,
                data: nil, prefix: gpsDataPrefix,
                valueCells:[newValueCell("lat"), newValueCell("lng"), newValueCell("alt")],
                toggleButton: self.newSensorButton(4),
                enabled: false)
        ]
        
        quatButton = sensorArray[0].toggleButton
        accelButton = sensorArray[1].toggleButton
        gyroButton = sensorArray[2].toggleButton
        magnetometerButton = sensorArray[3].toggleButton
        gpsButton = sensorArray[4].toggleButton
        
        //Set up recurring timer for sending sensor data
        sendTimer = Timer(timeInterval: updateInterval, target: self, selector: #selector(ControllerViewController.sendSensorData(_:)), userInfo: nil, repeats: true)
        sendTimer!.tolerance = 0.25
        RunLoop.current.add(sendTimer!, forMode: RunLoopMode.defaultRunLoopMode)
        
        //Set up minimum recurring timer for sending gps data when unchanged
        gpsTimer = newGPSTimer()
        //gpsTimer is added to the loop when gps data is enabled
        
        //Register to be notified when app returns to active
        NotificationCenter.default.addObserver(self, selector: #selector(ControllerViewController.checkLocationServices), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)
        
        //Check to see if location services are enabled
//        checkLocationServices()
        
//        if checkLocationServices() == false {
//            //Warn the user that GPS isn't available
//            locationAlert = UIAlertController(title: "Location Services disabled", message: "Enable Location Services in \nSettings->Privacy to allow location data to be sent over Bluetooth", preferredStyle: UIAlertControllerStyle.Alert)
//            let aaOK = UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil)
//            locationAlert!.addAction(aaOK)
//            self.presentViewController(locationAlert!, animated: true, completion: { () -> Void in
//                //Set switch enabled again after alert close in case the user enabled services
//                let verdict = self.checkLocationServices()
//            })
//        }
//        
//        else {
//            locationAlert?.dismissViewControllerAnimated(true, completion: { () -> Void in
//            })
//            
//            self.checkLocationServices()
//        }
        
    }
    
    
    func checkLocationServices()->Bool {
        
        var verdict = false
        if (CLLocationManager.locationServicesEnabled() && CLLocationManager.authorizationStatus() == CLAuthorizationStatus.authorizedWhenInUse) {
            verdict = true
        }
//        gpsButton.dimmed = !verdict
        return verdict
        
    }
    
    
    func showLocationServicesAlert(){
        
        //Warn the user that GPS isn't available
        locationAlert = UIAlertController(title: "Location Services disabled", message: "Enable Location Services in \nSettings->Privacy to allow location data to be sent over Bluetooth", preferredStyle: UIAlertControllerStyle.alert)
        let aaOK = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { (aa:UIAlertAction!) -> Void in
            
        })
        locationAlert!.addAction(aaOK)
        self.present(locationAlert!, animated: true, completion: { () -> Void in
            //Set switch enabled again after alert close in case the user enabled services
            //                self.gpsButton.enabled = CLLocationManager.locationServicesEnabled()
        })
        
    }
    
    
    func newGPSTimer()->Timer {
        
        let newTimer = Timer(timeInterval: gpsInterval, target: self, selector: #selector(ControllerViewController.gpsIntervalComplete(_:)), userInfo: nil, repeats: true)
        newTimer.tolerance = 1.0
        
        return newTimer
    }
    
    
    func removeGPSTimer() {
        
        gpsTimer?.invalidate()
        gpsTimer = nil
        
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        
        // Stop updates if we're returning to main view
        if self.isMovingFromParentViewController {
            stopSensorUpdates()
            //Stop receiving app active notification
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        }
        
        super.viewWillDisappear(animated)
        
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    convenience init(aDelegate:UARTViewControllerDelegate){
        
        //Separate NIBs for iPhone 3.5", iPhone 4", & iPad
        
        var nibName:NSString
        
        if IS_IPHONE {
            nibName = "ControllerViewController_iPhone"
        }
        else{   //IPAD
            nibName = "ControllerViewController_iPad"
        }
        
        self.init(nibName: nibName as String, bundle: Bundle.main)
        
        self.delegate = aDelegate
        self.title = "Controller"
        self.sensorArray = []
    }
    

    func sensorButtonTapped(_ sender: UIButton) {
        
        
//        print("--------> button \(sender.tag) state is ")
//        if sender.selected {
//            print("SELECTED")
//        }
//        else {
//            print("DESELECTED")
//        }
        
        
        
        
//        //Check to ensure switch is not being set redundantly
//        if sensorArray[sender.tag].enabled == sender.selected {
////            println(" - redundant!")
//            sender.userInteractionEnabled = true
//            return
//        }
//        else {
////            println("")
//            sensorArray[sender.tag].enabled = sender.selected
//        }
        
        //Accelerometer
        if sender === accelButton {
            
            //rows to add or remove
            let valuePaths: [IndexPath] = [
                IndexPath(row: 1, section: 1),
                IndexPath(row: 2, section: 1),
                IndexPath(row: 3, section: 1)
            ]
            
            if (sender.isSelected == false) {
                
                if cmm.isAccelerometerAvailable == true {
                    cmm.accelerometerUpdateInterval = pollInterval
                    cmm.startAccelerometerUpdates(to: OperationQueue.main, withHandler: { (data:CMAccelerometerData?, error:NSError?) -> Void in
                        self.didReceiveAccelData( CMAccelerometerData, error: error )
                    } as! CMAccelerometerHandler)
                    
                    sender.isSelected = true
                    
                    //add rows for sensor values
                    controlTable.beginUpdates()
                    controlTable.insertRows(at: valuePaths , with: UITableViewRowAnimation.fade)
                    controlTable.endUpdates()
                    
                }
                else {
                    printLog(self, funcName: "buttonValueChanged", logString: "accelerometer unavailable")
                }
            }
                //button switched off
            else {
                
                sender.isSelected = false
                
                //remove rows for sensor values
                controlTable.beginUpdates()
                controlTable.deleteRows(at: valuePaths, with: UITableViewRowAnimation.fade)
                controlTable.endUpdates()
                
                cmm.stopAccelerometerUpdates()
                
            }
        }
         
        //Gyro
        else if sender === gyroButton {
            
            //rows to add or remove
            let valuePaths: [IndexPath] = [
                IndexPath(row: 1, section: 2),
                IndexPath(row: 2, section: 2),
                IndexPath(row: 3, section: 2)
            ]
            
            if (sender.isSelected == false) {
                
                if cmm.isGyroAvailable == true {
                    cmm.gyroUpdateInterval = pollInterval
//                    let handler = { (data:CMGyroData?, error:NSError?) -> Void in
//                        self.didReceiveGyroData( <#CMGyroData!#>, error: error )
//                    } as! CMGyroHandler
                    cmm.startGyroUpdates(to: OperationQueue.main)
                    sender.isSelected = true
                    //add rows for sensor values
                    controlTable.beginUpdates()
                    controlTable.insertRows(at: valuePaths, with: UITableViewRowAnimation.fade)
                    controlTable.endUpdates()
                }
                else {
                    printLog(self, funcName: "buttonValueChanged", logString: "gyro unavailable")
                }
                
            }
                //button switched off
            else {
                sender.isSelected = false
                //remove rows for sensor values
                controlTable.beginUpdates()
                controlTable.deleteRows(at: valuePaths, with: UITableViewRowAnimation.fade)
                controlTable.endUpdates()
                
                cmm.stopGyroUpdates()
            }
        }
            
        //Magnetometer
        else if sender === magnetometerButton {
            
            //rows to add or remove
            let valuePaths: [IndexPath] = [
                IndexPath(row: 1, section: 3),
                IndexPath(row: 2, section: 3),
                IndexPath(row: 3, section: 3)
            ]
            
            if (sender.isSelected == false) {
                if cmm.isMagnetometerAvailable == true {
                    cmm.magnetometerUpdateInterval = pollInterval
//                    let handler = { (data:CMMagnetometerData?, error:NSError?) -> Void in
//                        self.didReceiveMagnetometerData( <#CMMagnetometerData!#>, error: error )
//                        } as! CMMagnetometerHandler
                    cmm.startMagnetometerUpdates(to: OperationQueue.main)
                    sender.isSelected = true
                    //add rows for sensor values
                    controlTable.beginUpdates()
                    controlTable.insertRows(at: valuePaths, with: UITableViewRowAnimation.fade)
                    controlTable.endUpdates()
                }
                else {
                    printLog(self, funcName: "buttonValueChanged", logString: "magnetometer unavailable")
                }
            }
                //button switched off
            else {
                sender.isSelected = false
                //remove rows for sensor values
                controlTable.beginUpdates()
                controlTable.deleteRows(at: valuePaths, with: UITableViewRowAnimation.fade)
                controlTable.endUpdates()
                
                cmm.stopMagnetometerUpdates()
                
            }
        }
            
        //GPS
        else if sender === gpsButton {
            
            //rows to add or remove
            let valuePaths: [IndexPath] = [
                IndexPath(row: 1, section: 4),
                IndexPath(row: 2, section: 4),
                IndexPath(row: 3, section: 4)
            ]
            
            if (sender.isSelected == false) {
                
                if locationManager == nil {
                    
                    locationManager = CLLocationManager()
                    locationManager?.delegate = self
                    locationManager?.desiredAccuracy = kCLLocationAccuracyBest
                    locationManager?.distanceFilter = kCLDistanceFilterNone
                    
                    //Check for authorization
                    if locationManager?.responds(to: #selector(CLLocationManager.requestWhenInUseAuthorization)) == true {
                        if CLLocationManager.authorizationStatus() != CLAuthorizationStatus.authorizedWhenInUse {
                            locationManager?.requestWhenInUseAuthorization()
                            gpsButton.isSelected = false
                            return
                        }
                    }
                    else {
                        printLog(self, funcName: "buttonValueChanged", logString: "Location Manager authorization not found")
                        gpsButton.isSelected = false
                        removeGPSTimer()
                        locationManager = nil
                        return
                    }
                }
                
                if CLLocationManager.authorizationStatus() == CLAuthorizationStatus.authorizedWhenInUse {
                    locationManager?.startUpdatingLocation()
                    
                    //add gpstimer to loop
                    if gpsTimer == nil { gpsTimer = newGPSTimer() }
                    RunLoop.current.add(gpsTimer!, forMode: RunLoopMode.defaultRunLoopMode)
                    
                    sender.isSelected = true
                    //add rows for sensor values
                    controlTable.beginUpdates()
                    controlTable.insertRows(at: valuePaths, with: UITableViewRowAnimation.fade)
                    controlTable.endUpdates()
                    
                }
                else {
//                    printLog(self, "buttonValueChanged", "Location Manager not authorized")
                    showLocationServicesAlert()
                    return
                }
                
            }
                //button switched off
            else {
                sender.isSelected = false
                //remove rows for sensor values
                controlTable.beginUpdates()
                controlTable.deleteRows(at: valuePaths, with: UITableViewRowAnimation.fade)
                controlTable.endUpdates()
                
                //remove gpstimer from loop
                removeGPSTimer()
                
                locationManager?.stopUpdatingLocation()
            }
        }
            
        //Quaternion / Device Motion
        else if sender === quatButton {
            //rows to add or remove
            let valuePaths: [IndexPath] = [
                IndexPath(row: 1, section: 0),
                IndexPath(row: 2, section: 0),
                IndexPath(row: 3, section: 0),
                IndexPath(row: 4, section: 0)
            ]
            
            if (sender.isSelected == false) {
                if cmm.isDeviceMotionAvailable == true {
                    cmm.deviceMotionUpdateInterval = pollInterval
//                    let handler = { (cmdm:CMDeviceMotion?, error:NSError?) -> Void in
//                        self.didReceivedDeviceMotion( <#CMDeviceMotion!#>, error: error )
//                        } as! CMDeviceMotionHandler
                    cmm.startDeviceMotionUpdates(to: OperationQueue.main)
                    
                    sender.isSelected = true
                    //add rows for sensor values
                    controlTable.beginUpdates()
                    controlTable.insertRows(at: valuePaths, with: UITableViewRowAnimation.fade)
                    controlTable.endUpdates()
                }
                else {
                    printLog(self, funcName: "buttonValueChanged", logString: "device motion unavailable")
                }
            }
                //button switched off
            else {
                
                sender.isSelected = false
                //remove rows for sensor values
                controlTable.beginUpdates()
                controlTable.deleteRows(at: valuePaths, with: UITableViewRowAnimation.fade)
                controlTable.endUpdates()
                
                cmm.stopDeviceMotionUpdates()
            }
        }
       
    }
    
    
    func newSensorButton(_ tag:Int)->BLESensorButton {
        
        
        let aButton = BLESensorButton()
        aButton.tag = tag
        
//        let offColor = bleBlueColor
//        let onColor = UIColor.whiteColor()
//        aButton.titleLabel?.font = UIFont.systemFontOfSize(14.0)
//        aButton.setTitle("OFF", forState: UIControlState.Normal)
//        aButton.setTitle("ON", forState: UIControlState.Selected)
//        aButton.setTitleColor(offColor, forState: UIControlState.Normal)
//        aButton.setTitleColor(onColor, forState: UIControlState.Selected)
//        aButton.setTitleColor(UIColor.lightGrayColor(), forState: UIControlState.Disabled)
//        aButton.backgroundColor = UIColor.whiteColor()
//        aButton.setBackgroundImage(UIImage(named: "ble_blue_1px.png"), forState: UIControlState.Selected)
//        aButton.layer.cornerRadius = 8.0
//        aButton.clipsToBounds = true
//        aButton.layer.borderColor = offColor.CGColor
//        aButton.layer.borderWidth = 1.0
        
        
        aButton.isSelected = false
        aButton.addTarget(self, action: #selector(ControllerViewController.sensorButtonTapped(_:)), for: UIControlEvents.touchUpInside)
        aButton.frame = CGRect(x: 0.0, y: 0.0, width: 75.0, height: 30.0)
        
        return aButton
    }
    
    
    func newValueCell(_ prefixString:String!)->SensorValueCell {
        
        let cellData = NSKeyedArchiver.archivedData(withRootObject: self.valueCell)
        let cell:SensorValueCell = NSKeyedUnarchiver.unarchiveObject(with: cellData) as! SensorValueCell
        cell.selectionStyle = UITableViewCellSelectionStyle.none
        cell.valueLabel = cell.viewWithTag(100) as! UILabel
//        let cell = SensorValueCell()
        
        cell.prefixString = prefixString
        
        return cell
        
    }
    
    
    func showNavbar(){
        
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        
    }
    
    
    //MARK: Sensor data
    
    func didReceivedDeviceMotion(_ cmdm:CMDeviceMotion!, error:NSError!) {
        
        storeSensorData(SensorType.qtn, x: cmdm.attitude.quaternion.x, y: cmdm.attitude.quaternion.y, z: cmdm.attitude.quaternion.z, w: cmdm.attitude.quaternion.w)
        
    }
    
    
    func didReceiveAccelData(_ aData:CMAccelerometerData!, error:NSError!) {
        
//        println("ACC X:\(Float(accelData.acceleration.x)) Y:\(Float(accelData.acceleration.y)) Z:\(Float(accelData.acceleration.z))")
        
        storeSensorData(SensorType.accel, x: aData.acceleration.x, y: aData.acceleration.y, z: aData.acceleration.z, w:nil)
        
        
    }
    
    
    func didReceiveGyroData(_ gData:CMGyroData!, error:NSError!) {
        
//        println("GYR X:\(gyroData.rotationRate.x) Y:\(gyroData.rotationRate.y) Z:\(gyroData.rotationRate.z)")
        
        storeSensorData(SensorType.gyro, x: gData.rotationRate.x, y: gData.rotationRate.y, z: gData.rotationRate.z, w:nil)
        
    }
    
    
    func didReceiveMagnetometerData(_ mData:CMMagnetometerData!, error:NSError!) {
        
//        println("MAG X:\(magData.magneticField.x) Y:\(magData.magneticField.y) Z:\(magData.magneticField.z)")
        
        storeSensorData(SensorType.mag, x: mData.magneticField.x, y: mData.magneticField.y, z: mData.magneticField.z, w:nil)
        
    }
    
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        let loc = locations.last as CLLocation!
        
        let eventDate = loc?.timestamp
        let howRecent = eventDate?.timeIntervalSinceNow
        if (abs(howRecent) < 15)
//            || (gpsFlag == true)
        {
//            gpsFlag = false
            //Check for invalid accuracy
            if loc?.horizontalAccuracy < 0.0 || loc?.verticalAccuracy < 0.0 {
                return
            }
            
            //Debug
            //            let lat = loc.coordinate.latitude
            //            let lng = loc.coordinate.longitude
            //            let alt = loc.altitude
            //            println("-------------------------------")
            //            println(String(format: "Location Double: %.32f, %.32f", lat, lng))
            //            println(String(format: "Location Float:  %.32f, %.32f", Float(lat), Float(lng)))
            //            println("-------------------------------")
            
            storeSensorData(SensorType.gps, x: (loc?.coordinate.latitude)!, y: (loc?.coordinate.longitude)!, z: (loc?.altitude)!, w:nil)
            
        }
    }
    
    
    func storeSensorData(_ type:SensorType, x:Double, y:Double, z:Double, w:Double?) {    //called in sensor queue
        
        let idx = type.rawValue
        
        let data = NSMutableData(capacity: 0)!
        let pfx = NSString(string: sensorArray[idx].prefix)
        var xv = Float(x)
        var yv = Float(y)
        var zv = Float(z)
        
        data.append(pfx.utf8String!, length: pfx.length)
        data.append(&xv, length: MemoryLayout<Float>.size)
        sensorArray[idx].valueCells[0].updateValue(xv)
        data.append(&yv, length: MemoryLayout<Float>.size)
        sensorArray[idx].valueCells[1].updateValue(yv)
        data.append(&zv, length: MemoryLayout<Float>.size)
        sensorArray[idx].valueCells[2].updateValue(zv)
        
        if w != nil {
            var wv = Float(w!)
            data.append(&wv, length: MemoryLayout<Float>.size)
            sensorArray[idx].valueCells[3].updateValue(wv)
        }
        
        appendCRCmutable(data)
        
        sensorArray[idx].data = data as Data
        
    }
    
    
    func sendSensorData(_ timer:Timer) {
        
        let startIdx = sendSensorIndex
        
        var data:Data?
        
        while data == nil {
            data = sensorArray[sendSensorIndex].data
            if data != nil {
                
//                println("------------------> Found sensor data \(sensorArray[sendSensorIndex].prefix)")
                delegate?.sendData(data!)
                if sensorArray[sendSensorIndex].type == SensorType.gps { lastGPSData = data }   // Store last gps data sent for min updates
                sensorArray[sendSensorIndex].data = nil
                incrementSensorIndex()
                return
            }
            
            incrementSensorIndex()
            if startIdx == sendSensorIndex {
//                println("------------------> No new data to send")
                return
            }
        }
        
    }
    
    
    func gpsIntervalComplete(_ timer:Timer) {
        
        //set last gpsdata sent as next gpsdata to send
        for i in 0...(sensorArray.count-1) {
            if (sensorArray[i].type == SensorType.gps) && (sensorArray[i].data == nil) {
//                println("--> gpsIntervalComplete - reloading last gps data")
                sensorArray[i].data = lastGPSData
                break
            }
        }
        
    }
    
    
    func incrementSensorIndex(){
        
        sendSensorIndex += 1
        if sendSensorIndex >= sensorArray.count {
            sendSensorIndex = 0
        }
        
    }
    
    
    func stopSensorUpdates(){
        
        sendTimer?.invalidate()
        
        removeGPSTimer()
        
        accelButton.isSelected = false
        cmm.stopAccelerometerUpdates()
        
        gyroButton.isSelected = false
        cmm.stopGyroUpdates()
        
        magnetometerButton.isSelected = false
        cmm.stopMagnetometerUpdates()
        
        cmm.stopDeviceMotionUpdates()
        
        gpsButton.isSelected = false
        locationManager?.stopUpdatingLocation()
        
    }
    
    
    //MARK: TableView
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = UITableViewCell(style: UITableViewCellStyle.default, reuseIdentifier: nil)
        var buttonView:UIButton?
        
        if indexPath.section == (sensorArray.count){
            cell.textLabel!.text = "Control Pad"
            cell.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
            cell.selectionStyle = UITableViewCellSelectionStyle.blue
            return cell
        }
        else if indexPath.section == sensorArray.count {
            cell.textLabel?.text = "Control Pad"
            cell.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
            cell.selectionStyle = UITableViewCellSelectionStyle.blue
            return cell
        }
        else if indexPath.section == (sensorArray.count + 1){
            cell.textLabel!.text = "Color Picker"
            cell.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
            cell.selectionStyle = UITableViewCellSelectionStyle.blue
            return cell
        }
        
        cell.selectionStyle = UITableViewCellSelectionStyle.none
        
        if indexPath.row == 0 {
            switch indexPath.section {
            case 0:
                cell.textLabel!.text = "Quaternion"
                buttonView = quatButton
            case 1:
                cell.textLabel!.text = "Accelerometer"
                buttonView = accelButton
            case 2:
                cell.textLabel!.text = "Gyro"
                buttonView = gyroButton
            case 3:
                cell.textLabel!.text = "Magnetometer"
                buttonView = magnetometerButton
            case 4:
                cell.textLabel!.text = "Location"
                buttonView = gpsButton
            default:
                break
            }
            
            cell.accessoryView = buttonView
            return cell
        }
        
        else {
            
//            switch indexPath.section {
//            case 0:
//                break
//            case 1: //Accel
//                cell.textLabel!.text = "TEST"
//            case 2: //Gyro
//                cell.textLabel!.text = "TEST"
//            case 3: //Mag
//                cell.textLabel!.text = "TEST"
//            case 4: //GPS
//                cell.textLabel!.text = "TEST"
//            default:
//                break
//            }
            
            return sensorArray[indexPath.section].valueCells[indexPath.row-1]
            
        }
        
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if section < sensorArray.count {
            let snsr = sensorArray[section]
            if snsr.toggleButton.isSelected == true {
                return snsr.valueCells.count+1
            }
            else {
                return 1
            }
        }
        
        else {
            return 1
        }

    }
    
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        if indexPath.row == 0 {
            return 44.0
        }
        else {
            return 28.0
        }
        
    }
    
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        if section == 0 {
            return 44.0
        }
        else if section == sensorArray.count {
            return 44.0
        }
        else {
            return 0.5
        }
    }
    
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        
        return 0.5
        
    }
    
    
    func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int {
        
        if indexPath.row == 0 {
            return 0
        }
        
        else {
            return 1
        }
        
    }
    
    
    func numberOfSections(in tableView: UITableView) -> Int {
    
        return sensorArray.count + 2
    
    }
    
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        if section == 0 {
            return "Stream Sensor Data"
        }
        
        else if section == sensorArray.count {
            return "Module"
        }
        
        else {
            return nil
        }
    }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if indexPath.section == sensorArray.count {
            tableView.deselectRow(at: indexPath, animated: false)
            self.navigationController?.pushViewController(controlPadViewController, animated: true)
            
            if IS_IPHONE {  //Hide nav bar on iphone to conserve space
                self.navigationController?.setNavigationBarHidden(true, animated: true)
            }
        }
        else if indexPath.section == (sensorArray.count + 1) {
            tableView.deselectRow(at: indexPath, animated: false)
            
        }
        
    }
    
    
    //MARK: Control Pad
    
    @IBAction func controlPadButtonPressed(_ sender:UIButton) {
    
//        println("PRESSED \(sender.tag)")
        
        sender.backgroundColor = cellSelectionColor
        
        controlPadButtonPressedWithTag(sender.tag)
    
    }
    
    
    func controlPadButtonPressedWithTag(_ tag:Int) {
        
        let str = NSString(string: buttonPrefix + "\(tag)" + "1")
        let data = Data(bytes: UnsafePointer<UInt8>(str.utf8String!), count: str.length)
        
        delegate?.sendData(appendCRC(data) as Data)
        
    }
    
    
    @IBAction func controlPadButtonReleased(_ sender:UIButton) {
        
//        println("RELEASED \(sender.tag)")
        
        sender.backgroundColor = buttonColor
        
        controlPadButtonReleasedWithTag(sender.tag)
    }
    
    
    func controlPadButtonReleasedWithTag(_ tag:Int) {
        
        let str = NSString(string: buttonPrefix + "\(tag)" + "0")
        let data = Data(bytes: UnsafePointer<UInt8>(str.utf8String!), count: str.length)
        
        delegate?.sendData(appendCRC(data) as Data)
    }
    
    
    @IBAction func controlPadExitPressed(_ sender:UIButton) {
        
        sender.backgroundColor = buttonColor
        
    }
    
    
    @IBAction func controlPadExitReleased(_ sender:UIButton) {
        
        sender.backgroundColor = exitButtonColor
        
        navigationController?.popViewController(animated: true)
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        
    }
    
    
    @IBAction func controlPadExitDragOutside(_ sender:UIButton) {
        
        sender.backgroundColor = exitButtonColor
        
    }
    
    
    //WatchKit functions
    func controlPadButtonTappedWithTag(_ tag:Int){
        
        //Press and release button
        controlPadButtonPressedWithTag(tag)
        delay(0.1, closure: { () -> () in
            self.controlPadButtonReleasedWithTag(tag)
        })
    }
    
    
    func appendCRCmutable(_ data:NSMutableData) {
        
        //append crc
        let len = data.length
        var bdata = [UInt8](repeating: 0, count: len)
//        var buf = [UInt8](count: len, repeatedValue: 0)
        var crc:UInt8 = 0
        data.getBytes(&bdata, length: len)
        
        for i in bdata {    //add all bytes
            crc = crc &+ i
        }
        
        crc = ~crc  //invert
        
        data.append(&crc, length: 1)
        
//        println("crc == \(crc)   length == \(data.length)")
        
    }
    
    
    func appendCRC(_ data:Data)->NSMutableData {
        
        let mData = NSMutableData(length: 0)
        mData!.append(data)
        appendCRCmutable(mData!)
        return mData!
        
    }
    
    
    //Color Picker
    
    func sendColor(_ red:UInt8, green:UInt8, blue:UInt8) {
        
        let pfx = NSString(string: colorPrefix)
        var rv = red
        var gv = green
        var bv = blue
        let data = NSMutableData(capacity: 3 + pfx.length)!
        
        data.append(pfx.utf8String!, length: pfx.length)
        data.append(&rv, length: 1)
        data.append(&gv, length: 1)
        data.append(&bv, length: 1)
        
        appendCRCmutable(data)
        
        delegate?.sendData(data as Data)
        
    }
    
    
    func helpViewControllerDidFinish(_ controller : HelpViewController) {
        
        delegate?.helpViewControllerDidFinish(controller)
        
    }
    
    
}










