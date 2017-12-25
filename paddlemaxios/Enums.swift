import UIKit

// MARK: Bluetooth state

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
