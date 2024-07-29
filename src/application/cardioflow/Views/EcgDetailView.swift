import Foundation
import SwiftUI
import SwiftData
import Charts
import PeakSwift
import SwiftCSV
import UniformTypeIdentifiers


struct EcgDetailView: View {
    
    @State var snippet: EcgSnippet
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HeartBeat(isOverview: true, isContinuous: false, voltage: snippet.values.map { Double($0) }, reconstruction: (snippet.reconstruction ?? []).map { Double($0) }, samplingRate: 500.0, date: snippet.timestamp, bpm: 0).padding()
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Quality")
                                .font(.headline)
                            Spacer()
                            Text(qualityToString(quality: snippet.quality))
                                .font(.body)
                        }
                        
                        HStack {
                            Text("Diagnosis")
                                .font(.headline)
                            Spacer()
                            Picker("", selection: $snippet.annotation) {
                                ForEach(Diagnosis.allCases, id: \.self) { option in
                                    Text(String(describing: option))
                                        .font(.body)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        
                        HStack {
                            Text("Residual")
                                .font(.headline)
                            Spacer()
                            Text(String(format: "%.4f", snippet.residual ?? "NA"))
                                .font(.body)
                        }
                    }
                    .padding()
                }
                if let embedding = snippet.embedding {
                    Section {
                        HeatMap(data: embedding).padding()
                    }
                }
            }
        }
    }
    
    func qualityToString(quality: ECGQualityRating) -> String {
        switch quality {
        case .excellent:
            return "🟢"
        case .barelyAcceptable:
            return "🟡"
        case .unacceptable:
            return "🔴"
        }
    }
}
