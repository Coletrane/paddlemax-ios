//
//  DeviceListViewController.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 10/15/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth

protocol DeviceListViewControllerDelegate: HelpViewControllerDelegate, UIAlertViewDelegate {
    
    var connectionMode:ConnectionMode { get }
    var warningLabel:UILabel! { get }
    func connectPeripheral(_ peripheral:CBPeripheral, mode:ConnectionMode)
    func stopScan()
    func startScan()
}

class DeviceListViewController : UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var delegate:DeviceListViewControllerDelegate?
    @IBOutlet var tableView:UITableView!
    @IBOutlet var helpViewController:HelpViewController!
    @IBOutlet var deviceCell:DeviceCell!
    @IBOutlet var attributeCell:AttributeCell!
    var devices:[BLEDevice] = []
    fileprivate var tableIsLoading = false
    fileprivate var signalImages:[UIImage]!
    
    
    convenience init(aDelegate:DeviceListViewControllerDelegate){
        
        //Separate NIBs for iPhone 3.5", iPhone 4", & iPad
        
        var nibName:NSString
        
        if IS_IPHONE{
            nibName = "DeviceListViewController_iPhone"
        }
        else{   //IPAD
            nibName = "DeviceListViewController_iPad"
        }
        
        self.init(nibName: nibName as String, bundle: Bundle.main)
        
        self.delegate = aDelegate
        self.title = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        
        self.signalImages = [UIImage](arrayLiteral: UIImage(named: "signalStrength-0.png")!,
            UIImage(named: "signalStrength-1.png")!,
            UIImage(named: "signalStrength-2.png")!,
            UIImage(named: "signalStrength-3.png")!,
            UIImage(named: "signalStrength-4.png")!)
        
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.separatorStyle = UITableViewCellSeparatorStyle.none
        self.helpViewController.delegate = delegate
        
        //Add pull-to-refresh functionality
        let tvc = UITableViewController(style: UITableViewStyle.plain)
        tvc.tableView = tableView
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(DeviceListViewController.refreshWasPulled(_:)), for: UIControlEvents.valueChanged)
        tvc.refreshControl = refresh
        
    }
    
    
    @objc func cellButtonTapped(_ sender: UIButton) {
        
//        println("\(self.classForCoder.description()) cellButtonTapped: \(sender.tag)")
        
        if tableIsLoading == true {
            printLog(self, funcName: "cellButtonTapped", logString: "ignoring tap during table load")
            return
        }
        
        //find relevant indexPaths
        let indexPath:IndexPath = indexPathForSubview(sender)
        var attributePathArray:[IndexPath] = []
        for i in 1...(devices[indexPath.section].advertisementArray.count) {
            attributePathArray.append(IndexPath(row: i, section: indexPath.section))
        }
        
        //if same button is tapped as previous, close the cell
        let senderCell = tableView.cellForRow(at: indexPath) as! DeviceCell
        
        animateCellSelection(tableView.cellForRow(at: indexPath)!)
        
        tableView.beginUpdates()
        if (senderCell.isOpen == true) {
//            println("- - - -"); println("sections \(indexPath.section) has \(tableView.numberOfRowsInSection(indexPath.section)) rows"); println("deleting \(attributePathArray.count) rows"); println("- - - -")
            senderCell.isOpen = false
            tableView.deleteRows(at: attributePathArray, with: UITableViewRowAnimation.fade)
        }
        else {
            senderCell.isOpen = true
            tableView.insertRows(at: attributePathArray, with: UITableViewRowAnimation.fade)
        }
        tableView.endUpdates()
        
    }
    
    
    @objc func connectButtonTapped(_ sender: UIButton) {
        
        printLog(self, funcName: "connectButtonTapped", logString: "\(sender.tag)")
        
        if tableIsLoading == true {
            printLog(self, funcName: "connectButtonTapped", logString: "ignoring button while table loads")
        }
        
        let device = devices[sender.tag]
        
        /*
        // If device is not uart capable, go straight to Info mode
        if device.isUART == false {
            connectInMode(ConnectionMode.Info, peripheral: device.peripheral)
            return
        }
*/
        
        //Show connection options for UART capable devices
        var style = UIAlertControllerStyle.actionSheet
        if IS_IPAD {
            style = UIAlertControllerStyle.alert
        }
        let alertController = UIAlertController(title: "Connect to \(device.name)", message: "Choose mode:", preferredStyle: style)
        
        
        // Cancel button
        let aaCancel = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel) { (aa:UIAlertAction!) -> Void in }
        alertController.addAction(aaCancel)
        
        // Info button
        let aaInfo = UIAlertAction(title: "Info", style: UIAlertActionStyle.default) { (aa:UIAlertAction!) -> Void in
            self.connectInMode(ConnectionMode.info, peripheral: device.peripheral)
        }
        alertController.addAction(aaInfo)
        
        if (device.isUART) {
            //UART button
            let aaUART = UIAlertAction(title: "UART", style: UIAlertActionStyle.default) { (aa:UIAlertAction!) -> Void in
                self.connectInMode(ConnectionMode.uart, peripheral: device.peripheral)
            }
            alertController.addAction(aaUART)
            
            //Pin I/O button
            let aaPinIO = UIAlertAction(title: "Pin I/O", style: UIAlertActionStyle.default) { (aa:UIAlertAction!) -> Void in
                self.connectInMode(ConnectionMode.pinIO, peripheral: device.peripheral)
            }
            alertController.addAction(aaPinIO)
            
            //Controller Button
            let aaController = UIAlertAction(title: "Controller", style: UIAlertActionStyle.default) { (aa:UIAlertAction!) -> Void in
                self.connectInMode(ConnectionMode.controller, peripheral: device.peripheral)
            }
            alertController.addAction(aaController)
        }
        
        self.present(alertController, animated: true) { () -> Void in
        }
    
    }
    
    
    func connectInMode(_ mode:ConnectionMode, peripheral:CBPeripheral) {
        
//        println("\(self.classForCoder.description()) connectInMode")
        switch mode {
        case ConnectionMode.uart,
             ConnectionMode.pinIO,
             ConnectionMode.info,
             ConnectionMode.controller:
            delegate?.connectPeripheral(peripheral, mode: mode)
        default:
            break
        }
        
    }
    
    
    func didFindPeripheral(_ peripheral:CBPeripheral!, advertisementData:[AnyHashable: Any]!, RSSI:NSNumber!) {
        
//        println("\(self.classForCoder.description()) didFindPeripheral")
        
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
        let newDevice = BLEDevice(peripheral: peripheral, advertisementData: advertisementData as! [NSObject : AnyObject], RSSI: RSSI)
        newDevice.printAdData()
        devices.append(newDevice)
        
        //Reload tableview to show new device
        if tableView != nil {
            tableIsLoading = true
            tableView.reloadData()
            tableIsLoading = false
        }
        
        delegate?.warningLabel.text = ""
    }
    
    
    func didConnectPeripheral(_ peripheral:CBPeripheral!) {
        
        
        
    }
    
    
    @objc func refreshWasPulled(_ sender:UIRefreshControl) {
        
        delegate?.stopScan()
        
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
                self.delegate?.warningLabel.text = "No peripherals found"
                self.delegate?.startScan()
            })
        })
        
    }
    
    
    func clearDevices() {
        
        delegate?.stopScan()
        
        tableView.beginUpdates()
        tableView.deleteSections(IndexSet(integersIn: NSMakeRange(0, tableView.numberOfSections).toRange()!), with: UITableViewRowAnimation.fade)
        devices.removeAll(keepingCapacity: false)
        tableView.endUpdates()
        
        tableIsLoading = true
        tableView.reloadData()
        tableIsLoading = false
        delegate?.startScan()
        
        delegate?.warningLabel.text = "No peripherals found"
        
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
            let cell:DeviceCell = NSKeyedUnarchiver.unarchiveObject(with: cellData) as! DeviceCell
            
            //Assign properties via view tags set in IB
            cell.nameLabel = cell.viewWithTag(100) as! UILabel
            cell.rssiLabel = cell.viewWithTag(101) as! UILabel
            cell.connectButton = cell.viewWithTag(102) as! UIButton
            cell.connectButton.addTarget(self, action: #selector(DeviceListViewController.connectButtonTapped(_:)), for: UIControlEvents.touchUpInside)
            cell.connectButton.layer.cornerRadius = 4.0
            cell.toggleButton = cell.viewWithTag(103) as! UIButton
            cell.toggleButton.addTarget(self, action: #selector(DeviceListViewController.cellButtonTapped(_:)), for: UIControlEvents.touchUpInside)
            cell.signalImageView = cell.viewWithTag(104) as! UIImageView
            cell.uartCapableLabel = cell.viewWithTag(105) as! UILabel
            //set tag to indicate digital pin number
            cell.toggleButton.tag = indexPath.section   // Button tags are now device indexes, not view references
            cell.connectButton.tag = indexPath.section
            cell.signalImages = signalImages
            
            
            //Ensure cell is within device array range
            if indexPath.section <= (devices.count-1) {
                devices[indexPath.section].deviceCell = cell
            }
            return cell
        }
        
        //Attribute Cell
        else {
            //Create Device Cell from NIB
            let cellData = NSKeyedArchiver.archivedData(withRootObject: attributeCell)
            let cell:AttributeCell = NSKeyedUnarchiver.unarchiveObject(with: cellData) as! AttributeCell
            
            //Assign properties via tags
            cell.label = cell.viewWithTag(100) as! UILabel
            cell.button = cell.viewWithTag(103) as! UIButton
            cell.button.addTarget(self, action: #selector(DeviceListViewController.selectAttributeCell(_:)), for: UIControlEvents.touchUpInside)
            cell.dataStrings = devices[indexPath.section].advertisementArray[indexPath.row - 1]
            
            return cell
        }
        
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        let device:BLEDevice? = devices[section]
        let cell = device?.deviceCell
        
        if (cell == nil) || (cell?.isOpen == false) {  //When table is first loaded
            return 1
        }
        
        else {
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
        }
        else {
            return 24.0
        }
    }
    
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        if section == 0 {
            return 46.0
        }
        else {
            return 0.5
        }
    }
    
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        
        if section == (devices.count-1) {
            return 22.0
        }
        else {
            return 0.5
        }
    }
    
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        if (section == 0){
            return "Peripherals"
        }
            
        else{
            return nil
        }
    }
    
    
    //MARK: Helper functions
    
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
                indexPath = tableView.indexPath(for: theCell)
            }
            else {
                aView = theView.superview
            }
            counter += 1;
        }
        
        return indexPath!
        
    }
    
    
    @objc func selectAttributeCell(_ sender: UIButton){
        
        let indexPath = indexPathForSubview(sender)
        
        let cell = tableView.cellForRow(at: indexPath) as! AttributeCell
        
        tableView.selectRow(at: indexPath, animated: true, scrollPosition: UITableViewScrollPosition.none)
        
        //Show full view of attribute data
        let ttl = cell.dataStrings[0]
        var msg = ""
        for s in cell.dataStrings { //compose message from attribute strings
            if s == "nil" || s == ttl {
                continue
            }
            else {
                msg += "\n"
                msg += s
            }
        }
        
//        var style = UIAlertControllerStyle.ActionSheet
//        if IS_IPAD {
            let style = UIAlertControllerStyle.alert
//        }
        let alertController = UIAlertController(title: ttl, message: msg, preferredStyle: style)
        
        
        // Cancel button
        let aaCancel = UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel) { (aa:UIAlertAction!) -> Void in }
        alertController.addAction(aaCancel)
        
        // Info button
//        let aaInfo = UIAlertAction(title: "Info", style: UIAlertActionStyle.Default) { (aa:UIAlertAction!) -> Void in
//            self.connectInMode(ConnectionMode.Info, peripheral: device.peripheral)
//    }
        
        self.present(alertController, animated: true) { () -> Void in
            
        }
    
    }
    
    
}
