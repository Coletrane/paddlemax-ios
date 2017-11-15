import Foundation
import UIKit
import CoreBluetooth

protocol DeviceListViewControllerDelegate: HomeViewControllerDelegate {

}

class DeviceListViewController : UIViewController, UITableViewDelegate, UITableViewDataSource, BLEPeripheralDelegate, UINavigationControllerDelegate {

    var delegate: DeviceListViewControllerDelegate?

    var infoButton: UIButton!
    @IBOutlet var tableView: UITableView!
    //    @IBOutlet var helpViewController: HelpViewController!
    @IBOutlet var deviceCell: DeviceCell!
    @IBOutlet var attributeCell: AttributeCell!
    @IBOutlet var warningLabel: UILabel!

    var devices: [BLEDevice] = []

    fileprivate var tableIsLoading = false
    fileprivate var signalImages: [UIImage]!
    fileprivate var infoBarButton: UIBarButtonItem!
    fileprivate var scanIndicator: UIActivityIndicatorView!
    fileprivate var scanIndicatorItem: UIBarButtonItem!
    fileprivate var scanButtonItem: UIBarButtonItem!
    fileprivate var connectionTimeOutIntvl: TimeInterval! = 30.0
    var connectionTimer: Timer?

    fileprivate let CONNECTION_MODE = ConnectionMode.pinIO

    convenience init(aDelegate: DeviceListViewControllerDelegate) {
        self.init(nibName: "DeviceListViewController", bundle: Bundle.main)
        delegate = aDelegate

        title = "Connect to Paddle"
        warningLabel = UILabel()
        warningLabel.isHidden = true

        infoButton = UIButton()
        let archivedData = NSKeyedArchiver.archivedData(withRootObject: infoButton)
        let buttonCopy = NSKeyedUnarchiver.unarchiveObject(with: archivedData) as! UIButton
//        buttonCopy.addTarget(self, action: #selector(HomeViewController.showInfo(_:)), for: UIControlEvents.touchUpInside)
        infoBarButton = UIBarButtonItem(customView: buttonCopy)
        scanIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.white)
        self.navigationItem.rightBarButtonItem = infoBarButton
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Back", style: UIBarButtonItemStyle.plain, target: nil, action: nil)
        scanIndicator!.hidesWhenStopped = false
        scanIndicatorItem = UIBarButtonItem(customView: scanIndicator!)
        let space = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace, target: nil, action: nil)
        scanButtonItem = UIBarButtonItem(title: "Scan for peripherals", style: UIBarButtonItemStyle.plain, target: self, action: #selector(toggleScan(_:)))
        self.toolbarItems = [space, scanButtonItem!, space]
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        self.signalImages = [UIImage](arrayLiteral: UIImage(named: "signalStrength-0.png")!,
            UIImage(named: "signalStrength-1.png")!,
            UIImage(named: "signalStrength-2.png")!,
            UIImage(named: "signalStrength-3.png")!,
            UIImage(named: "signalStrength-4.png")!)

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

        warningLabel.isHidden = true
        if (delegate?.cm?.state == CBManagerState.poweredOff) {
            warningLabel.isHidden = false
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        tableView.isHidden = false
    }


    @objc func cellButtonTapped(_ sender: UIButton) {
        if tableIsLoading == true {
            printLog(self, funcName: "cellButtonTapped", logString: "ignoring tap during table load")
            return
        }

        //find relevant indexPaths
        let indexPath: IndexPath = indexPathForSubview(sender)
        var attributePathArray: [IndexPath] = []
        for i in 1...(devices[indexPath.section].advertisementArray.count) {
            attributePathArray.append(IndexPath(row: i, section: indexPath.section))
        }

        //if same button is tapped as previous, close the cell
        let senderCell = tableView.cellForRow(at: indexPath) as! DeviceCell

        animateCellSelection(tableView.cellForRow(at: indexPath)!)

        tableView.beginUpdates()
        if (senderCell.isOpen == true) {
            senderCell.isOpen = false
            tableView.deleteRows(at: attributePathArray, with: UITableViewRowAnimation.fade)
        } else {
            senderCell.isOpen = true
            tableView.insertRows(at: attributePathArray, with: UITableViewRowAnimation.fade)
        }
        tableView.endUpdates()

    }

    // MARK: event handlers

    @objc func connectButtonTapped(_ sender: UIButton) {
        let device = devices[sender.tag]
        print("CONNECT TAPPED \(device) \(device.isUART)")
        if (device.isUART) {
            self.connectInMode(CONNECTION_MODE, peripheral: device.peripheral)
        }
    }

    // MARK: view manipulation
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
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
        tableView.deleteSections(IndexSet(integersIn: NSMakeRange(0, tableView.numberOfSections).toRange()!), with: UITableViewRowAnimation.fade)
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
        tableView.deleteSections(IndexSet(integersIn: NSMakeRange(0, tableView.numberOfSections).toRange()!), with: UITableViewRowAnimation.fade)
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

            //Create Device Cell from NIB
            let cellData = NSKeyedArchiver.archivedData(withRootObject: deviceCell)
            let cell: DeviceCell = NSKeyedUnarchiver.unarchiveObject(with: cellData) as! DeviceCell

            //Assign properties via view tags set in IB
            cell.nameLabel = cell.viewWithTag(100) as! UILabel
            cell.rssiLabel = cell.viewWithTag(101) as! UILabel
            cell.connectButton = cell.viewWithTag(102) as! UIButton
            cell.connectButton.addTarget(self, action: #selector(self.connectButtonTapped(_:)), for: UIControlEvents.touchUpInside)
            cell.connectButton.layer.cornerRadius = 4.0
            cell.toggleButton = cell.viewWithTag(103) as! UIButton
            cell.toggleButton.addTarget(self, action: #selector(self.cellButtonTapped(_:)), for: UIControlEvents.touchUpInside)
            cell.signalImageView = cell.viewWithTag(104) as! UIImageView
            cell.uartCapableLabel = cell.viewWithTag(105) as! UILabel
            //set tag to indicate digital pin number
            cell.toggleButton.tag = indexPath.section   // Button tags are now device indexes, not view references
            cell.connectButton.tag = indexPath.section
            cell.signalImages = signalImages


            //Ensure cell is within device array range
            if indexPath.section <= (devices.count - 1) {
                devices[indexPath.section].deviceCell = cell
            }
            return cell
        }

        //Attribute Cell
        else {
            //Create Device Cell from NIB
            let cellData = NSKeyedArchiver.archivedData(withRootObject: attributeCell)
            let cell: AttributeCell = NSKeyedUnarchiver.unarchiveObject(with: cellData) as! AttributeCell

            //Assign properties via tags
            cell.label = cell.viewWithTag(100) as! UILabel
            cell.button = cell.viewWithTag(103) as! UIButton
            cell.button.addTarget(self, action: #selector(self.selectAttributeCell(_:)), for: UIControlEvents.touchUpInside)
            cell.dataStrings = devices[indexPath.section].advertisementArray[indexPath.row - 1]

            return cell
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


    @objc func selectAttributeCell(_ sender: UIButton) {

        let indexPath = indexPathForSubview(sender)

        let cell = tableView.cellForRow(at: indexPath) as! AttributeCell

        tableView.selectRow(at: indexPath, animated: true, scrollPosition: UITableViewScrollPosition.none)

        //Show full view of attribute data
        let ttl = cell.dataStrings[0]
        var msg = ""
        for s in cell.dataStrings { //compose message from attribute strings
            if s == "nil" || s == ttl {
                continue
            } else {
                msg += "\n"
                msg += s
            }
        }

        let style = UIAlertControllerStyle.alert
        let alertController = UIAlertController(title: ttl, message: msg, preferredStyle: style)


        // Cancel button
        let aaCancel = UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel) { (aa: UIAlertAction!) -> Void in
        }
        alertController.addAction(aaCancel)

        // Info button
//        let aaInfo = UIAlertAction(title: "Info", style: UIAlertActionStyle.Default) { (aa:UIAlertAction!) -> Void in
//            self.connectInMode(delegate?.connectionMode.Info, peripheral: device.peripheral)
//    }

        self.present(alertController, animated: true) { () -> Void in

        }

    }

    func stopScan() {

        if (delegate?.connectionMode == ConnectionMode.none) {
            delegate?.cm?.stopScan()
            scanIndicator?.stopAnimating()

            for i in 0...toolbarItems!.count - 1 {
                if toolbarItems?[i] === scanIndicatorItem {
                    toolbarItems?.remove(at: i)
                    break
                }
            }

            delegate?.connectionStatus = ConnectionStatus.idle
            scanButtonItem?.title = "Scan for peripherals"
        }

    }


    func startScan() {
        if delegate?.cm?.state == CBManagerState.poweredOff {
            onBluetoothDisabled()
            return
        }

        delegate?.cm?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        //Check if scan indicator is in toolbar items
        var indicatorShown = false
        for i in toolbarItems! {
            if i === scanIndicatorItem {
                indicatorShown = true
            }
        }
        //Insert scan indicator if not already in toolbar items
        if indicatorShown == false {
            toolbarItems?.insert(scanIndicatorItem!, at: 1)
        }

        scanIndicator?.startAnimating()
        delegate?.connectionStatus = ConnectionStatus.scanning
        scanButtonItem?.title = "Scanning"
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
        let alert = UIAlertController(title: "Connecting …", message: nil, preferredStyle: UIAlertControllerStyle.alert)
                let aaCancel = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler:{ (aa:UIAlertAction!) -> Void in
                    self.delegate?.alertView.dismiss(animated: true)
                    self.abortConnection()
                })
                alert.addAction(aaCancel)
        delegate?.alertView = alert
        self.present(alert, animated: true, completion: nil)

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

        //Show alert to enable bluetooth
        let alert = UIAlertController(title: "Bluetooth disabled", message: "Enable Bluetooth in system settings", preferredStyle: UIAlertControllerStyle.alert)
        let aaOK = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil)
        alert.addAction(aaOK)
        self.present(alert, animated: true, completion: nil)
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

        //Notify user that connection timed out
        let alert = UIAlertController(title: "Connection timed out", message: "No response from peripheral", preferredStyle: UIAlertControllerStyle.alert)
        let aaOk = UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel) { (aa:UIAlertAction!) -> Void in }
        alert.addAction(aaOk)
        self.present(alert, animated: true) { () -> Void in }

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

        //Display error alert
        let alert = UIAlertController(title: "Error", message: error as String, preferredStyle: UIAlertControllerStyle.alert)
        let aaOK = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil)
        alert.addAction(aaOK)
        self.present(alert, animated: true, completion: nil)
    }
}
