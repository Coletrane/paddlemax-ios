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
BLEPeripheralDelegate, UARTViewControllerDelegate, PinIOViewControllerDelegate, DeviceListViewControllerDelegate, HomeViewControllerDelegate {

    
    
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
    var homeViewController: HomeViewController!
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
    
    static let sharedInstance = BLEMainViewController()
    
    
    func centralManager()->CBCentralManager{
        
        return cm!;
        
    }
    
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {

        super.init(nibName: "BLEMainViewController", bundle: Bundle.main)

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

        if (cm == nil) {
            cm = CBCentralManager(delegate: self, queue: cbcmQueue)

            connectionMode = ConnectionMode.none
            connectionStatus = ConnectionStatus.idle
            currentAlertView = nil
        }

        homeViewController =  HomeViewController(aDelegate: self)
        refreshHomeViewLabels()

        navController = UINavigationController(rootViewController: homeViewController)
        navController.delegate = self
        navController.navigationBar.barStyle = UIBarStyle.black
        navController.navigationBar.isTranslucent = false
//        navController.toolbar.barStyle = UIBarStyle.black
//        navController.toolbar.isTranslucent = false
        navController.isToolbarHidden = true
        navController.interactivePopGestureRecognizer?.isEnabled = false
        
        addChildViewController(navController)
        view.addSubview(navController.view)


        
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    func didBecomeActive() {
        refreshHomeViewLabels()
    }

    //MARK: UI etc
    
    func helpViewControllerDidFinish(_ controller: HelpViewController) {
            dismiss(animated: true, completion: nil)
    }

    func refreshHomeViewLabels() {

        if (cm?.state == CBManagerState.poweredOff) {
            setHomeViewBluetoothDisabled()
        } else if (connectionStatus == ConnectionStatus.idle) {
            setHomeViewNotConnected()
        } else if (connectionStatus == ConnectionStatus.connected
                || connectionStatus == ConnectionStatus.connecting) {
            setHomeViewConnected()
        }
    }
    func setHomeViewBluetoothDisabled() {
        homeViewController.connectedLabel.text = "Bluetooth disabled"
    }

    func setHomeViewNotConnected() {
        homeViewController.connectedLabel.text = "You are not currently connected to your paddle"
        homeViewController.connectButton.isHidden = false
    }

    func setHomeViewConnected() {
        homeViewController.connectedLabel.text = "You are connected to your paddle!"
        homeViewController.connectButton.isHidden = true
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

        pushViewController(deviceListViewController)
    }
    
    
    @objc func toggleScan(_ sender:UIBarButtonItem?){
        
        if connectionStatus == ConnectionStatus.scanning {
            stopScan()
        }
        else {
            startScan()
        }
        
    }
    
    
    func stopScan(){
        
        if (connectionMode == ConnectionMode.none) {
            cm?.stopScan()
            scanIndicator?.stopAnimating()
            
//            let count:Int = deviceListViewController.toolbarItems!.count
//            for i in 0...(count-1) {
//                if deviceListViewController.toolbarItems?[i] === scanIndicatorItem {
//                    deviceListViewController.toolbarItems?.remove(at: i)
//                    break
//                }
//            }
            
            connectionStatus = ConnectionStatus.idle
            scanButtonItem?.title = "Scan for peripherals"
        }

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

        present(currentHelpViewController(), animated: true, completion: nil)
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
    
    
    @objc func connectionTimedOut(_ timer:Timer) {
        
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
                // Starting in device list
                // Start scaning if bluetooth is enabled
            else if (connectionStatus == ConnectionStatus.idle) && (cm?.state != CBManagerState.poweredOff) {
                startScan()
            }
            
            //All modes hide toolbar except for device list
            navController.setToolbarHidden(false, animated: true)
        }
            //All modes hide toolbar except for device list
        else {
//            deviceListViewController.navigationItem.backBarButtonItem?.title = "Disconnect"
//            navController.setToolbarHidden(true, animated: false)
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
    }
    
    
    func isModuleController(_ anObject:AnyObject)->Bool{
        
        var verdict = false
        if     anObject.isMember(of: PinIOViewController.self)
            || anObject.isMember(of: UARTViewController.self)
            || anObject.isMember(of: DeviceInfoViewController.self)
            || anObject.isMember(of: ControllerViewController.self)
            || (anObject.title == "Control Pad")
            || (anObject.title == "Color Picker") {
                verdict = true
        }
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

        self.launchPinIOViewController()
    }

    func launchPinIOViewController() {
        pinIoViewController = PinIOViewController(delegate: self)
        pinIoViewController.didConnect()
        pinIoViewController.navigationItem.rightBarButtonItem = infoBarButton
        let weakPiovc = pinIoViewController
        DispatchQueue.main.async(execute: { () -> Void in
            self.pushViewController(weakPiovc!)
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
        printLog(self, funcName: "didReceiveData", logString: "\(newData.hexRepresentationWithSpaces(true))")
        
        if (connectionStatus == ConnectionStatus.connected ) {
            pinIoViewController.receiveData(newData)
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
}


