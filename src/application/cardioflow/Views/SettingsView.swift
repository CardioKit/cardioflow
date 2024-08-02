import Foundation
import SwiftData
import SwiftUI
import Charts
import PeakSwift

struct SettingsView: View {
    
    @Environment(\.modelContext) private var modelContext
    
    @State private var outlierPercentile = 50
    @State private var epochs = 10
    @State private var batchSize = 128
    @State private var shareLink: URL? = nil
    
    @State private var testSegment: UUID? = nil
    
    @State var processECG = ProcessEcg.shared
    @State var machineLearning = MachineLearning.shared
    @State var federatedLearning = FederatedLearning.shared
    
    @State private var testDataUUID: UUID? = nil
    
    var numberFormatter: NumberFormatter = {
        var nf = NumberFormatter()
        nf.usesGroupingSeparator = false
        nf.numberStyle = .none
        return nf
    }()
    
    private var logText: String {
        if let client = federatedLearning.mlFlwrClient {
            return client.logText
        } else {
            return "FL has not started yet."
        }
    }
    
    static var fetchDescriptorUUID: FetchDescriptor<EcgRecording> {
        var descriptor = FetchDescriptor<EcgRecording>()
        descriptor.propertiesToFetch = [\.uuid, \.name]
        return descriptor
    }
    
    @Query(fetchDescriptorUUID) var recordings: [EcgRecording]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Data preprocessing")){
                    HStack {
                        Text("Segment ECG")
                        Spacer()
                        if processECG.isSegment {
                            VStack {
                                ProgressView(value: processECG.progressSegment).progressViewStyle(CircularProgressViewStyle(circleText: String(processECG.whichSegment) + "/" + String(processECG.totalSegments))).frame(width: 75, height: 75)
                            }
                        } else {
                            Button(action: {
                                processECG.segmentEcg()
                            }) {
                                Text("Start")
                            }
                        }
                    }
                    HStack {
                        Text("Predict ECG")
                        Spacer()
                        if processECG.isPredict {
                            VStack {
                                ProgressView(value: processECG.progressPredict).progressViewStyle(CircularProgressViewStyle(circleText: String(Int(processECG.progressPredict*100)) + "%")).frame(width: 75, height: 75)
                            }
                        } else {
                            Button(action: {
                                processECG.predictECG()
                            }) {
                                Text("Start")
                            }
                        }
                    }
                }
                Section(header: Text("Data Split")) {
                    HStack {
                        Text("Test Segment").frame(alignment: .leading)
                        Spacer()
                        Picker("", selection: $testDataUUID) {
                            Text("Select").font(.footnote).tag(nil as UUID?)
                            ForEach(recordings, id: \.self) { item in
                                Text(item.name).font(.footnote).tag(item.uuid as UUID?)
                            }
                        }
                        .onChange(of: testDataUUID) {
                            if let testDataUUID = testDataUUID {
                                self.testDataUUID = testDataUUID
                            }
                        }
                    }
                    if machineLearning.isPrepareBatch {
                        HStack {
                            Text("Transform Data").frame(alignment: .leading)
                            Spacer()
                            ProgressView(value: machineLearning.progressPrepareBatch).progressViewStyle(CircularProgressViewStyle(circleText: machineLearningText)).frame(width: 75, height: 75)
                        }
                    }
                }
                Section(header: Text("Machine Learning")) {
                    HStack {
                        Text("Finetune Model").frame(alignment: .leading)
                        Spacer()
                        if machineLearning.isMachineLearning {
                            ProgressView(value: machineLearning.progressMachineLearning).progressViewStyle(CircularProgressViewStyle(circleText: machineLearningText)).frame(width: 75, height: 75)
                        } else {
                            Button(action: {
                                if let testDataUUID = testDataUUID {
                                    machineLearning.fineTuneModel(testData: testDataUUID)
                                }
                            }) {
                                Text("Start")
                            }
                        }
                    }
                    HStack {
                        Text("Epochs: \(machineLearning.epochs)")
                        Spacer()
                        Stepper("", value: $machineLearning.epochs, in: 1...1000)
                    }
                    HStack {
                        Text("Batch Size: \(batchSize)")
                        Stepper("", value: $batchSize, in: 1...1025)
                    }
                }
                Section(header: Text("Federated Learning")) {
                    HStack {
                        Text("Server Hostname: ")
                        Spacer()
                        TextField("Server Hostname", text: $federatedLearning.hostname)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Server Port: ")
                        TextField( "Server Port", value: $federatedLearning.port, formatter: numberFormatter)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Federated Learning ")
                        Spacer()
                        Button(action: {
                            runFlwr()
                        }){
                            Text("Start")
                        }
                    }
                    HStack {
                        Text("Log")
                        Spacer()
                        Text(logText)
                            .font(.custom("Arial", size: 14))
                            .multilineTextAlignment(.trailing)
                    }
                }
                Section(header: Text("Anomaly Detection")) {
                    HStack {
                        Text(String(format: "Threshold: %.3f", Float(outlierPercentile) / 1000.0))
                        Stepper("", value: $outlierPercentile, in: 0...1000, step: 1)
                    }
                    HStack {
                        Text("Calculate Outliers")
                        Spacer()
                        if processECG.isAnomaly {
                            ProgressView(value: processECG.progressAnomaly).progressViewStyle(CircularProgressViewStyle(circleText: String(Int(processECG.progressAnomaly*100)) + "%")).frame(width: 75, height: 75)
                        } else {
                            Button(action: {
                                processECG.detectAnomalies(threshold: Float(outlierPercentile) / 1000.0)
                            }) {
                                Text("Start")
                            }
                        }
                    }
                    HStack {
                        Text("This is a simple approach to detecting anomalies by thresholding the reconstruction error. The assumption is that a large reconstruction error correlates with an anomaly or a noisy signal.").font(.footnote)
                    }
                }
                Section(header: Text("Save and Share")) {
                    HStack {
                        Text("Export to CSV")
                        Spacer()
                        if processECG.isLoadCSV {
                            ProgressView(value: processECG.progressLoadCSV).progressViewStyle(CircularProgressViewStyle(circleText: String(Int(processECG.progressLoadCSV*100)) + "%")).frame(width: 75, height: 75)
                        } else {
                            Button(action: {
                                processECG.prepareCSVasURL { fileURL in
                                    self.shareLink = fileURL
                                }
                            }) {
                                Text("Start")
                            }
                        }
                    }
                    
                    if let shareLink = shareLink {
                        HStack {
                            Text("Share")
                            Spacer()
                            
                            ShareLink(item: shareLink) {
                                Label("", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                }
                Section(header: Text("Edit Data")) {
                    HStack {
                        Text("Delete All")
                        Spacer()
                        Button(action: {
                            processECG.deleteAll()
                        }) {
                            Text("Start")
                        }
                    }
                    Text("Attention: This operation deletes the entire database without control mechanisms, which can lead to unexpected behavior and errors.").font(.footnote)
                }
            }
            .navigationTitle("Settings")
        }
    }
    
    var machineLearningText: String {
        if machineLearning.isPrepareBatch {
            return String(Int(machineLearning.progressPrepareBatch*100)) + "%"
        } else if machineLearning.isMachineLearning {
            return String(Int(machineLearning.progressMachineLearning*100)) + "%"
        }
        return ""
    }
    
    public func runFlwr() {
        if let testDataUUID = testDataUUID {
            let batchDataDescriptorTrain = FetchDescriptor<EcgSnippet>( predicate: #Predicate { $0.parent != testDataUUID } )
            let batchDataDescriptorTest = FetchDescriptor<EcgSnippet>( predicate: #Predicate { $0.parent == testDataUUID } )
            
            machineLearning.prepareMLBatchProvider(batchDataDescriptorTrain: batchDataDescriptorTrain, batchDataDescriptorTest: batchDataDescriptorTest) { batchProvider in
                let (trainingBatch, testingBatch) = batchProvider
                federatedLearning.initFederatedLearning(trainingBatchProvider: trainingBatch, testBatchProvider: testingBatch)
                federatedLearning.startFederatedLearning()
            }
        }
    }
}

struct CircularProgressViewStyle: ProgressViewStyle {
    var strokeColor: Color = .blue
    var strokeWidth: CGFloat = 8
    var circleText: String
    
    func makeBody(configuration: Configuration) -> some View {
        let progress = configuration.fractionCompleted ?? 0
        
        return ZStack {
            Circle()
                .stroke(strokeColor.opacity(0.3), lineWidth: strokeWidth)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(strokeColor, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .rotationEffect(Angle(degrees: -90))
            
            Text(circleText)
                .font(.footnote)
                .bold()
                .foregroundColor(strokeColor)
        }
        .padding(10)
    }
}
