import Foundation
import PolarBleSdk

struct OfflineRecordingFeature {
    var isSupported = false
    var availableOfflineDataTypes: [PolarDeviceDataType: Bool] = Dictionary(uniqueKeysWithValues: zip(PolarDeviceDataType.allCases, [false]))
    var isRecording: [PolarDeviceDataType: Bool] = Dictionary.init()
}
