import Foundation
import UIKit
import CoreBluetooth

protocol DeviceListViewControllerDelegate: HomeViewControllerDelegate {

}

class DeviceListViewController : UIViewController, UITableViewDelegate, UITableViewDataSource, UINavigationControllerDelegate, DeviceCellDelegate {

    var delegate: DeviceListViewControllerDelegate?

    // Services
    let bluetoothService = BluetoothService.sharedInstance

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
    @IBOutlet var toolbar: UIToolbar!
    @IBOutlet var leftSpace: UIBarButtonItem!
    @IBOutlet var scanningItem: UIBarButtonItem!
    @IBOutlet var scanningIndicatorItem: UIBarButtonItem!
    @IBOutlet var rightSpace: UIBarButtonItem!
    
    // Alert Views
    fileprivate var connectingAlertView: UIAlertController!
    fileprivate var noBluetoothAlertView: UIAlertController!
    fileprivate var timedOutAlertView: UIAlertController!
    fileprivate var genericErrorAlertView: UIAlertController!

    // Variables
    fileprivate var tableIsLoading = false
    fileprivate var signalImages: [UIImage]!
    fileprivate var scanIndicator: UIActivityIndicatorView!
    fileprivate var refreshControl: UIRefreshControl!


    convenience init(aDelegate: DeviceListViewControllerDelegate) {
        self.init(nibName: "DeviceListViewController", bundle: Bundle.main)

        delegate = aDelegate
    }

    func initTitleAndBars() {
        title = "Connect to Paddle"
        warningLabel = UILabel()
        warningLabel.isHidden = true

        tableView = UITableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = UITableViewCellSeparatorStyle.none
        tableView.isHidden = true

        warningLabel.isHidden = true
        if (bluetoothService.centralManager.state == CBManagerState.poweredOff) {
            warningLabel.text = "Bluetooth is disabled, tap settings to turn it on"
            warningLabel.isHidden = false
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if (scanningIndicatorItem == nil) {
            initTitleAndBars()
        }

        // Make toolbar items
        leftSpace = UIBarButtonItem(
                barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace,
                target: nil,
                action: nil)
        scanningItem = UIBarButtonItem(
                title: "Scanning",
                style: UIBarButtonItemStyle.plain,
                target: self,
                action: nil)
        scanIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        scanIndicator.hidesWhenStopped = true
        scanningIndicatorItem = UIBarButtonItem(customView: scanIndicator!)
        rightSpace = UIBarButtonItem(
                barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace,
                target: nil,
                action: nil)

        toolbar.items = [
            leftSpace,
            scanningItem,
            scanningIndicatorItem,
            rightSpace
        ]

        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self,
                                 action: #selector(DeviceListViewController.handleRefresh(_:)),
                                 for: UIControlEvents.valueChanged)
        tableView.addSubview(refreshControl)

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
                        self.bluetoothService.abortConnection()
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
//        for i in 1...(bluetoothService.devices[indexPath.section].advertisementArray.count) {
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
        let device = bluetoothService.devices[sender.tag]
        printLog(
            self,
            funcName: #function,
            logString: "Connect button pressed, connecting to \(device.peripheral)")

        bluetoothService.connectPeripheral(device.peripheral)
    }
    
    @IBAction func cancelButtonPressed(_ sender: UIBarButtonItem) {
        printLog(self,
                funcName: #function,
                logString: "Cancel pressed, stopping scan and going back to the home screen")
        stopScan()
        self.dismiss(animated: true)
    }
    
    @IBAction func settingsButtonPressed(_ sender: UIBarButtonItem) {
        // TODO: fix this wtf apple why
        let settingsUrl = URL(string: "App-Prefs:root=Bluetooth")
        if UIApplication.shared.canOpenURL(settingsUrl!) {
            printLog(self,
                    funcName: #function,
                    logString: "Going to system settings")
            UIApplication.shared.open(settingsUrl!)
        }
    }
    
    @IBAction

    @objc func handleRefresh(_ sender: UIRefreshControl) {
        stopScan()

        if (tableView.numberOfSections > 0) {
            tableView.beginUpdates()
            tableView.deleteSections(IndexSet(integersIn: 0...tableView.numberOfSections - 1), with: UITableViewRowAnimation.fade)
            bluetoothService.removeAllDevices()
            tableView.endUpdates()
        }

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
    
    // MARK: view manipulation
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }

    func connectButtonTapped(_ sender: UIButton) {
        let peripheral = bluetoothService.devices[sender.tag].peripheral!
        bluetoothService.connectPeripheral(peripheral)
    }

    func setToolbarItemsScanning() {
        toolbar.items = [
            leftSpace,
            scanningItem,
            scanningIndicatorItem,
            rightSpace
        ]
    }

    func setToolbarItemsNotScanning() {
        toolbar.items = [
            leftSpace,
            scanningItem,
            rightSpace
        ]
    }

    // MARK: connection helpers

    func clearDevices() {

        self.stopScan()

        tableView.beginUpdates()
        tableView.deleteSections(IndexSet(integersIn: 0...tableView.numberOfSections), with: UITableViewRowAnimation.fade)
        bluetoothService.removeAllDevices()
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
            let testCell = bluetoothService.devices[indexPath.section].deviceCell
            if testCell != nil {
                return testCell!
            }

//            //Create Device Cell from NIB
//            let cellData = NSKeyedArchiver.archivedData(withRootObject: deviceCell)
//            let cell: DeviceCell = NSKeyedUnarchiver.unarchiveObject(with: cellData) as! DeviceCell
            let cell = DeviceCell(aDelegate: self)

//            cell.nameLabel = cell.viewWithTag(100) as! UILabel
//            cell.connectButton = cell.viewWithTag(102) as! UIButton
////            cell.connectButton.addTarget(self, action: #selector(self.connectButtonTapped(_:)), for: UIControlEvents.touchUpInside)
//            cell.connectButton.layer.cornerRadius = 4.0
//            cell.signalImageView = cell.viewWithTag(104) as! UIImageView
//            //set tag to indicate digital pin number
//            cell.connectButton.tag = indexPath.section
            cell.signalImages = signalImages


            //Ensure cell is within device array range
            if indexPath.section <= (bluetoothService.devices.count - 1) {
                bluetoothService.devices[indexPath.section].deviceCell = cell
            }

            return cell
        } else {
            return UITableViewCell()
        }
    }


    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        let device: BLEDevice? = bluetoothService.devices[section]
        let cell = device?.deviceCell

        if (cell == nil) || (cell?.isOpen == false) {  //When table is first loaded
            return 1
        } else {
            let rows = bluetoothService.devices[section].advertisementArray.count + 1
            return rows
        }

    }


    func numberOfSections(in tableView: UITableView) -> Int {

        //Each DeviceCell gets its own section
        return bluetoothService.devices.count
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

        if section == (bluetoothService.devices.count - 1) {
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


    func startScan() {
        guard bluetoothService.centralManager.state != CBManagerState.poweredOff else {
            setToolbarItemsNotScanning()
            return
        }
        scanIndicator.startAnimating()
        scanningItem.title = "Scanning"
        setToolbarItemsScanning()
        bluetoothService.tableViewCallback = { [weak self] () in
            self?.tableView.reloadData()
        }
        bluetoothService.startScan()
    }

    func stopScan() {
        scanIndicator?.stopAnimating()
        scanningItem?.title = "Scan"
        setToolbarItemsNotScanning()
    }

    func connectPeripheral() {
        //Show connection activity alert view
        self.present(connectingAlertView, animated: true, completion: nil)
    }

    func onBluetoothDisabled() {
        self.present(noBluetoothAlertView, animated: true, completion: nil)
    }

    func onConnectionTimedOut() {
        if delegate?.alertView != nil {
            delegate?.alertView.dismiss(animated: true, completion: nil)
        }

        self.present(timedOutAlertView, animated: true) { () -> Void in }

    }

    func connectionFinalized() {
        delegate?.alertView.dismiss(animated: true)
        delegate?.dismissDeviceList()
    }


    func alertDismissedOnError() {
        if (bluetoothService.connectionStatus == ConnectionStatus.connected) {
            bluetoothService.disconnect()
        } else if (bluetoothService.connectionStatus == ConnectionStatus.scanning) {
            stopScan()
        }
    }

}
