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
    var alertView: UIAlertController! { get set }
    func dismissDeviceList()
}

class HomeViewController: UIViewController,
        DeviceListViewControllerDelegate,
        UIPickerViewDelegate {

    // Services
    let bluetoothService = BluetoothService.sharedInstance

    // View controllers
    var deviceListViewController: DeviceListViewController!
    var pinIoViewController:PinIOViewController!

    var delegate: HomeViewControllerDelegate?

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

    // MARK: view lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

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

//    func helpViewControllerDidFinish(_ controller: HelpViewController) {
//        //TODO: implement help
//    }

    // MARK: view controller navigation
    @IBAction func connectButtonPressed(_ sender: UIButton) {
        deviceListViewController = DeviceListViewController(aDelegate: self)
        deviceListViewController.initTitleAndBars()
        present(deviceListViewController, animated: true, completion: { () -> Void in
            self.deviceListViewController.startScan()
        })
    }

    func dismissDeviceList() {
        deviceListViewController.dismiss(animated: true)
        refreshConnectionStatusComponents()
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

        if (bluetoothService.centralManager.state == CBManagerState.poweredOff) {
            bluetoothDisabledComponents()
        } else if (bluetoothService.connectionStatus == ConnectionStatus.idle) {
            notConnectedComponents()
        } else if (bluetoothService.connectionStatus == ConnectionStatus.connected
            || bluetoothService.connectionStatus == ConnectionStatus.connecting) {
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


    func launchPinIOViewController() {
//        pinIoViewController = PinIOViewController(delegate: self)
//        pinIoViewController.didConnect()
//        pinIoViewController.navigationItem.rightBarButtonItem = infoBarButton
//        self.navigationController?.pushViewController(pinIoViewController, animated: true)
    }

    func peripheralDidDisconnect() {

        printLog(
                self,
                funcName: #function,
                logString: "Disconnecting peripheral")


        //if status was connected, then disconnect was unexpected by the user, show alert
//        let topVC = self.navigationController?.topViewController
        //TODO: implement record controller
//        if  bluetoothService.connectionStatus == ConnectionStatus.connected && isModuleController(topVC!) {
    }

    //WatchKit requests

    func connectedInControllerMode()->Bool {

//        if bluetoothService.connectionStatus == ConnectionStatus.connected &&
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
