import Foundation
import CoreBluetooth

class BLEDevice {
    
    var peripheral: CBPeripheral!
    var isUART:Bool = false
//    var isDFU:Bool = false
    fileprivate var advertisementData: [AnyHashable: Any]
    var RSSI:NSNumber {
        didSet {
            self.deviceCell?.updateSignalImage(RSSI)
        }
    }
    fileprivate let nilString = "nil"
    var connectableBool:Bool {
        let num = advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber
        if num != nil {
            return num!.boolValue
        }
        else {
            return false
        }
    }
    var name:String = ""
    
    var deviceCell:DeviceCell? {
        didSet {
            deviceCell?.nameLabel.text = self.name
            deviceCell?.connectButton.isHidden = !(self.connectableBool)
            deviceCell?.updateSignalImage(RSSI)
        }
    }
    
    var localName:String {
        var nameString = advertisementData[CBAdvertisementDataLocalNameKey] as? NSString
            if nameString == nil {
                nameString = nilString as NSString
            }
        return nameString! as String
    }
    
    var manufacturerData:String {
        let newData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
            if newData == nil {
                return nilString
            }
            let dataString = newData?.hexRepresentation()
            
            return dataString!
    }
    
    var serviceData:String {
        let dict = advertisementData[CBAdvertisementDataServiceDataKey] as? NSDictionary
            if dict == nil {
                return nilString
            }
            else {
                return dict!.description
            }
    }
    
    var serviceUUIDs:[String] {
        let svcIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? NSArray
            if svcIDs == nil {
                return [nilString]
            }
        return self.stringsFromUUIDs(svcIDs!)
    }
    
    var overflowServiceUUIDs:[String] {
        let ovfIDs = advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? NSArray
            
            if ovfIDs == nil {
                return [nilString]
            }
        return self.stringsFromUUIDs(ovfIDs!)
    }
    
    var txPowerLevel:String {
        let txNum = advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber
            if txNum == nil {
                return nilString
            }
        return txNum!.stringValue
    }
    
    var isConnectable:String {
        let num = advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber
            if num == nil {
                return nilString
            }
            let verdict = num!.boolValue
        
        //Enable connect button according to connectable value
        if self.deviceCell?.connectButton != nil {
            deviceCell?.connectButton.isEnabled = verdict
        }
            
            return verdict.description
    }
    
    var solicitedServiceUUIDs:[String] {
        let ssIDs = advertisementData[CBAdvertisementDataSolicitedServiceUUIDsKey] as? NSArray
            
            if ssIDs == nil {
                return [nilString]
            }
            
            return self.stringsFromUUIDs(ssIDs!)
    }
    
    var RSSString:String {
        return RSSI.stringValue
    }
    
    var identifier:UUID? {
        if self.peripheral == nil {
            printLog(self, funcName: "identifier", logString: "attempting to retrieve peripheral ID before peripheral set")
            return nil
        }
        else {
            return self.peripheral.identifier
        }
    }
    
    var UUIDString:String {
        let str = self.identifier?.uuidString
        if str != nil {
            return str!
        }
        else {
            return nilString
        }
    }
    
    var advertisementArray:[[String]] = []
    

    init(peripheral:CBPeripheral!, advertisementData:[AnyHashable: Any]!, RSSI:NSNumber!) {
        
        self.peripheral = peripheral
        self.advertisementData = advertisementData
        self.RSSI = RSSI
        
        var array:[[String]] = []
        var entry:[String] = ["Local Name", self.localName]
        if entry[1] != nilString {
            array.append(entry)
        }
        
//        entry = ["UUID", UUIDString]
//        if entry[1] != nilString { array.append(entry) }
        
        entry = ["Manufacturer Data", manufacturerData]
        if entry[1] != nilString { array.append(entry) }
        entry = ["Service Data", serviceData]
        if entry[1] != nilString { array.append(entry) }
        var completServiceUUIDs:[String] = serviceUUIDs
        if overflowServiceUUIDs[0] != nilString { completServiceUUIDs += overflowServiceUUIDs }
        entry = ["Service UUIDs"] + completServiceUUIDs
        if entry[1] != nilString { array.append(entry) }
        entry = ["TX Power Level", txPowerLevel]
        if entry[1] != nilString { array.append(entry) }
        entry = ["Connectable", isConnectable]
        if entry[1] != nilString { array.append(entry) }
        entry = ["Solicited Service UUIDs"] + solicitedServiceUUIDs
        if entry[1] != nilString { array.append(entry) }
        
        advertisementArray = array
        
        var nameString = peripheral.name

        
        if nameString == nil || nameString == "" {
            nameString = "N/A"
        }
        self.name = nameString!
        
        //Check for UART & DFU services
        for id in completServiceUUIDs {
            if uartServiceUUID().equalsString(id, caseSensitive: false, omitDashes: true) {
                isUART = true
            }
        }
        
    }

    func stringsFromUUIDs(_ idArray:NSArray)->[String] {
        
        var idStringArray = [String](repeating: "", count: idArray.count)
        
        idArray.enumerateObjects({ (obj:Any!, idx:Int, stop:UnsafeMutablePointer<ObjCBool>) -> Void in
            let objUUID = obj as? CBUUID
            let idStr = objUUID!.uuidString
            idStringArray[idx] = idStr
        })
        
        return idStringArray
        
    }
    
    
    func printAdData(){
        
        if LOGGING {
            print("- - - -")
            for a in advertisementArray {
                print(a)
            }
            print("- - - -")
        }
        
    }
    
    
}
