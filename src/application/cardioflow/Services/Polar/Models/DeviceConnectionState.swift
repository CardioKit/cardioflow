import Foundation

enum DeviceConnectionState {
    case disconnected(String)
    case connecting(String)
    case connected(String)
    
    var description : String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting"
        case .connected(let deviceId): return "\(deviceId)"
        }
      }
}
