
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

// MARK: Quick stat view options
enum TimePeriod: String {
    case oneWeek    = "This Week"
    case twoWeeks   = "Past 2 Weeks"
    case oneMonth   = "This Month"
    case threeMonth = "Past 3 Months"
    case sixMonth   = "Past 6 Months"
    case oneYear    = "This Year"
}
enum QuickStatValue: String {
    case distance   = "Distance"
    case power      = "Power"
    case time       = "Time"
}

// Localization measurement systems
enum MeasurementSystem: Int {
    case standard
    case metric
}
