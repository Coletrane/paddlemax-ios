//
//  DeviceInfoViewController.swift
//  Adafruit Bluefruit LE Connect
//
//  Displays CBPeripheral Services & Characteristics in a UITableView
//
//  Created by Collin Cunningham on 10/24/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

import UIKit
import CoreBluetooth

class DeviceInfoViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, HelpViewControllerDelegate{
    
    @IBOutlet var tableView:UITableView!
    @IBOutlet var headerView:UIView!
    @IBOutlet var peripheralNameLabel:UILabel!
//    @IBOutlet var peripheralUUIDLabel:UILabel!
    @IBOutlet var helpViewController:HelpViewController!
    var delegate:HelpViewControllerDelegate?
//    @IBOutlet var serviceCell:UITableViewCell!
//    @IBOutlet var characteristicCell:UITableViewCell!
    let serviceCellIdentifier = "serviceCell"
    let characteristicCellIdentifier = "characteristicCell"
    let defaultServiceToggleState = true
    var peripheral:CBPeripheral!
    var gattDict:Dictionary<String,String>? //known UUID reference
    var serviceToggle:[Bool]!    //individual ref for service is open in table
    
    convenience init(cbPeripheral:CBPeripheral, delegate:HelpViewControllerDelegate){
        
        //Separate NIBs for iPhone 3.5", iPhone 4", & iPad
        
        var nibName:NSString
        
        if IS_IPHONE{
            nibName = "DeviceInfoViewController_iPhone"
        }
        else{   //IPAD
            nibName = "DeviceInfoViewController_iPad"
        }
        
        self.init(nibName: nibName as String, bundle: Bundle.main)
        
        self.peripheral = cbPeripheral
        self.delegate = delegate
        
        if let path = Bundle.main.path(forResource: "GATT-characteristics", ofType: "plist") {
            if let dict = NSDictionary(contentsOfFile: path) as? Dictionary<String, String> {
                self.gattDict = dict
            }
        }
        
        self.serviceToggle = [Bool](repeating: defaultServiceToggleState, count: peripheral.services!.count)
        
    }
    
    
    //FOR SCREENSHOTS
//    convenience init(delegate:HelpViewControllerDelegate){
//        
//        //Separate NIBs for iPhone 3.5", iPhone 4", & iPad
//        
//        var nibName:NSString
//        
//        if IS_IPHONE{
//            nibName = "DeviceInfoViewController_iPhone"
//        }
//        else{   //IPAD
//            nibName = "DeviceInfoViewController_iPad"
//        }
//        
//        self.init(nibName: nibName, bundle: NSBundle.mainBundle())
//        
//        self.peripheral = CBPeripheral()
//        
//        self.delegate = delegate
//    }
    
    
    override func viewDidLoad() {
        
        super.viewDidLoad()

        self.helpViewController.delegate = delegate
        self.title = peripheral.name
        
        let tvc = UITableViewController(style: UITableViewStyle.plain)
        tvc.tableView = tableView
        
        
        peripheralNameLabel.text = peripheral.name
//        peripheralUUIDLabel.text = "UUID: " + peripheral.identifier.UUIDString
        
        // … and add \(#function) to printLogs
    }

    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let service = peripheral.services![indexPath.section]
        var identifier = characteristicCellIdentifier
        let style = UITableViewCellStyle.subtitle
        var title = ""
        var detailTitle = ""
        var selectable = false
//        var bkgColor = UIColor.whiteColor()
        
        //Service row
        if indexPath.row == 0 {
            identifier = serviceCellIdentifier
//            style = UITableViewCellStyle.Default
            title = displayNameforUUID(service.uuid)
            detailTitle = "Service"
            selectable = true
        }
        
        //Characteristic row
        else {
            if let chstc = service.characteristics?[indexPath.row-1] as CBCharacteristic! {
                
                title = displayNameforUUID(chstc.uuid)
                if chstc.value != nil {
                    detailTitle = chstc.value!.stringRepresentation()
                    
                    //Debugging unknown chars
                    //                if detailTitle.rangeOfString("�") != nil {
                    //                    println("-------------> detailTitle == " + detailTitle + " contains unknown char, hex value == " + chstc.value.hexRepresentation() + " description == " + chstc.value.description)
                    //                }
                }
                else { detailTitle = "Characteristic" }
            }
        }
        
        var cell = tableView.dequeueReusableCell(withIdentifier: identifier) as UITableViewCell?
        if (cell == nil) {
            cell = UITableViewCell(style: style, reuseIdentifier: identifier)
        }
        
        //Set up cell
        cell?.textLabel?.adjustsFontSizeToFitWidth = true
        cell?.textLabel?.minimumScaleFactor = 0.5
        cell?.textLabel?.text = title
        cell?.detailTextLabel?.text = detailTitle
        cell?.selectionStyle = UITableViewCellSelectionStyle.none
        cell?.isUserInteractionEnabled = selectable
//        cell?.backgroundColor = bkgColor
        return cell!
    }
    
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        return peripheral.services!.count
        
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        
        if let service = peripheral.services?[section] {
            
            //service is open/being viewed
            if serviceToggle[section] == true {
                return service.characteristics!.count + 1
            }
            //service is closed
            else {
                return 1
            }
            
        }
        
        else {
            return 0
        }
        
    }
    
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        return 0.5
    
    }
    
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        
        return 0.5
        
    }
    
    
    func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int {
        
        if indexPath.row == 0 {
            return 0
        }
        else {
            return 2
        }
    }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let section = indexPath.section
        
        if let charCount = peripheral.services?[section].characteristics?.count {
            
            var attributePathArray:[IndexPath] = []
            for i in 1...(charCount) {
                attributePathArray.append(IndexPath(row: i, section: indexPath.section))
            }
            
            //make cell background blue
//            tableView.cellForRowAtIndexPath(indexPath)?.backgroundColor = cellSelectionColor
//            let cell = tableView.cellForRowAtIndexPath(indexPath)!
//            UIView.animateWithDuration(0.25, animations: { () -> Void in
//                cell.backgroundColor = UIColor.whiteColor()
//            })
            animateCellSelection(tableView.cellForRow(at: indexPath)!)
            
            tableView.beginUpdates()
            if (serviceToggle[section] == true) {
                serviceToggle[section] = false
                tableView.deleteRows(at: attributePathArray, with: UITableViewRowAnimation.fade)
            }
            else {
                serviceToggle[section] = true
                tableView.insertRows(at: attributePathArray, with: UITableViewRowAnimation.fade)
            }
            tableView.endUpdates()
            
        }
        
        
//        tableView.beginUpdates()
//        tableView.reloadSection(NSIndexSet(indexesInRange: NSMakeRange(section, section)), withRowAnimation: UITableViewRowAnimation.Fade)
//        serviceToggle[section] = !serviceToggle[section]
//        tableView.endUpdates()
    }
    
    
    func helpViewControllerDidFinish(_ controller : HelpViewController){
        
    }

    
    func displayNameforUUID(_ uuid:CBUUID)->String {
        
        let uuidString = uuid.uuidString
        
        //Find description for UUID
        if let name = gattDict?[uuidString] {
            return name
        }
        
        else {
            return uuidString
        }
    }

}
