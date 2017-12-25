import Foundation
import CoreBluetooth

class BluetoothService: CBCentralManagerDelegate, BLEPeripheralDelegate {

    // Singleton
    static let sharedInstance = BluetoothService()

    // Services
    var centralManager: CBCentralManager
//    fileprivate let cbcmQueue = DispatchQueue(
//            label: "com.paddlemax.paddlemaxios.cbcmqueue",
//            attributes: DispatchQueue.Attributes.concurrent)

    // Variables
    var connectionStatus = ConnectionStatus.idle
    var devices: [BLEDevice] = []
    var currentPeripheral: BLEPeripheral?
    fileprivate var connectionTimeOutIntvl: TimeInterval! = 30.0
    var connectionTimer: Timer?

    required init() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: CBCentralManager delegate

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {

        if connectionStatus == ConnectionStatus.idle {
            DispatchQueue.main.sync(execute: { () -> Void in
                didFindPeripheral(peripheral, advertisementData: advertisementData, RSSI:RSSI)
            })
        }
    }


    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {

        if currentPeripheral == nil {
            printLog(self,
                    funcName: "didConnectPeripheral",
                    logString: "No current peripheral found, unable to connect")
            return
        }


        if currentPeripheral!.currentPeripheral == peripheral {

            printLog(self,
                    funcName: "didConnectPeripheral",
                    logString: "\(peripheral.name ?? "N/A")")

            //Discover Services for device
            if((peripheral.services) != nil){
                printLog(self,
                        funcName: "didConnectPeripheral",
                        logString: "Did connect to existing peripheral \(peripheral.name ?? "N/A")")
                //already discovered services, DO NOT re-discover. Just pass along the peripheral.
                currentPeripheral!.peripheral(peripheral, didDiscoverServices: nil)
            }
            else {
//                currentPeripheral!.didConnect(connectionMode!)
            }

        }
    }


    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {

        printLog(self,
                funcName: #function,
                logString: "")

        if currentPeripheral == nil {
            printLog(
                    self,
                    funcName: #function,
                    logString: "No current peripheral found, unable to disconnect")
            return
        }

        //if status was connected, then disconnect was unexpected by the user, show alert
        //TODO: add record controller here
//        if  connectionStatus == ConnectionStatus.connected && topVC!) {
        if connectionStatus == ConnectionStatus.connected {
            printLog(self,
                    funcName: #function,
                    logString: "unexpected disconnect while connected")
        }

        // Disconnected while connecting
        else if connectionStatus == ConnectionStatus.connecting {

            printLog(self,
                    funcName: #function,
                    logString: "unexpected disconnect while connecting")
        }

        connectionStatus = ConnectionStatus.idle
        currentPeripheral = nil
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
        let newDevice = BLEDevice(
                peripheral: peripheral,
                advertisementData: advertisementData! as [NSObject: AnyObject],
                RSSI: RSSI)
        newDevice.printAdData()

        let alreadyInDevices = devices.filter {
            $0.name == newDevice.name
        }
        if newDevice.name == NAME && alreadyInDevices.isEmpty {
            devices.append(newDevice)
        }
    }

    func startScan() {
        if centralManager.state != CBManagerState.poweredOff {

            centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])

            connectionStatus = ConnectionStatus.scanning
        }
    }

    func connectPeripheral(_ peripheral: CBPeripheral) {

        //Check if Bluetooth is enabled
        if centralManager.state != CBManagerState.poweredOff {

            printLog(self,
                    funcName: #function,
                    logString: "")

            connectionTimer?.invalidate()

            stopScan()


            //Cancel any current or pending connection to the peripheral
            if peripheral.state == CBPeripheralState.connected || peripheral.state == CBPeripheralState.connecting {
                centralManager.cancelPeripheralConnection(peripheral)
            }

            //Connect
            currentPeripheral = BLEPeripheral(peripheral: peripheral, delegate: self)
            centralManager.connect(
                    peripheral,
                    options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: NSNumber(value: true as Bool)])

            connectionStatus = ConnectionStatus.connecting

            // Start connection timeout timer
            connectionTimer = Timer.scheduledTimer(
                    timeInterval: connectionTimeOutIntvl,
                    target: self,
                    selector: #selector(self.connectionTimedOut(_:)),
                    userInfo: nil,
                    repeats: false)
        }
    }

    func stopScan() {
        centralManager.stopScan()
        connectionStatus = ConnectionStatus.idle

    }

    func toggleScan(){
        if connectionStatus == ConnectionStatus.scanning {
            stopScan()
        }
        else {
            startScan()
        }
    }

    @objc func connectionTimedOut(_ timer:Timer) {

        if connectionStatus != ConnectionStatus.connecting {
            return
        }

        abortConnection()
    }


    func abortConnection() {
        connectionTimer?.invalidate()

        if (currentPeripheral != nil) {
            centralManager.cancelPeripheralConnection((currentPeripheral?.currentPeripheral!)!)
        }

        connectionStatus = ConnectionStatus.idle
    }


    func disconnect() {

        printLog(
                self,
                funcName: #function,
                logString: "Disconnecting from peripheral.")

        if currentPeripheral == nil {
            printLog(
                    self,
                    funcName: #function,
                    logString: "No current peripheral found, unable to disconnect peripheral")
            return
        }

        //Cancel any current or pending connection to the peripheral
        let peripheralState = currentPeripheral!.currentPeripheral.state
        if  peripheralState == CBPeripheralState.connected || peripheralState == CBPeripheralState.connecting {
            centralManager.cancelPeripheralConnection((currentPeripheral?.currentPeripheral!)!)
        }
    }

    func didReceiveData(_ newData: Data) {
        printLog(
                self,
                funcName: #function,
                logString: "\(newData.hexRepresentationWithSpaces(true))")

        // TODO: trigger function in IO controller
//        if (connectionStatus == ConnectionStatus.connected ) {
////            delegate?.pinIoViewController.receiveData(newData)
//        }
    }

    func connectionFinalized() {

        //Bail if we aren't in the process of connecting
        if connectionStatus != ConnectionStatus.connecting {
            printLog(self, funcName: "connectionFinalized", logString: "with incorrect state")
            return
        }

        if (currentPeripheral == nil) {
            printLog(self, funcName: "connectionFinalized", logString: "Unable to start info w nil delegate?.currentPeripheral")
            return
        }

        connectionTimer?.invalidate()

        connectionStatus = ConnectionStatus.connecting
    }
}
