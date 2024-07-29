import Foundation
import SwiftUI
import SwiftData
import PolarBleSdk
import Charts
import PolarBleSdk
import SwiftData
import CoreML
import UniformTypeIdentifiers


struct RecordingView: View {
    @State var polarSdkManager = PolarSDKManager()
    @Environment(\.modelContext) private var modelContext
    let feature: PolarDeviceDataType
    
    var body: some View {
        VStack {
            connectionIndicator(connectionStatus: polarSdkManager.deviceConnectionState, batteryLevel: polarSdkManager.batteryStatusFeature)
            HeartBeat(isOverview: true, isContinuous: true, voltage: polarSdkManager.voltage, reconstruction: [], samplingRate: 130.0, date: Date(), bpm: polarSdkManager.bpm).padding()
            HStack {
                Button(textForConnectButton(polarSdkManager.deviceConnectionState), systemImage: "heart") {
                    switch polarSdkManager.deviceConnectionState {
                    case .connected:
                        polarSdkManager.disconnectFromDevice()
                    case .disconnected:
                        polarSdkManager.connectToDevice()
                    default:
                        break
                    }
                }
                Button("Record", systemImage: "waveform.path.ecg") {
                    if(polarSdkManager.isStreamOn(feature: feature)) {
                        polarSdkManager.onlineStreamStop(feature: feature)
                    } else {
                        startStream()
                    }
                }
            }
            .foregroundStyle(.background)
            .buttonStyle(.borderedProminent)
        }
    }
    
    @ViewBuilder
    private func connectionIndicator(connectionStatus: DeviceConnectionState, batteryLevel: BatteryStatusFeature) -> some View {
        HStack {
            Circle()
                .frame(width: 8, height: 8)
                .foregroundColor(colorForStatus(connectionStatus))
            Text(connectionStatus.description).foregroundColor(.gray)
            Text(String(batteryLevel.batteryLevel) + "%").foregroundColor(.gray)
        }
    }
    
    private func isStreamOn() -> Bool {
        let isOn = polarSdkManager.isStreamOn(feature: .ecg)
        return !isOn
    }
    
    private func textForConnectButton(_ status: DeviceConnectionState) -> String {
        switch status {
        case .connecting(_):
            return "Connecting"
        case .disconnected(_):
            return "Connect"
        case .connected(_):
            return "Disconnect"
        }
    }
    
    private func colorForStatus(_ status: DeviceConnectionState) -> Color {
        switch status {
        case .connected:
            return .green
        case .connecting:
            return .yellow
        case .disconnected:
            return .gray
        }
    }
    
    func startStream() {
        let sampleRate = 130
        let resolution = 14
        let settings = [TypeSetting(type: .sampleRate, values: [sampleRate]), TypeSetting(type: .resolution, values: [resolution])]
        let selectedSettings = RecordingSettings(feature: feature, settings: settings)
        polarSdkManager.onlineStreamStart(feature: feature, settings: selectedSettings, context: modelContext)
        polarSdkManager.onlineStreamStart(feature: .hr, settings: nil, context: modelContext)
    }
}
