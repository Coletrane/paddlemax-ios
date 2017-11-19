import UIKit

// MARK: Bluetooth state
enum ConnectionMode: Int {
    case none
    case pinIO
    case uart
    case info
    case controller
    case dfu
}
enum ConnectionStatus: Int {
    case idle = 0
    case scanning
    case connected
    case connecting
}


// Localization measurement systems
enum MeasurementSystem: Int {
    case standard
    case metric
}
