import Foundation
import UIKit
import CoreBluetooth

enum TimePeriod: String {
    case oneWeek    = "This Week"
    case twoWeeks   = "Past 2 Weeks"
    case oneMonth   = "This Month"
    case threeMonth = "Past 3 Months"
    case sixMonth   = "Past 6 Months"
    case oneYear    = "This Year"

    static let array: Array<String> = [
        oneWeek.rawValue,
        twoWeeks.rawValue,
        oneMonth.rawValue,
        threeMonth.rawValue,
        sixMonth.rawValue,
        oneYear.rawValue
    ]
}

enum QuickStatValue: String {
    case distance   = "Distance"
    case power      = "Power"
    case time       = "Time"

    static let array: Array<String> = [
        distance.rawValue,
        power.rawValue,
        time.rawValue
    ]
}

protocol HomeViewControllerDelegate: AnyObject {
    var connectionMode: ConnectionMode? { get set }
    var connectionStatus: ConnectionStatus? { get set }
    var currentPeripheral: BLEPeripheral? { get set }
    var alertView: UIAlertController! { get set }
    var cm: CBCentralManager? { get set }
    func dismissDeviceList()
//    func onDeviceConnectionChange(_ peripheral:CBPeripheral)
}


class HomeViewController: UIViewController,
        DeviceListViewControllerDelegate,
        CBCentralManagerDelegate,
        PinIOViewControllerDelegate,
        UIPickerViewDelegate {

    static let singleton = HomeViewController()

    var cm: CBCentralManager?
    fileprivate let cbcmQueue = DispatchQueue(
            label: "com.paddlemax.paddlemaxios.cbcmqueue",
            attributes: DispatchQueue.Attributes.concurrent)

    // View controllers
    var deviceListViewController: DeviceListViewController!
    var pinIoViewController:PinIOViewController!

    var delegate: HomeViewControllerDelegate?

    // Enum values
    var connectionMode: ConnectionMode?
    var connectionStatus: ConnectionStatus?
    var currentPeripheral: BLEPeripheral?

    // Quick stat variables
    fileprivate var timePeriod: TimePeriod!
    fileprivate var timePeriodPickerValue: Int!
    fileprivate let timePeriodPickerItems = TimePeriod.array
    fileprivate var quickStatValue: QuickStatValue!
    fileprivate var quickStat: Double!
    fileprivate var quickStatPickerValue: Int!
    fileprivate let quickStatPickerItems = QuickStatValue.array

    // General outlets
    @IBOutlet var logo: UIImageView!
    @IBOutlet var logoLabel: UILabel!
    @IBOutlet var logoImage: UIImageView!

    // Connection related outlets
    @IBOutlet var connectedLabel: UILabel!
    @IBOutlet var connectButton: UIButton!

    // Quick stat related outlets
    @IBOutlet var setQuickStatButton: UIButton!
    @IBOutlet var confirmQuickStatButton: UIButton!
    @IBOutlet var quickStatLabel: UILabel!
    @IBOutlet var quickStatPicker: UIPickerView!
    @IBOutlet var timePeriodLabel: UILabel!
    @IBOutlet var timePeriodPicker: UIPickerView!


    var alertView: UIAlertController!

    // MARK: constructors
    convenience init() {
        self.init(
                nibName: "HomeViewController",
                bundle: Bundle.main)

        // TODO: check if device is already connected
        connectionMode = ConnectionMode.none
        connectionStatus = ConnectionStatus.idle

        connectedLabel = UILabel()
        connectButton = UIButton()
        quickStatLabel = UILabel()
        quickStatPicker = UIPickerView()
        timePeriodLabel = UILabel()
        timePeriodPicker = UIPickerView()
        setQuickStatButton = UIButton()
        confirmQuickStatButton = UIButton()
    }

    override init(nibName nib: String?, bundle nibBundle: Bundle?) {
        super.init(nibName: nib, bundle: nibBundle)
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }

    //for Objective-C delegate compatibility
    func setDelegate(_ newDelegate:AnyObject){

        if newDelegate.responds(to: Selector("onDeviceConnectionChange:")){
            delegate = newDelegate as? HomeViewControllerDelegate
        }
        else {
            printLog(self,
                    funcName: "setDelegate",
                    logString: "failed to set delegate")
        }

    }

    // MARK: view lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        if (cm == nil) {
            cm = CBCentralManager(delegate: self, queue: cbcmQueue)
        }

        connectButton.layer.cornerRadius = 8
        connectButton.layer.borderWidth = 1
        connectButton.layer.borderColor = BLUE.cgColor

        hideQuickStatSettings()
        // Set to one week and distance if user has no preferences set
        setQuickStatValues(timePeriod: TimePeriod.oneWeek, quickStat: 0.0)
        refreshConnectionStatusComponents()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        timePeriodPicker.reloadAllComponents()
        if let row = timePeriodPickerValue {
            timePeriodPicker.selectRow(row, inComponent: 0, animated: false)
        }

        quickStatPicker.reloadAllComponents()
        if let row = quickStatPickerValue {
            quickStatPicker.selectRow(row, inComponent: 0, animated: false)
        }

    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    func helpViewControllerDidFinish(_ controller: HelpViewController) {
        //TODO: implement help
    }

    // MARK: view controller navigation
    @IBAction func connectButtonPressed(_ sender: UIButton) {
        deviceListViewController = DeviceListViewController(aDelegate: self)
        present(deviceListViewController, animated: true, completion: { () -> Void in
            self.deviceListViewController.startScan()
        })
    }

    func dismissDeviceList() {
        deviceListViewController.dismiss(animated: true)
        refreshConnectionStatusComponents()
    }

    func alertDismissedOnError() {
        if (connectionStatus == ConnectionStatus.connected) {
            deviceListViewController.disconnect()
        }
        else if (connectionStatus == ConnectionStatus.scanning){

            if cm == nil {
                printLog(self,
                        funcName: "alertView clickedButtonAtIndex",
                        logString: "No central Manager found, unable to stop scan")
                return
            }

            deviceListViewController.stopScan()
        }

        connectionStatus = ConnectionStatus.idle
        connectionMode = ConnectionMode.none

        alertView = nil
    }

    // MARK: quick stat helpers
    func setQuickStatValues(timePeriod time: TimePeriod, quickStat stat: Double) {
        // Figure out if the user has already set a preference for quick stats
        if let userTimePeriod = UserDefaults.standard.string(forKey: QUICK_STAT_TIME) {
            timePeriod = TimePeriod(rawValue: userTimePeriod)
        } else {
            UserDefaults.standard.set(TimePeriod.oneWeek.rawValue, forKey: QUICK_STAT_TIME)
            timePeriod = TimePeriod.oneWeek
        }
        timePeriodPickerValue = timePeriodPickerItems.index(of: timePeriod.rawValue)
        timePeriodLabel.text = "\(timePeriod.rawValue):"

        // TODO: handle localiztion measurement systems
        if let userQuickStat = UserDefaults.standard.string(forKey: QUICK_STAT_SETTING) {
            quickStatValue = QuickStatValue(rawValue: userQuickStat)
        } else {
            UserDefaults.standard.set(QuickStatValue.distance.rawValue, forKey: QUICK_STAT_SETTING)
            quickStatValue = QuickStatValue.distance
        }
        quickStatPickerValue = quickStatPickerItems.index(of: quickStatValue.rawValue)
        quickStat = stat
        quickStatLabel.text = "\(quickStat!) mi"
    }

    // MARK: view manipulation
    func refreshConnectionStatusComponents() {

        if (cm?.state == CBManagerState.poweredOff) {
            bluetoothDisabledComponents()
        } else if (connectionStatus == ConnectionStatus.idle) {
            notConnectedComponents()
        } else if (connectionStatus == ConnectionStatus.connected
            || connectionStatus == ConnectionStatus.connecting) {
            connectedComponents()
        }
    }

    // MARK: event handlers
    @IBAction func setQuickStat(_ sender: UIButton) {
        printLog(self,
                funcName: #function,
                logString: "set quick stat button was pressed")

        showQuickStatSettings()
    }
    func showQuickStatSettings() {
        timePeriodLabel.isHidden = true
        timePeriodPicker.isHidden = false
        quickStatLabel.isHidden = true
        quickStatPicker.isHidden = false
        setQuickStatButton.isHidden = true
        confirmQuickStatButton.isHidden = false
    }


    @IBAction func confirmQuickStat(_ sender: UIButton) {
        printLog(self,
                funcName: #function,
                logString: "confirming quick stat settings " +
                        "timePeriod = \(timePeriod) " +
                        "quickStat = \(quickStatValue)")
    }
    func hideQuickStatSettings() {
        timePeriodLabel.isHidden = false
        timePeriodPicker.isHidden = true
        quickStatLabel.isHidden = false
        quickStatPicker.isHidden = true
        setQuickStatButton.isHidden = false
        confirmQuickStatButton.isHidden = true
    }
    func confirmQuickStatSettings() {

    }


    // helpers for component refresh
    func bluetoothDisabledComponents() {
        connectedLabel.text = "Bluetooth disabled"
    }

    func notConnectedComponents() {
        connectedLabel.text = "You are not currently connected to your paddle"
        connectButton.isHidden = false
        logoImage.isHidden = false
    }

    func connectedComponents() {
        connectedLabel.text = "You are connected to your paddle!"
        connectButton.isHidden = true
        logoImage.isHidden = true
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

    // UIPickerViewDelegate functions
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, _ component: Int) {
        if pickerView == timePeriodPicker {

        } else if pickerView == quickStatPicker {

        }
    }

    // MARK: bluetooth functions
    func onBluetoothDisabled(){

        //Show alert to enable bluetooth
        let alert = UIAlertController(title: "Bluetooth disabled", message: "Enable Bluetooth in system settings", preferredStyle: UIAlertControllerStyle.alert)
        let aaOK = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil)
        alert.addAction(aaOK)
        self.present(alert, animated: true, completion: nil)
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
                self.deviceListViewController.didFindPeripheral(peripheral, advertisementData: advertisementData, RSSI:RSSI)
            })
        }
//        deviceListViewController.warningLabel.text = "No paddles found!"
    }


    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {

        if (delegate != nil) {
//            delegate!.onDeviceConnectionChange(peripheral)
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
                currentPeripheral!.didConnect(connectionMode!)
            }

        }
    }


    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {


        if (delegate != nil) {
//            delegate!.onDeviceConnectionChange(peripheral)
        }

        if connectionMode == ConnectionMode.dfu {
            connectionStatus = ConnectionStatus.idle
            return
        }

        printLog(self, funcName: "didDisconnectPeripheral", logString: "")

        if currentPeripheral == nil {
            printLog(self, funcName: "didDisconnectPeripheral", logString: "No current peripheral found, unable to disconnect")
            return
        }

        //if we were in the process of scanning/connecting, dismiss alert
        if (alertView != nil) {
            deviceListViewController.uartDidEncounterError("Paddle disconnected")
        }

        //if status was connected, then disconnect was unexpected by the user, show alert
        //TODO: add record controller here
//        if  connectionStatus == ConnectionStatus.connected && topVC!) {
        if connectionStatus == ConnectionStatus.connected {
            printLog(self, funcName: "centralManager:didDisconnectPeripheral", logString: "unexpected disconnect while connected")

            //return to main view
            DispatchQueue.main.async(execute: { () -> Void in
                self.respondToUnexpectedDisconnect()
            })
        }

        // Disconnected while connecting
        else if connectionStatus == ConnectionStatus.connecting {

            deviceListViewController.abortConnection()

            printLog(self, funcName: "centralManager:didDisconnectPeripheral", logString: "unexpected disconnect while connecting")

            //return to main view
            DispatchQueue.main.async(execute: { () -> Void in
                self.respondToUnexpectedDisconnect()
            })

        }

        connectionStatus = ConnectionStatus.idle
        connectionMode = ConnectionMode.none
//        currentPeripheral = nil

//        recordViewController = nil
    }


    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {

        if (delegate != nil) {
//            delegate!.onDeviceConnectionChange(peripheral)
        }

    }


    func respondToUnexpectedDisconnect() {

//        self.self.navigationController?.popToRootViewController(animated: true)

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

    func launchPinIOViewController() {
        pinIoViewController = PinIOViewController(delegate: self)
        pinIoViewController.didConnect()
//        pinIoViewController.navigationItem.rightBarButtonItem = infoBarButton
//        self.navigationController?.pushViewController(pinIoViewController, animated: true)
    }

    func peripheralDidDisconnect() {

        //respond to device disconnecting

        printLog(self, funcName: "peripheralDidDisconnect", logString: "")

        //if we were in the process of scanning/connecting, dismiss alert
        if (alertView != nil) {
            deviceListViewController.uartDidEncounterError("Paddle disconnected")
        }

        //if status was connected, then disconnect was unexpected by the user, show alert
//        let topVC = self.navigationController?.topViewController
        //TODO: implement record controller
//        if  connectionStatus == ConnectionStatus.connected && isModuleController(topVC!) {
        if connectionStatus == ConnectionStatus.connected {
            printLog(self, funcName: "peripheralDidDisconnect", logString: "unexpected disconnect while connected")

            //return to main view
            DispatchQueue.main.async(execute: { () -> Void in
                self.respondToUnexpectedDisconnect()
            })
        }

        connectionStatus = ConnectionStatus.idle
        connectionMode = ConnectionMode.none
//        currentPeripheral = nil

        // Dereference mode controllers
//        dereferenceModeController()

    }

    //MARK: UartViewControllerDelegate / PinIOViewControllerDelegate methods

    func sendData(_ newData: Data) {

        //Output data to UART peripheral

        let hexString = newData.hexRepresentationWithSpaces(true)

        printLog(self, funcName: "sendData", logString: "\(hexString)")


        if currentPeripheral! == nil {
            printLog(self, funcName: "sendData", logString: "No current peripheral found, unable to send data")
            return
        }

        currentPeripheral!.writeRawData(newData)

    }


    //WatchKit requests

    func connectedInControllerMode()->Bool {

//        if connectionStatus == ConnectionStatus.connected &&
//               connectionMode == ConnectionMode.controller   &&
////               controllerViewController != nil {
//            return true
//        }
//        else {
//            return false
//        }
        return true
    }


    func disconnectviaWatch(){

//        NSLog("disconnectviaWatch")

//        controllerViewController?.stopSensorUpdates()
//        disconnect()
//        navController.popToRootViewControllerAnimated(true)

    }
}
