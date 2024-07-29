import Foundation
import SwiftUI
import Charts
import PolarBleSdk
import SwiftData
import CoreML
import SwiftCSV
import UniformTypeIdentifiers


struct HomeView: View {
    
    @State var polarSdkManager = PolarSDKManager()
    @Environment(\.modelContext) private var modelContext
    
    @State private var dimensionSelectionX: Int = 0
    @State private var dimensionSelectionY: Int = 1
    
    @State private var selectedRecording: UUID? = nil //UUID()
    
    let dimensions = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
    
    static var fetchDescriptorUUID: FetchDescriptor<EcgRecording> {
        var descriptor = FetchDescriptor<EcgRecording>()
        descriptor.propertiesToFetch = [\.uuid, \.name]
        return descriptor
    }
    
    @Query(fetchDescriptorUUID) var recordings: [EcgRecording]
    @State private var snippets: [EcgSnippet] = []
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        IndicatorView(number: numberRecordings, title: "Segments")
                        IndicatorView(number: numberSnippets, title: "Beats")
                        IndicatorView(number: numberOutliers, title: "Anomalies")
                    }
                    .listRowBackground(Color.clear)
                }
                
                Section(header: Text("Source")){
                    Picker("Recording", selection: $selectedRecording) {
                        Text("Select").font(.footnote).tag(nil as UUID?)
                        ForEach(recordings, id: \.self) { item in
                            Text(item.name).font(.footnote).tag(item.uuid as UUID?)
                        }
                    }.onChange(of: selectedRecording) {
                        if let selectedRecording = selectedRecording {
                            self.snippets = ProcessEcg.shared.loadSnippetsOfRecording(recordingID: selectedRecording)
                        }
                    }
                }
                if snippets.isEmpty == false {
                    Section(header: Text("Embedding Space")){
                        HStack {
                            Picker("X-Dimension", selection: $dimensionSelectionX) {
                                ForEach(dimensions, id: \.self) { item in
                                    Text(item.description)
                                }
                            }
                            Spacer()
                            Picker("Y-Dimension", selection: $dimensionSelectionY) {
                                ForEach(dimensions, id: \.self) { item in
                                    Text(item.description)
                                }
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Chart(snippets) { item in
                            if let embeddingValues = item.embedding {
                                PointMark(
                                    x: .value("X", embeddingValues.values[dimensionSelectionX]),
                                    y: .value("Y", embeddingValues.values[dimensionSelectionY])
                                )
                                .foregroundStyle(by: .value("Family", item.annotation.description))
                                .symbolSize(10)
                            }
                        }
                        .frame(height: 300)
                    }
                    Section(header: Text("Error Distribution")){
                        DistributionPlotView(data: snippets.map { $0.residual ?? 0.0 }, binCount: 10).padding()
                    }
                }
            }
            .navigationTitle("Cardioflow")
        }
    }
    
    var numberRecordings: String  {
        let fetchEcgRecordings = FetchDescriptor<EcgRecording>()
        var number: String = "NA"
        do {
            number = String(try modelContext.fetchCount(fetchEcgRecordings))
        } catch {
            print("\(error)")
        }
        return number
    }
    
    var numberSnippets: String  {
        let fetchEcgSnippets = FetchDescriptor<EcgSnippet>()
        var number: String = "NA"
        do {
            number = String(try modelContext.fetchCount(fetchEcgSnippets))
        } catch {
            print("\(error)")
        }
        return number
    }
    
    var numberOutliers: String  {
        let fetchOutlierSnippets = FetchDescriptor<EcgSnippet>(predicate: #Predicate { $0.anomalyDetected == true})
        var number: String = "NA"
        do {
            number = String(try modelContext.fetchCount(fetchOutlierSnippets))
        } catch {
            print("\(error)")
        }
        return number
    }
}
