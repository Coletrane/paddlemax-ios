import Foundation
import CoreBluetooth

class BLEPeripheral: NSObject, CBPeripheralDelegate {

    // Services
    let bluetoothService = BluetoothService.sharedInstance

    // Variables
    var currentPeripheral:CBPeripheral!
    var uartService:CBService?
    var rxCharacteristic:CBCharacteristic?
    var txCharacteristic:CBCharacteristic?
    var knownServices:[CBService] = []
    
    //MARK: Utility methods
    
    init(peripheral:CBPeripheral){
        
        super.init()
        
        currentPeripheral = peripheral
        currentPeripheral.delegate = self
    }
    
    
    func didConnect() {
        
        //Respond to peripheral connection
        
        //Already discovered services
        if currentPeripheral.services != nil{
            printLog(
                    self,
                    funcName: #function,
                    logString: "Skipping service discovery")

            peripheral(currentPeripheral, didDiscoverServices: nil)
            return
        }
        
        printLog(
                self,
                funcName: #function,
                logString: "Starting service discovery")
    }
    
    
    func writeString(_ string:NSString){
        
        //Send string to peripheral
        
        let stringPtr = UnsafePointer(string.utf8String!).withMemoryRebound(to: UInt8.self, capacity: 8) {
            return $0
        }
        let data = Data(bytes: stringPtr, count: string.length)
        writeRawData(data)
    }
    
    
    func writeRawData(_ data:Data) {
        
        //Send data to peripheral
        
        if (txCharacteristic == nil){
            printLog(self, funcName: "writeRawData", logString: "Unable to write data without txcharacteristic")
            return
        }
        
        var writeType:CBCharacteristicWriteType
        
        if (txCharacteristic!.properties.rawValue & CBCharacteristicProperties.writeWithoutResponse.rawValue) != 0 {
            
            writeType = CBCharacteristicWriteType.withoutResponse
            
        }
            
        else if ((txCharacteristic!.properties.rawValue & CBCharacteristicProperties.write.rawValue) != 0){
            
            writeType = CBCharacteristicWriteType.withResponse
        }
            
        else{
            printLog(self, funcName: "writeRawData", logString: "Unable to write data without characteristic write property")
            return
        }
        
        //TODO: Test packetization
        
        //send data in lengths of <= 20 bytes
        let dataLength = data.count
        let limit = 20
        
        //Below limit, send as-is
        if dataLength <= limit {
            currentPeripheral.writeValue(data, for: txCharacteristic!, type: writeType)
        }
            
            //Above limit, send in lengths <= 20 bytes
        else {
            
            var len = limit
            var loc = 0
            var idx = 0 //for debug
            
            while loc < dataLength {
                
                let rmdr = dataLength - loc
                if rmdr <= len {
                    len = rmdr
                }
                
                let range = NSMakeRange(loc, len)
                var newBytes = [UInt8](repeating: 0, count: len)
                (data as NSData).getBytes(&newBytes, range: range)
                let newData = Data(bytes: UnsafePointer<UInt8>(newBytes), count: len)
                //                    println("\(self.classForCoder.description()) writeRawData : packet_\(idx) : \(newData.hexRepresentationWithSpaces(true))")
                self.currentPeripheral.writeValue(newData, for: self.txCharacteristic!, type: writeType)
                
                loc += len
                idx += 1
            }
        }
        
    }
    
    
    //MARK: CBPeripheral Delegate methods
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        //Respond to finding a new service on peripheral
        
        if error != nil {
            
//            handleError("\(self.classForCoder.description()) didDiscoverServices : Error discovering services")
            printLog(self, funcName: "didDiscoverServices", logString: "\(error.debugDescription)")
            
            return
        }
        
        //        println("\(self.classForCoder.description()) didDiscoverServices")
        
        
        let services = peripheral.services as [CBService]!
        
        for s in services! {
            
            // Service characteristics already discovered
            if (s.characteristics != nil){
                self.peripheral(peripheral, didDiscoverCharacteristicsFor: s, error: nil)    // If characteristics have already been discovered, do not check again
            } else if UUIDsAreEqual(s.uuid, secondID: uartServiceUUID()){
                    uartService = s
                    peripheral.discoverCharacteristics([txCharacteristicUUID(), rxCharacteristicUUID()], for: uartService!)
            }
        }
        
        printLog(self, funcName: "didDiscoverServices", logString: "all top-level services discovered")
        
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        //Respond to finding a new characteristic on service
        
        if error != nil {
//            handleError("Error discovering characteristics")
            printLog(self, funcName: "didDiscoverCharacteristicsForService", logString: "\(error.debugDescription)")
            
            return
        }
        
        printLog(self, funcName: "didDiscoverCharacteristicsForService", logString: "\(service.description) with \(service.characteristics!.count) characteristics")
            
            for c in (service.characteristics as [CBCharacteristic]!) {
                
                switch c.uuid {
                case rxCharacteristicUUID():         //"6e400003-b5a3-f393-e0a9-e50e24dcca9e"
                    printLog(self, funcName: "didDiscoverCharacteristicsForService", logString: "\(service.description) : RX")
                    rxCharacteristic = c
                    currentPeripheral.setNotifyValue(true, for: rxCharacteristic!)
                    break
                case txCharacteristicUUID():         //"6e400002-b5a3-f393-e0a9-e50e24dcca9e"
                    printLog(self, funcName: "didDiscoverCharacteristicsForService", logString: "\(service.description) : TX")
                    txCharacteristic = c
                    break
                default:
//                    printLog(self, "didDiscoverCharacteristicsForService", "Found Characteristic: Unknown")
                    break
                }

            }
            
            if rxCharacteristic != nil && txCharacteristic != nil {
                DispatchQueue.main.async(execute: { () -> Void in
                    self.bluetoothService.connectionFinalized()
                })
            }

    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        
        if error != nil {
//            handleError("Error discovering descriptors \(error.debugDescription)")
            printLog(self, funcName: "didDiscoverDescriptorsForCharacteristic", logString: "\(error.debugDescription)")
//            return
        }
        
        else {
            if characteristic.descriptors?.count != 0 {
                for d in characteristic.descriptors! {
                    let desc = d as CBDescriptor!
                    printLog(self,
                            funcName: "didDiscoverDescriptorsForCharacteristic",
                            logString: "\(desc?.description ?? "N/A")")
                    
                    currentPeripheral.readValue(for: desc!)
                }
            }

        }
        
        
        //Check if all characteristics were discovered
        var allCharacteristics:[CBCharacteristic] = []
        for s in knownServices {
            for c in s.characteristics! {
                allCharacteristics.append(c as CBCharacteristic!)
            }
        }
        for idx in 0...(allCharacteristics.count-1) {
            if allCharacteristics[idx] === characteristic {
//                println("found characteristic index \(idx)")
                if (idx + 1) == allCharacteristics.count {
//                    println("found last characteristic")
                    bluetoothService.connectionFinalized()
                }
            }
        }

        
    }
    
    
//    func peripheral(peripheral: CBPeripheral!, didUpdateValueForDescriptor descriptor: CBDescriptor!, error: NSError!) {
//        
//        if error != nil {
////            handleError("Error reading descriptor value \(error.debugDescription)")
//            printLog(self, "didUpdateValueForDescriptor", "\(error.debugDescription)")
////            return
//        }
//        
//        else {
//            println("descriptor value = \(descriptor.value)")
//            println("descriptor description = \(descriptor.description)")
//        }
//        
//    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        //Respond to value change on peripheral
        
        if error != nil {
//            handleError("Error updating value for characteristic\(characteristic.description.utf8) \(error.description.utf8)")
            printLog(self, funcName: "didUpdateValueForCharacteristic", logString: "\(error.debugDescription)")
            return
        }
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
        
        //Respond to finding a new characteristic on service
        
        if error != nil {
            printLog(self, funcName: "didDiscoverIncludedServicesForService", logString: "\(error.debugDescription)")
            return
        }
        
        printLog(self,
                funcName: "didDiscoverIncludedServicesForService",
                logString: "service: \(service.description) has \(service.includedServices?.count ?? -1) included services")
        
        //        if service.characteristics.count == 0 {
        //            currentPeripheral.discoverIncludedServices(nil, forService: service)
        //        }
        
        for s in (service.includedServices as [CBService]!) {
            
            printLog(self, funcName: "didDiscoverIncludedServicesForService", logString: "\(s.description)")
        }
        
    }
    
    
    func handleError(_ errorString:String) {
        
        printLog(self, funcName: "Error", logString: "\(errorString)")
        
    }
    
    
}
