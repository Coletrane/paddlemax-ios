import Foundation
import UIKit
import CoreBluetooth

protocol DeviceListViewControllerDelegate: HomeViewControllerDelegate {

}

class DeviceListViewController : UIViewController, UITableViewDelegate, UITableViewDataSource, BLEPeripheralDelegate, UINavigationControllerDelegate, DeviceCellDelegate {

    var delegate: DeviceListViewControllerDelegate?

    // Navigation bar outlets
    @IBOutlet var navBar: UINavigationBar!
    @IBOutlet var barItem: UINavigationItem!
    @IBOutlet var cancelButton: UIBarButtonItem!
    @IBOutlet var settingsButton: UIBarButtonItem!

    // Outlets
    @IBOutlet var tableView: UITableView!
    //    @IBOutlet var helpViewController: HelpViewController!
    @IBOutlet var deviceCell: DeviceCell!
    @IBOutlet var warningLabel: UILabel!

    // Alert Views
    fileprivate var connectingAlertView: UIAlertController!
    fileprivate var noBluetoothAlertView: UIAlertController!
    fileprivate var timedOutAlertView: UIAlertController!
    fileprivate var genericErrorAlertView: UIAlertController!

    // Variables
    var devices: [BLEDevice] = []
    fileprivate var tableIsLoading = false
    fileprivate var signalImages: [UIImage]!
    fileprivate var infoBarButton: UIBarButtonItem!
    fileprivate var scanIndicator: UIActivityIndicatorView!
    fileprivate var scanIndicatorItem: UIBarButtonItem!
    fileprivate var scanningItem: UIBarButtonItem!
    fileprivate var connectionTimeOutIntvl: TimeInterval! = 30.0
    var connectionTimer: Timer?

    fileprivate let CONNECTION_MODE = ConnectionMode.pinIO

    convenience init(aDelegate: DeviceListViewControllerDelegate) {
        self.init(nibName: "DeviceListViewController", bundle: Bundle.main)

        delegate = aDelegate
    }


    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Connect to Paddle"
        warningLabel = UILabel()
        warningLabel.isHidden = true

        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = UITableViewCellSeparatorStyle.none
        tableView.isHidden = true

        //Add pull-to-refresh functionality
        let tvc = UITableViewController(style: UITableViewStyle.plain)
        tvc.tableView = tableView
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(self.refreshWasPulled(_:)), for: UIControlEvents.valueChanged)
        tvc.refreshControl = refresh

        // Add scanning indicator to toolbar
        scanIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.white)
        scanIndicator!.hidesWhenStopped = false
        scanIndicatorItem = UIBarButtonItem(customView: scanIndicator!)
        scanningItem = UIBarButtonItem(
                title: "Scanning",
                style: UIBarButtonItemStyle.plain,
                target: nil,
                action: nil)
        navigationController?.toolbarItems = [scanIndicatorItem, scanningItem]
        navigationController?.toolbar.isHidden = false

        warningLabel.isHidden = true
        if (delegate?.cm?.state == CBManagerState.poweredOff) {
            warningLabel.isHidden = false
        }

        connectingAlertView = UIAlertController(
                title: "Connecting …",
                message: nil,
                preferredStyle: UIAlertControllerStyle.alert)
        connectingAlertView.addAction(
            UIAlertAction(
                    title: "Cancel",
                    style: UIAlertActionStyle.cancel,
                    handler: { (aa: UIAlertAction!) -> Void in
                        self.delegate?.alertView.dismiss(animated: true)
                        self.abortConnection()
                    }))

        noBluetoothAlertView = UIAlertController(
                title: "Bluetooth disabled",
                message: "Enable Bluetooth in system settings",
                preferredStyle: UIAlertControllerStyle.alert)
        noBluetoothAlertView.addAction(
                UIAlertAction(
                        title: "OK",
                        style: UIAlertActionStyle.default,
                        handler: nil))

        timedOutAlertView = UIAlertController(
                title: "Connection timed out",
                message: "No response from peripheral",
                preferredStyle: UIAlertControllerStyle.alert)
        timedOutAlertView.addAction(
                UIAlertAction(
                        title: "OK",
                        style: UIAlertActionStyle.cancel,
                        handler: nil))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tableView.isHidden = false
    }


//    @objc func cellButtonTapped(_ sender: UIButton) {
//        if tableIsLoading == true {
//            printLog(self, funcName: "cellButtonTapped", logString: "ignoring tap during table load")
//            return
//        }
//
//        //find relevant indexPaths
//        let indexPath: IndexPath = indexPathForSubview(sender)
//        var attributePathArray: [IndexPath] = []
//        for i in 1...(devices[indexPath.section].advertisementArray.count) {
//            attributePathArray.append(IndexPath(row: i, section: indexPath.section))
//        }
//
//        //if same button is tapped as previous, close the cell
//        let senderCell = tableView.cellForRow(at: indexPath) as! DeviceCell
//
//        animateCellSelection(tableView.cellForRow(at: indexPath)!)
//
//        tableView.beginUpdates()
//        if (senderCell.isOpen == true) {
//            senderCell.isOpen = false
//            tableView.deleteRows(at: attributePathArray, with: UITableViewRowAnimation.fade)
//        } else {
//            senderCell.isOpen = true
//            tableView.insertRows(at: attributePathArray, with: UITableViewRowAnimation.fade)
//        }
//        tableView.endUpdates()
//
//    }

    // MARK: event handlers
    @IBAction func connectButtonPressed(_ sender: UIButton) {
        let device = devices[sender.tag]
        printLog(self,
                funcName: #function,
                logString: "Connect button pressed, connecting to \(device.peripheral)")

        if (device.isUART) {
            self.connectInMode(CONNECTION_MODE, peripheral: device.peripheral)
        }
    }
    
    @IBAction func cancelButtonPressed(_ sender: UIBarButtonItem) {
        printLog(self,
                funcName: #function,
                logString: "Cancel pressed, stopping scan and going back to the home screen")
        stopScan()
        self.dismiss(animated: true)
    }
    
    @IBAction func settingsButtonPressed(_ sender: UIBarButtonItem) {
        let settingsUrl = URL(string: UIApplicationOpenSettingsURLString)
        if settingsUrl != nil && UIApplication.shared.canOpenURL(settingsUrl!) {
            printLog(self,
                    funcName: #function,
                    logString: "Going to system settings")
            UIApplication.shared.open(settingsUrl!)
        }
    }
    
    // MARK: view manipulation
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }

    func connectButtonTapped(_ sender: UIButton) {
        let device = devices[sender.tag]
        print("CONNECT TAPPED \(device) \(device.isUART)")
        if (device.isUART) {
            self.connectInMode(CONNECTION_MODE, peripheral: device.peripheral)
        }
    }

    // MARK: connection helpers
    func connectInMode(_ mode: ConnectionMode, peripheral: CBPeripheral) {
        self.connectPeripheral(peripheral, mode: mode)
//        switch mode {
//        case delegate?.connectionMode.uart,
//             delegate?.connectionMode.pinIO,
//             delegate?.connectionMode.info,
//             delegate?.connectionMode.controller:
//            self.connectPeripheral(peripheral, mode: mode)
//        default:
//            break
//        }

    }

    func didFindPeripheral(_ peripheral: CBPeripheral!, advertisementData: [AnyHashable: Any]!, RSSI: NSNumber!) {

        //If device is already listed, just update RSSI
        let newID = peripheral.identifier
        for device in devices {
            if device.identifier == newID {
//                println("   \(self.classForCoder.description()) updating device RSSI")
                device.RSSI = RSSI
                return
            }
        }

        //Add reference to new device
        let newDevice = BLEDevice(peripheral: peripheral, advertisementData: advertisementData! as [NSObject: AnyObject], RSSI: RSSI)
        newDevice.printAdData()

        let alreadyInDevices = devices.filter {
            $0.name == newDevice.name
        }
        if newDevice.name == NAME && alreadyInDevices.isEmpty {
            devices.append(newDevice)
        }

        //Reload tableview to show new device
        if tableView != nil {
            tableIsLoading = true
            tableView.reloadData()
            tableIsLoading = false
        }
    }


    func didConnectPeripheral(_ peripheral: CBPeripheral!) {


    }


    @objc func refreshWasPulled(_ sender: UIRefreshControl) {

        self.stopScan()

        tableView.beginUpdates()
        tableView.deleteSections(IndexSet(integersIn: 0...tableView.numberOfSections), with: UITableViewRowAnimation.fade)
        devices.removeAll(keepingCapacity: false)
        tableView.endUpdates()

        delay(0.45, closure: { () -> () in
            sender.endRefreshing()

            delay(0.25, closure: { () -> () in
                self.tableIsLoading = true
                self.tableView.reloadData()
                self.tableIsLoading = false
                self.warningLabel.isHidden = false
                self.startScan()
            })
        })

    }


    func clearDevices() {

        self.stopScan()

        tableView.beginUpdates()
        tableView.deleteSections(IndexSet(integersIn: 0...tableView.numberOfSections), with: UITableViewRowAnimation.fade)
        devices.removeAll(keepingCapacity: false)
        tableView.endUpdates()

        tableIsLoading = true
        tableView.reloadData()
        tableIsLoading = false
        self.startScan()

        self.warningLabel.isHidden = false

    }


    //MARK: TableView functions

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        // Each device has its own section
        // row 0 is the device cell
        // additional rows are advertisement attributes

        //Device Cell
        if indexPath.row == 0 {
            //Check if cell already exists
            let testCell = devices[indexPath.section].deviceCell
            if testCell != nil {
                return testCell!
            }

//            //Create Device Cell from NIB
//            let cellData = NSKeyedArchiver.archivedData(withRootObject: deviceCell)
//            let cell: DeviceCell = NSKeyedUnarchiver.unarchiveObject(with: cellData) as! DeviceCell
            let cell = DeviceCell(aDelegate: self)

//            cell.nameLabel = cell.viewWithTag(100) as! UILabel
//            cell.connectButton = cell.viewWithTag(102) as! UIButton
//            cell.connectButton.addTarget(self, action: #selector(self.connectButtonTapped(_:)), for: UIControlEvents.touchUpInside)
//            cell.connectButton.layer.cornerRadius = 4.0
//            cell.signalImageView = cell.viewWithTag(104) as! UIImageView
//            //set tag to indicate digital pin number
//            cell.connectButton.tag = indexPath.section
//            cell.signalImages = signalImages


            //Ensure cell is within device array range
            if indexPath.section <= (devices.count - 1) {
                devices[indexPath.section].deviceCell = cell
            }

            return cell
        } else {
            return UITableViewCell()
        }
    }


    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        let device: BLEDevice? = devices[section]
        let cell = device?.deviceCell

        if (cell == nil) || (cell?.isOpen == false) {  //When table is first loaded
            return 1
        } else {
            let rows = devices[section].advertisementArray.count + 1
            return rows
        }

    }


    func numberOfSections(in tableView: UITableView) -> Int {

        //Each DeviceCell gets its own section
        return devices.count
    }


    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == 0 {
            return 50.0
        } else {
            return 24.0
        }
    }


    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {

        if section == 0 {
            return 46.0
        } else {
            return 0.5
        }
    }


    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {

        if section == (devices.count - 1) {
            return 22.0
        } else {
            return 0.5
        }
    }


    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {

        if (section == 0) {
            return "Peripherals"
        } else {
            return nil
        }
    }


    //MARK: Helper functions

    func indexPathForSubview(_ theView: UIView) -> IndexPath {

        //Find the indexpath for the cell which contains theView

        var indexPath: IndexPath?
        var counter = 0
        let limit = 20
        var aView: UIView? = theView

        while (indexPath == nil) {
            if (counter > limit) {
                break
            }
            if aView?.superview is UITableViewCell {
                let theCell = aView?.superview as! UITableViewCell
                indexPath = tableView.indexPath(for: theCell)
            } else {
                aView = theView.superview
            }
            counter += 1;
        }

        return indexPath!

    }


    func stopScan() {

        if (delegate?.connectionMode == ConnectionMode.none) {
            delegate?.cm?.stopScan()
            scanIndicator?.stopAnimating()

            navigationController?.toolbarItems = []

            delegate?.connectionStatus = ConnectionStatus.idle
            scanningItem?.title = "Scan for peripherals"
        }

    }


    func startScan() {
        if delegate?.cm?.state == CBManagerState.poweredOff {
            onBluetoothDisabled()
            return
        }

        delegate?.cm?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])

        navigationController?.toolbarItems = [scanIndicatorItem, scanningItem]
        scanIndicator?.startAnimating()

        delegate?.connectionStatus = ConnectionStatus.scanning
    }

    func connectPeripheral(_ peripheral: CBPeripheral, mode: ConnectionMode) {

        //Check if Bluetooth is enabled
        if delegate?.cm?.state == CBManagerState.poweredOff {
            onBluetoothDisabled()
            return
        }

        printLog(self, funcName: "connectPeripheral", logString: "")

        connectionTimer?.invalidate()

        stopScan()

        //Show connection activity alert view
        self.present(connectingAlertView, animated: true, completion: nil)

        //Cancel any current or pending connection to the peripheral
        if peripheral.state == CBPeripheralState.connected || peripheral.state == CBPeripheralState.connecting {
            delegate?.cm?.cancelPeripheralConnection(peripheral)
        }

        //Connect
        delegate?.currentPeripheral = BLEPeripheral(peripheral: peripheral, delegate: self)
        delegate?.cm?.connect(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: NSNumber(value: true as Bool)])

        delegate?.connectionMode = CONNECTION_MODE
        delegate?.connectionStatus = ConnectionStatus.connecting

        // Start connection timeout timer
        connectionTimer = Timer.scheduledTimer(timeInterval: connectionTimeOutIntvl, target: self, selector: #selector(self.connectionTimedOut(_:)), userInfo: nil, repeats: false)
    }

    func onBluetoothDisabled(){


        self.present(noBluetoothAlertView, animated: true, completion: nil)
    }

    @objc func toggleScan(_ sender:UIBarButtonItem?){

        if delegate?.connectionStatus == ConnectionStatus.scanning {
            stopScan()
        }
        else {
            startScan()
        }

    }

    @objc func connectionTimedOut(_ timer:Timer) {

        if delegate?.connectionStatus != ConnectionStatus.connecting {
            return
        }

        if delegate?.alertView != nil {
            delegate?.alertView.dismiss(animated: true, completion: nil)
        }

        abortConnection()

        self.present(timedOutAlertView, animated: true) { () -> Void in }
    }


    func abortConnection() {

        connectionTimer?.invalidate()

        if (delegate?.cm != nil) && (delegate?.currentPeripheral != nil) {
            delegate?.cm?.cancelPeripheralConnection((delegate?.currentPeripheral?.currentPeripheral!)!)
        }

        delegate?.connectionMode = ConnectionMode.none
        delegate?.connectionStatus = ConnectionStatus.idle
    }


    func disconnect() {

        printLog(self, funcName: (#function), logString: "")

        if delegate?.cm == nil {
            printLog(self, funcName: (#function), logString: "No central Manager found, unable to disconnect peripheral")
            return
        }

        else if delegate?.currentPeripheral == nil {
            printLog(self, funcName: (#function), logString: "No current peripheral found, unable to disconnect peripheral")
            return
        }

        //Cancel any current or pending connection to the peripheral
        let peripheralState = delegate?.currentPeripheral!.currentPeripheral.state
        if peripheralState == CBPeripheralState.connected || peripheralState == CBPeripheralState.connecting {
            delegate?.cm?.cancelPeripheralConnection((delegate?.currentPeripheral?.currentPeripheral!)!)
        }

    }


    func alertDismissedOnError() {
        if (delegate?.connectionStatus == ConnectionStatus.connected) {
            disconnect()
        }
        else if (delegate?.connectionStatus == ConnectionStatus.scanning){

            if delegate?.cm == nil {
                printLog(self, funcName: "alertView clickedButtonAtIndex", logString: "No central Manager found, unable to stop scan")
                return
            }

            stopScan()
        }

        delegate?.connectionStatus = ConnectionStatus.idle
        delegate?.connectionMode = ConnectionMode.none

        //alert dismisses automatically @ return
    }

    // MARK: BLEPeripheral delegate

    func didReceiveData(_ newData: Data) {
        printLog(self, funcName: "didReceiveData", logString: "\(newData.hexRepresentationWithSpaces(true))")

        if (delegate?.connectionStatus == ConnectionStatus.connected ) {
//            delegate?.pinIoViewController.receiveData(newData)
        }
        else {
            printLog(self, funcName: "didReceiveData", logString: "Received data without connection")
        }
    }

    func connectionFinalized() {

        //Bail if we aren't in the process of connecting
        if delegate?.connectionStatus != ConnectionStatus.connecting {
            printLog(self, funcName: "connectionFinalized", logString: "with incorrect state")
            return
        }

        if (delegate?.currentPeripheral == nil) {
            printLog(self, funcName: "connectionFinalized", logString: "Unable to start info w nil delegate?.currentPeripheral")
            return
        }

        connectionTimer?.invalidate()

        delegate?.connectionStatus = ConnectionStatus.connecting

        delegate?.alertView.dismiss(animated: true)
        delegate?.dismissDeviceList()
    }

    func uartDidEncounterError(_ error: NSString) {

        delegate?.alertView.dismiss(animated: true, completion: { () -> Void in
            self.alertDismissedOnError()
        })

        self.present(genericErrorAlertView, animated: true, completion: nil)
    }
}
