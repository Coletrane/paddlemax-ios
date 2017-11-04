//
//  BLEMainViewController.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 10/13/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth

enum ConnectionMode:Int {
    case none
    case pinIO
    case uart
    case info
    case controller
    case dfu
}

protocol BLEMainViewControllerDelegate : AnyObject {
    func onDeviceConnectionChange(_ peripheral:CBPeripheral)
}

class BLEMainViewController : UIViewController, UINavigationControllerDelegate, HelpViewControllerDelegate, CBCentralManagerDelegate,
                              BLEPeripheralDelegate, UARTViewControllerDelegate, PinIOViewControllerDelegate, DeviceListViewControllerDelegate, FirmwareUpdaterDelegate {
    
    enum ConnectionStatus:Int {
        case idle = 0
        case scanning
        case connected
        case connecting
    }
    
    var connectionMode:ConnectionMode = ConnectionMode.none
    var connectionStatus:ConnectionStatus = ConnectionStatus.idle
    var helpPopoverController:UIPopoverController?
    var navController:UINavigationController!
    var pinIoViewController:PinIOViewController!
    var uartViewController:UARTViewController!
    var deviceListViewController:DeviceListViewController!
    var deviceInfoViewController:DeviceInfoViewController!
    var controllerViewController:ControllerViewController!
    var dfuViewController:DFUViewController!
    var delegate:BLEMainViewControllerDelegate?
    
    @IBOutlet var infoButton:UIButton!
    @IBOutlet var warningLabel:UILabel!
    
    @IBOutlet var helpViewController:HelpViewController!
    
    fileprivate var cm:CBCentralManager?
    fileprivate var currentAlertView:UIAlertController?
    fileprivate var currentPeripheral:BLEPeripheral?
    fileprivate var dfuPeripheral:CBPeripheral?
    fileprivate var infoBarButton:UIBarButtonItem?
    fileprivate var scanIndicator:UIActivityIndicatorView?
    fileprivate var scanIndicatorItem:UIBarButtonItem?
    fileprivate var scanButtonItem:UIBarButtonItem?
    fileprivate let cbcmQueue = DispatchQueue(label: "com.adafruit.bluefruitconnect.cbcmqueue", attributes: DispatchQueue.Attributes.concurrent)
    fileprivate let connectionTimeOutIntvl:TimeInterval = 30.0
    fileprivate var connectionTimer:Timer?
    fileprivate var firmwareUpdater : FirmwareUpdater?
    
    static let sharedInstance = BLEMainViewController()
    
    
    func centralManager()->CBCentralManager{
        
        return cm!;
        
    }
    
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        
        var newNibName:String
        
        if (IS_IPHONE){
            newNibName = "BLEMainViewController_iPhone"
        }
            
        else{
            newNibName = "BLEMainViewController_iPad"
        }
        
        super.init(nibName: newNibName, bundle: Bundle.main)
        
        //        println("init with NIB " + self.description)
        
    }
    
    
    required init(coder aDecoder: NSCoder) {
        
        super.init(coder: aDecoder)!
        
    }
    
    
    //for Objective-C delegate compatibility
    func setDelegate(_ newDelegate:AnyObject){
        
        if newDelegate.responds(to: Selector("onDeviceConnectionChange:")){
            delegate = newDelegate as? BLEMainViewControllerDelegate
        }
        else {
            printLog(self, funcName: "setDelegate", logString: "failed to set delegate")
        }
        
    }
    
    
    //MARK: View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        createDeviceListViewController()
        
        navController = UINavigationController(rootViewController: deviceListViewController)
        navController.delegate = self
        navController.navigationBar.barStyle = UIBarStyle.black
        navController.navigationBar.isTranslucent = false
        navController.toolbar.barStyle = UIBarStyle.black
        navController.toolbar.isTranslucent = false
        navController.isToolbarHidden = false
        navController.interactivePopGestureRecognizer?.isEnabled = false
        
        if IS_IPHONE {
            addChildViewController(navController)
            view.addSubview(navController.view)
        }
        
        // Create core bluetooth manager on launch
        if (cm == nil) {
            cm = CBCentralManager(delegate: self, queue: cbcmQueue)
            
            connectionMode = ConnectionMode.none
            connectionStatus = ConnectionStatus.idle
            currentAlertView = nil
        }
        
        //refresh updates for DFU
        FirmwareUpdater.refreshSoftwareUpdatesDatabase()
        let areAutomaticFirmwareUpdatesEnabled = UserDefaults.standard.bool(forKey: "updatescheck_preference");
        if (areAutomaticFirmwareUpdatesEnabled) {
            firmwareUpdater = FirmwareUpdater()
        }
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if (IS_IPAD) {
            addChildViewController(navController)
            view.addSubview(navController.view)
        }
        
        
        //FOR SCREENSHOTS
        //        connectionMode = ConnectionMode.Info
        //        connectionStatus = ConnectionStatus.Connected
        //        deviceInfoViewController = DeviceInfoViewController(cbPeripheral: <#CBPeripheral#>, delegate: <#HelpViewControllerDelegate#>)
        //        uartViewController.navigationItem.rightBarButtonItem = infoBarButton
        //        pushViewController(uartViewController)
        
    }
    
    
    func didBecomeActive() {
        
        // Application returned from background state
        
        // Adjust warning label
        if cm?.state == CBManagerState.poweredOff {
            
            warningLabel.text = "Bluetooth disabled"
            
        }
        else if deviceListViewController.devices.count == 0 {
            
            warningLabel.text = "No peripherals found"
            
        }
        else {
            warningLabel.text = ""
        }
        
    }
    
    
    //MARK: UI etc
    
    func helpViewControllerDidFinish(_ controller: HelpViewController) {
        
        //Called when help view's done button is tapped
        
        if (IS_IPHONE) {
            dismiss(animated: true, completion: nil)
        }
            
        else {
            helpPopoverController?.dismiss(animated: true)
        }
        
    }
    
    
    func createDeviceListViewController(){
        
        //add info bar button to mode controllers
        let archivedData = NSKeyedArchiver.archivedData(withRootObject: infoButton)
        let buttonCopy = NSKeyedUnarchiver.unarchiveObject(with: archivedData) as! UIButton
        buttonCopy.addTarget(self, action: #selector(BLEMainViewController.showInfo(_:)), for: UIControlEvents.touchUpInside)
        infoBarButton = UIBarButtonItem(customView: buttonCopy)
        deviceListViewController = DeviceListViewController(aDelegate: self)
        deviceListViewController.navigationItem.rightBarButtonItem = infoBarButton
        deviceListViewController.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Disconnect", style: UIBarButtonItemStyle.plain, target: nil, action: nil)
        //add scan indicator to toolbar
        scanIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.white)
        scanIndicator!.hidesWhenStopped = false
        scanIndicatorItem = UIBarButtonItem(customView: scanIndicator!)
        let space = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace, target: nil, action: nil)
        scanButtonItem = UIBarButtonItem(title: "Scan for peripherals", style: UIBarButtonItemStyle.plain, target: self, action: #selector(BLEMainViewController.toggleScan(_:)))
        deviceListViewController.toolbarItems = [space, scanButtonItem!, space]
        
    }
    
    
    func toggleScan(_ sender:UIBarButtonItem?){
        
        // Stop scan
        if connectionStatus == ConnectionStatus.scanning {
            stopScan()
        }
            
            // Start scan
        else {
            startScan()
        }
        
    }
    
    
    func stopScan(){
        
        if (connectionMode == ConnectionMode.none) {
            cm?.stopScan()
            scanIndicator?.stopAnimating()
            
            //If scan indicator is in toolbar items, remove it
            let count:Int = deviceListViewController.toolbarItems!.count
//            var index = -1
            for i in 0...(count-1) {
                if deviceListViewController.toolbarItems?[i] === scanIndicatorItem {
                    deviceListViewController.toolbarItems?.remove(at: i)
                    break
                }
            }
            
            connectionStatus = ConnectionStatus.idle
            scanButtonItem?.title = "Scan for peripherals"
        }
        
        
        //        else if (connectionMode == ConnectionMode.UART) {
        //
        //        }
        
    }
    
    
    func startScan() {
        //Check if Bluetooth is enabled
        if cm?.state == CBManagerState.poweredOff {
            onBluetoothDisabled()
            return
        }
        
        cm!.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        //Check if scan indicator is in toolbar items
        var indicatorShown = false
        for i in deviceListViewController.toolbarItems! {
            if i === scanIndicatorItem {
                indicatorShown = true
            }
        }
        //Insert scan indicator if not already in toolbar items
        if indicatorShown == false {
            deviceListViewController.toolbarItems?.insert(scanIndicatorItem!, at: 1)
        }
        
        scanIndicator?.startAnimating()
        connectionStatus = ConnectionStatus.scanning
        scanButtonItem?.title = "Scanning"
    }
    
    
    func onBluetoothDisabled(){
        
        //Show alert to enable bluetooth
        let alert = UIAlertController(title: "Bluetooth disabled", message: "Enable Bluetooth in system settings", preferredStyle: UIAlertControllerStyle.alert)
        let aaOK = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil)
        alert.addAction(aaOK)
        self.present(alert, animated: true, completion: nil)
    }
    
    
    func currentHelpViewController()->HelpViewController {
        
        //Determine which help view to show based on the current view shown
        
        var hvc:HelpViewController
        
        if navController.topViewController!.isKind(of: PinIOViewController.self){
            hvc = pinIoViewController.helpViewController
        }
            
        else if navController.topViewController!.isKind(of: UARTViewController.self){
            hvc = uartViewController.helpViewController
        }
        else if navController.topViewController!.isKind(of: DeviceListViewController.self){
            hvc = deviceListViewController.helpViewController
        }
        else if navController.topViewController!.isKind(of: DeviceInfoViewController.self){
            hvc = deviceInfoViewController.helpViewController
        }
        else if navController.topViewController!.isKind(of: ControllerViewController.self){
            hvc = controllerViewController.helpViewController
        }
            //Add DFU help
            
        else{
            hvc = helpViewController
        }
        
        return hvc
        
    }
    
    
    @IBAction func showInfo(_ sender:AnyObject) {
        
        // Show help info view on iPhone via flip transition, called via "i" button in navbar
        
        if (IS_IPHONE) {
            present(currentHelpViewController(), animated: true, completion: nil)
        }
            
            //iPad
        else if (IS_IPAD) {
            
            //close popover it is being shown
            //            if helpPopoverController != nil {
            //                if helpPopoverController!.popoverVisible {
            //                    helpPopoverController?.dismissPopoverAnimated(true)
            //                    helpPopoverController = nil
            //                }
            //
            //            }
            
            //show popover if it isn't shown
            //            else {
            helpPopoverController?.dismiss(animated: true)
            
            helpPopoverController = UIPopoverController(contentViewController: currentHelpViewController())
            helpPopoverController?.backgroundColor = UIColor.darkGray
            
            let rightBBI:UIBarButtonItem! = navController.navigationBar.items!.last!.rightBarButtonItem
            let aFrame:CGRect = rightBBI!.customView!.frame
            helpPopoverController?.present(from: aFrame,
                in: rightBBI.customView!.superview!,
                permittedArrowDirections: UIPopoverArrowDirection.any,
                animated: true)
            //            }
        }
    }
    
    
    func connectPeripheral(_ peripheral:CBPeripheral, mode:ConnectionMode) {
        
        //Check if Bluetooth is enabled
        if cm?.state == CBManagerState.poweredOff {
            onBluetoothDisabled()
            return
        }
        
        printLog(self, funcName: "connectPeripheral", logString: "")
        
        connectionTimer?.invalidate()
        
        if cm == nil {
            //            println(self.description)
            printLog(self, funcName: (#function), logString: "No central Manager found, unable to connect peripheral")
            return
        }
        
        stopScan()
        
        //Show connection activity alert view
        let alert = UIAlertController(title: "Connecting …", message: nil, preferredStyle: UIAlertControllerStyle.alert)
        //        let aaCancel = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler:{ (aa:UIAlertAction!) -> Void in
        //            self.currentAlertView = nil
        //            self.abortConnection()
        //        })
        //        alert.addAction(aaCancel)
        currentAlertView = alert
        self.present(alert, animated: true, completion: nil)
        
        //Cancel any current or pending connection to the peripheral
        if peripheral.state == CBPeripheralState.connected || peripheral.state == CBPeripheralState.connecting {
            cm!.cancelPeripheralConnection(peripheral)
        }
        
        //Connect
        currentPeripheral = BLEPeripheral(peripheral: peripheral, delegate: self)
        cm!.connect(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: NSNumber(value: true as Bool)])
        
        connectionMode = mode
        connectionStatus = ConnectionStatus.connecting
        
        // Start connection timeout timer
        connectionTimer = Timer.scheduledTimer(timeInterval: connectionTimeOutIntvl, target: self, selector: #selector(BLEMainViewController.connectionTimedOut(_:)), userInfo: nil, repeats: false)
    }
    
    
    func connectPeripheralForDFU(_ peripheral:CBPeripheral) {
        
        //        connect device w services: dfuServiceUUID, deviceInfoServiceUUID
        
        printLog(self, funcName: (#function), logString: self.description)
        
        if cm == nil {
            //            println(self.description)
            printLog(self, funcName: (#function), logString: "No central Manager found, unable to connect peripheral")
            return
        }
        
        stopScan()
        
        dfuPeripheral = peripheral
        
        //Show connection activity alert view
        //        currentAlertView = UIAlertView(title: "Connecting …", message: nil, delegate: self, cancelButtonTitle: nil)
        //        currentAlertView!.show()
        
        //Cancel any current or pending connection to the peripheral
        if peripheral.state == CBPeripheralState.connected || peripheral.state == CBPeripheralState.connecting {
            cm!.cancelPeripheralConnection(peripheral)
        }
        
        //Connect
        //        currentPeripheral = BLEPeripheral(peripheral: peripheral, delegate: self)
        cm!.connect(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: NSNumber(value: true as Bool)])
        
        connectionMode = ConnectionMode.dfu
        connectionStatus = ConnectionStatus.connecting
        
        
    }
    
    
    func connectionTimedOut(_ timer:Timer) {
        
        if connectionStatus != ConnectionStatus.connecting {
            return
        }
        
        //dismiss "Connecting" alert view
        if currentAlertView != nil {
            currentAlertView?.dismiss(animated: true, completion: nil)
            currentAlertView = nil
        }
        
        //Cancel current connection
        abortConnection()
        
        //Notify user that connection timed out
        let alert = UIAlertController(title: "Connection timed out", message: "No response from peripheral", preferredStyle: UIAlertControllerStyle.alert)
        let aaOk = UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel) { (aa:UIAlertAction!) -> Void in }
        alert.addAction(aaOk)
        self.present(alert, animated: true) { () -> Void in }
        
    }
    
    
    func abortConnection() {
        
        connectionTimer?.invalidate()
        
        if (cm != nil) && (currentPeripheral != nil) {
            cm!.cancelPeripheralConnection(currentPeripheral!.currentPeripheral)
        }
        
        currentPeripheral = nil
        
        connectionMode = ConnectionMode.none
        connectionStatus = ConnectionStatus.idle
    }
    
    
    func disconnect() {
        
        printLog(self, funcName: (#function), logString: "")
        
        if connectionMode == ConnectionMode.dfu && dfuPeripheral != nil{
            cm!.cancelPeripheralConnection(dfuPeripheral!)
            dfuPeripheral = nil
            return
        }
        
        if cm == nil {
            printLog(self, funcName: (#function), logString: "No central Manager found, unable to disconnect peripheral")
            return
        }
            
        else if currentPeripheral == nil {
            printLog(self, funcName: (#function), logString: "No current peripheral found, unable to disconnect peripheral")
            return
        }
        
        //Cancel any current or pending connection to the peripheral
        let peripheral = currentPeripheral!.currentPeripheral
        if peripheral?.state == CBPeripheralState.connected || peripheral?.state == CBPeripheralState.connecting {
            cm!.cancelPeripheralConnection(peripheral!)
        }
        
    }
    
    
    func alertDismissedOnError() {
        
        //        if buttonIndex == 77 {
        //            currentAlertView = nil
        //        }
        
        if (connectionStatus == ConnectionStatus.connected) {
            disconnect()
        }
        else if (connectionStatus == ConnectionStatus.scanning){
            
            if cm == nil {
                printLog(self, funcName: "alertView clickedButtonAtIndex", logString: "No central Manager found, unable to stop scan")
                return
            }
            
            stopScan()
        }
        
        connectionStatus = ConnectionStatus.idle
        connectionMode = ConnectionMode.none
        
        currentAlertView = nil
        
        //alert dismisses automatically @ return
        
    }
    
    
    func pushViewController(_ vc:UIViewController) {
        
        //if currentAlertView != nil {
        if ((self.presentedViewController) != nil) {
            self.presentedViewController!.dismiss(animated: false, completion: { () -> Void in
                self.navController.pushViewController(vc, animated: true)
              //  self.currentAlertView = nil
            })
        }
        else {
            navController.pushViewController(vc, animated: true)
        }
        
        self.currentAlertView = nil
    }
    
    
    //MARK: Navigation Controller delegate methods
    
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        
        // Returning from a module, about to show device list ...
        if viewController === deviceListViewController {
            
            // Returning from Device Info
            if connectionMode == ConnectionMode.info {
                if connectionStatus == ConnectionStatus.connected {
                    disconnect()
                }
            }
                
                // Returning from UART
            else if connectionMode == ConnectionMode.uart {
                uartViewController?.inputTextView.resignFirstResponder()
                
                if connectionStatus == ConnectionStatus.connected {
                    disconnect()
                }
            }
                
                // Returning from Pin I/O
            else if connectionMode == ConnectionMode.pinIO {
                if connectionStatus == ConnectionStatus.connected {
                    pinIoViewController.systemReset()
                    disconnect()
                }
            }
                
                // Returning from Controller
            else if connectionMode == ConnectionMode.controller {
                controllerViewController?.stopSensorUpdates()
                
                if connectionStatus == ConnectionStatus.connected {
                    disconnect()
                }
            }
                
                // Returning from DFU
            else if connectionMode == ConnectionMode.dfu {
                //                if connectionStatus == ConnectionStatus.Connected {
                disconnect()
                //                }
                //return cbcentralmanager delegation to self
                cm?.delegate = self
                connectionMode = ConnectionMode.none
                dereferenceModeController()
            }
                
                // Starting in device list
                // Start scaning if bluetooth is enabled
            else if (connectionStatus == ConnectionStatus.idle) && (cm?.state != CBManagerState.poweredOff) {
                startScan()
            }
            
            //All modes hide toolbar except for device list
            navController.setToolbarHidden(false, animated: true)
        }
            //DFU mode doesn't maintain a connection, so back button sez "Back"!
        else if dfuViewController != nil && viewController == dfuViewController {
            deviceListViewController.navigationItem.backBarButtonItem?.title = "Back"
        }
            
            //All modes hide toolbar except for device list
        else {
            deviceListViewController.navigationItem.backBarButtonItem?.title = "Disconnect"
            navController.setToolbarHidden(true, animated: false)
        }
    }
    
    
    //MARK: CBCentralManagerDelegate methods
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        if (central.state == CBManagerState.poweredOn){
            
            //respond to powered on
        }
            
        else if (central.state == CBManagerState.poweredOff){
            
            //respond to powered off
        }
        
    }
    
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        if connectionMode == ConnectionMode.none {
            DispatchQueue.main.sync(execute: { () -> Void in
                if self.deviceListViewController == nil {
                    self.createDeviceListViewController()
                }
                self.deviceListViewController.didFindPeripheral(peripheral, advertisementData: advertisementData, RSSI:RSSI)
            })
            
            if navController.topViewController != deviceListViewController {
                DispatchQueue.main.sync(execute: { () -> Void in
                    self.pushViewController(self.deviceListViewController)
                })
            }
            
        }
    }
    
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        if (delegate != nil) {
            delegate!.onDeviceConnectionChange(peripheral)
        }
        
        //Connecting in DFU mode, discover specific services
        if connectionMode == ConnectionMode.dfu {
            peripheral.discoverServices([dfuServiceUUID(), deviceInformationServiceUUID()])
        }
        
        if currentPeripheral == nil {
            printLog(self, funcName: "didConnectPeripheral", logString: "No current peripheral found, unable to connect")
            return
        }
        
        
        if currentPeripheral!.currentPeripheral == peripheral {
            
            printLog(self, funcName: "didConnectPeripheral", logString: "\(peripheral.name)")
            
            //Discover Services for device
            if((peripheral.services) != nil){
                printLog(self, funcName: "didConnectPeripheral", logString: "Did connect to existing peripheral \(peripheral.name)")
                currentPeripheral!.peripheral(peripheral, didDiscoverServices: nil)  //already discovered services, DO NOT re-discover. Just pass along the peripheral.
            }
            else {
                currentPeripheral!.didConnect(connectionMode)
            }
            
        }
    }
    
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
        //respond to disconnection
        
        if (delegate != nil) {
            delegate!.onDeviceConnectionChange(peripheral)
        }
        
        if connectionMode == ConnectionMode.dfu {
            connectionStatus = ConnectionStatus.idle
            return
        }
        else if connectionMode == ConnectionMode.controller {
            controllerViewController.showNavbar()
        }
        
        printLog(self, funcName: "didDisconnectPeripheral", logString: "")
        
        if currentPeripheral == nil {
            printLog(self, funcName: "didDisconnectPeripheral", logString: "No current peripheral found, unable to disconnect")
            return
        }
        
        //if we were in the process of scanning/connecting, dismiss alert
        if (currentAlertView != nil) {
            uartDidEncounterError("Peripheral disconnected")
        }
        
        //if status was connected, then disconnect was unexpected by the user, show alert
        let topVC = navController.topViewController
        if  connectionStatus == ConnectionStatus.connected && isModuleController(topVC!) {
            
            printLog(self, funcName: "centralManager:didDisconnectPeripheral", logString: "unexpected disconnect while connected")
            
            //return to main view
            DispatchQueue.main.async(execute: { () -> Void in
                self.respondToUnexpectedDisconnect()
            })
        }
            
            // Disconnected while connecting
        else if connectionStatus == ConnectionStatus.connecting {
            
            abortConnection()
            
            printLog(self, funcName: "centralManager:didDisconnectPeripheral", logString: "unexpected disconnect while connecting")
            
            //return to main view
            DispatchQueue.main.async(execute: { () -> Void in
                self.respondToUnexpectedDisconnect()
            })
            
        }
        
        connectionStatus = ConnectionStatus.idle
        connectionMode = ConnectionMode.none
        currentPeripheral = nil
        
        // Dereference mode controllers
        dereferenceModeController()
        
    }
    
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        
        if (delegate != nil) {
            delegate!.onDeviceConnectionChange(peripheral)
        }
        
    }
    
    
    func respondToUnexpectedDisconnect() {
        
        self.navController.popToRootViewController(animated: true)
        
        //display disconnect alert
        let alert = UIAlertView(title:"Disconnected",
            message:"BlE device disconnected",
            delegate:self,
            cancelButtonTitle:"OK")
        
        let note = UILocalNotification()
        note.fireDate = Date().addingTimeInterval(0.0)
        note.alertBody = "BLE device disconnected"
        note.soundName =  UILocalNotificationDefaultSoundName
        UIApplication.shared.scheduleLocalNotification(note)
        
        alert.show()
        
        
    }


    func dereferenceModeController() {
        
        pinIoViewController = nil
        uartViewController = nil
        deviceInfoViewController = nil
        controllerViewController = nil
        dfuViewController = nil
    }
    
    
    func isModuleController(_ anObject:AnyObject)->Bool{
        
        var verdict = false
        if     anObject.isMember(of: PinIOViewController.self)
            || anObject.isMember(of: UARTViewController.self)
            || anObject.isMember(of: DeviceInfoViewController.self)
            || anObject.isMember(of: ControllerViewController.self)
            || anObject.isMember(of: DFUViewController.self)
            || (anObject.title == "Control Pad")
            || (anObject.title == "Color Picker") {
                verdict = true
        }
        
        //all controllers are modules except BLEMainViewController - weak
        //        var verdict = true
        //        if anObject.isMemberOfClass(BLEMainViewController) {
        //            verdict = false
        //        }
        
        return verdict
        
    }
    
    
    //MARK: BLEPeripheralDelegate methods
    
    func connectionFinalized() {
        
        //Bail if we aren't in the process of connecting
        if connectionStatus != ConnectionStatus.connecting {
            printLog(self, funcName: "connectionFinalized", logString: "with incorrect state")
            return
        }
        
        if (currentPeripheral == nil) {
            printLog(self, funcName: "connectionFinalized", logString: "Unable to start info w nil currentPeripheral")
            return
        }
        
        //stop time out timer
        connectionTimer?.invalidate()
        
        connectionStatus = ConnectionStatus.connected
        
        // Check if automatic update should be presented to the user
        if (firmwareUpdater != nil && connectionMode != .dfu) {
            // Wait till an updates are checked
             printLog(self, funcName: "connectionFinalized", logString: "Check if updates are available")
            firmwareUpdater!.checkUpdates(for: currentPeripheral!.currentPeripheral, delegate: self)
        }
        else {
            // Automatic updates not enabled. Just go to the mode selected by the user
            launchViewControllerForSelectedMode()
        }
    }
    

    func launchViewControllerForSelectedMode() {
        //Push appropriate viewcontroller onto the navcontroller
        var vc:UIViewController? = nil
        switch connectionMode {
        case ConnectionMode.pinIO:
            pinIoViewController = PinIOViewController(delegate: self)
            pinIoViewController.didConnect()
            vc = pinIoViewController
            break
        case ConnectionMode.uart:
            uartViewController = UARTViewController(aDelegate: self)
            uartViewController.didConnect()
            vc = uartViewController
            break
        case ConnectionMode.info:
            deviceInfoViewController = DeviceInfoViewController(cbPeripheral: currentPeripheral!.currentPeripheral, delegate: self)
            vc = deviceInfoViewController
            break
        case ConnectionMode.controller:
            controllerViewController = ControllerViewController(aDelegate: self)
            vc = controllerViewController
        case ConnectionMode.dfu:
            printLog(self, funcName: (#function), logString: "DFU mode")
        default:
            printLog(self, funcName: (#function), logString: "No connection mode set")
            break
        }
        
        if (vc != nil) {
            vc?.navigationItem.rightBarButtonItem = infoBarButton
            DispatchQueue.main.async(execute: { () -> Void in
                self.pushViewController(vc!)
            })
        }
    }
    
    
    func launchDFU(_ peripheral:CBPeripheral){
        
        printLog(self, funcName: (#function), logString: self.description)
        
        connectionMode = ConnectionMode.dfu
        dfuViewController = DFUViewController()
        dfuViewController.peripheral = peripheral
        //        dfuViewController.navigationItem.rightBarButtonItem = infoBarButton
        
        DispatchQueue.main.async(execute: { () -> Void in
            self.pushViewController(self.dfuViewController!)
        })
        
    }
    
    
    func uartDidEncounterError(_ error: NSString) {
        
        //Dismiss "scanning …" alert view if shown
        if (currentAlertView != nil) {
            currentAlertView?.dismiss(animated: true, completion: { () -> Void in
                self.alertDismissedOnError()
            })
        }
        
        //Display error alert
        let alert = UIAlertController(title: "Error", message: error as String, preferredStyle: UIAlertControllerStyle.alert)
        let aaOK = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil)
        alert.addAction(aaOK)
        self.present(alert, animated: true, completion: nil)
    }
    
    
    func didReceiveData(_ newData: Data) {
        
        //Data incoming from UART peripheral, forward to current view controller
        
        printLog(self, funcName: "didReceiveData", logString: "\(newData.hexRepresentationWithSpaces(true))")
        
        if (connectionStatus == ConnectionStatus.connected ) {
            //UART
            if (connectionMode == ConnectionMode.uart) {
                //send data to UART Controller
                uartViewController.receiveData(newData)
            }
                
                //Pin I/O
            else if (connectionMode == ConnectionMode.pinIO) {
                //send data to PIN IO Controller
                pinIoViewController.receiveData(newData)
            }
        }
        else {
            printLog(self, funcName: "didReceiveData", logString: "Received data without connection")
        }
        
    }
    
    
    func peripheralDidDisconnect() {
        
        //respond to device disconnecting
        
        printLog(self, funcName: "peripheralDidDisconnect", logString: "")
        
        //if we were in the process of scanning/connecting, dismiss alert
        if (currentAlertView != nil) {
            uartDidEncounterError("Peripheral disconnected")
        }
        
        //if status was connected, then disconnect was unexpected by the user, show alert
        let topVC = navController.topViewController
        if  connectionStatus == ConnectionStatus.connected && isModuleController(topVC!) {
            
            printLog(self, funcName: "peripheralDidDisconnect", logString: "unexpected disconnect while connected")
            
            //return to main view
            DispatchQueue.main.async(execute: { () -> Void in
                self.respondToUnexpectedDisconnect()
            })
        }
        
        connectionStatus = ConnectionStatus.idle
        connectionMode = ConnectionMode.none
        currentPeripheral = nil
        
        // Dereference mode controllers
        dereferenceModeController()
        
    }
    
    
    func alertBluetoothPowerOff() {
        
        //Respond to system's bluetooth disabled
        
        let title = "Bluetooth Power"
        let message = "You must turn on Bluetooth in Settings in order to connect to a device"
        let alertView = UIAlertView(title: title, message: message, delegate: nil, cancelButtonTitle: "OK")
        alertView.show()
    }
    
    
    func alertFailedConnection() {
        
        //Respond to unsuccessful connection
        
        let title = "Unable to connect"
        let message = "Please check power & wiring,\nthen reset your Arduino"
        let alertView = UIAlertView(title: title, message: message, delegate: nil, cancelButtonTitle: "OK")
        alertView.show()
        
    }
    
    
    //MARK: UartViewControllerDelegate / PinIOViewControllerDelegate methods
    
    func sendData(_ newData: Data) {
        
        //Output data to UART peripheral
        
        let hexString = newData.hexRepresentationWithSpaces(true)
        
        printLog(self, funcName: "sendData", logString: "\(hexString)")
        
        
        if currentPeripheral == nil {
            printLog(self, funcName: "sendData", logString: "No current peripheral found, unable to send data")
            return
        }
        
        currentPeripheral!.writeRawData(newData)
        
    }
    
    
    //WatchKit requests
    
    func connectedInControllerMode()->Bool{
        
        if connectionStatus == ConnectionStatus.connected &&
            connectionMode == ConnectionMode.controller   &&
            controllerViewController != nil {
                return true
        }
        else {
            return false
        }
    }
    
    
    func disconnectviaWatch(){
        
//        NSLog("disconnectviaWatch")
        
        controllerViewController?.stopSensorUpdates()
        disconnect()
//        navController.popToRootViewControllerAnimated(true)
        
    }
    
    
    // MARK: - FirmwareUpdaterDelegate
    
    func onFirmwareUpdatesAvailable(_ isUpdateAvailable: Bool, latestRelease: FirmwareInfo!, deviceInfoData: DeviceInfoData!, allReleases: [AnyHashable: Any]!) {
        printLog(self, funcName: "onFirmwareUpdatesAvailable", logString: "\(isUpdateAvailable)")
        
        cm?.delegate = self
        
        if (isUpdateAvailable) {
            DispatchQueue.main.async(execute: { [unowned self] in
                
                // Dismiss current dialog
                self.currentAlertView = nil
                if (self.presentedViewController != nil) {
                    self.presentedViewController!.dismiss(animated: true, completion: { _ in
                        self.currentAlertView = nil
                        self.showUpdateAvailableForRelease(latestRelease)
                    })
                }
                else {
                    self.showUpdateAvailableForRelease(latestRelease)
                }
            })
        }
        else {
            launchViewControllerForSelectedMode()
        }
    }
    
    func dfuServiceNotFound() {
        printLog(self, funcName: "dfuServiceNotFound", logString: "")
        
        cm?.delegate = self
        launchViewControllerForSelectedMode()
    }
    
    func showUpdateAvailableForRelease(_ latestRelease: FirmwareInfo!) {
        let alert = UIAlertController(title:"Update available", message: "Software version \(latestRelease.version) is available", preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addAction(UIAlertAction(title: "Go to updates", style: UIAlertActionStyle.default, handler: { _ in
            self.launchDFU(self.currentPeripheral!.currentPeripheral)
        }))
        alert.addAction(UIAlertAction(title: "Ask later", style: UIAlertActionStyle.default, handler: { _ in
            self.launchViewControllerForSelectedMode()
        }))
        alert.addAction(UIAlertAction(title: "Ignore", style: UIAlertActionStyle.cancel, handler: { _ in
            UserDefaults.standard.set(latestRelease.version, forKey: "softwareUpdateIgnoredVersion")
            self.launchViewControllerForSelectedMode()
        }))
        self.present(alert, animated: true, completion: nil)
        //self.currentAlertView = alert


    }
    
}


