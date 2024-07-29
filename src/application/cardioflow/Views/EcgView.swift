import Foundation
import SwiftUI
import SwiftData
import PolarBleSdk
import Charts
import PolarBleSdk
import SwiftData
import CoreML
import PeakSwift

struct EcgView: View {
    
    static var fetchDescriptor: FetchDescriptor<EcgRecording> {
        var descriptor = FetchDescriptor<EcgRecording>()
        descriptor.propertiesToFetch = [\.name, \.timestamp]
        return descriptor
    }
    
    @Environment(\.modelContext) private var modelContext
    
    let dateFormatter = DateFormatter()
    @State var processECG = ProcessEcg.shared
    
    @Query(EcgView.fetchDescriptor) var ecgs: [EcgRecording]
    
    @State var polarSdkManager = PolarSDKManager()
    @State private var showRecordingView = false
    @State private var selection: String? = nil
    @State private var isDocumentPickerPresented = false
    
    var body: some View {
        NavigationView {
            List {
                if showRecordingView {
                    Section("Recording") {
                        RecordingView(feature: .ecg)
                            .transition(.slide)
                    }
                }
                if processECG.isLoadCSV {
                    ProgressView("Load from CSV...", value: processECG.progressLoadCSV)
                }
                Section {
                    ForEach(ecgs) { ecgRecording in
                        NavigationLink(destination: SnippetsView(uuid: ecgRecording.uuid)){
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(dateToString(date: ecgRecording.timestamp))
                                        .italic()
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(ecgRecording.source.description)
                                        .italic()
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(ecgRecording.name)
                                    .bold()
                                    .font(.headline)
                            }
                            .padding()
                            .swipeActions {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    modelContext.delete(ecgRecording)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("ECGs")
            .toolbar {
                Menu {
                    Button("Polar H10", systemImage: "waveform.path.ecg") {
                        withAnimation {
                            showRecordingView.toggle()
                        }
                    }
                    Button("Upload CSV", systemImage: "square.and.arrow.up") {
                        isDocumentPickerPresented.toggle()
                    }
                    Button("Healthkit", systemImage: "cross") {
                        // TODO: Implement
                        print("To be implemented.")
                    }
                } label: {
                    Image(systemName: "plus")
                }
                
            }
            .sheet(isPresented: $isDocumentPickerPresented) {
                DocumentPicker { urls in
                    if let urls = urls {
                        processECG.loadCSVs(urls: urls)
                    }
                }
            }
        }
    }
    
    func dateToString(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
