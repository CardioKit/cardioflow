import Foundation
import SwiftUI
import SwiftData
import PeakSwift

struct SnippetsView: View {
    @Environment(\.modelContext) private var modelContext
    let uuid: UUID
    var snippets: [EcgSnippet] = []
    
    init(uuid: UUID) {
        self.uuid = uuid
        snippets = ProcessEcg.shared.loadSnippetsOfRecording(recordingID: uuid)
    }
    
    var body: some View {
        List(snippets) { snippet in
            NavigationLink(destination: EcgDetailView(snippet: snippet)){
                /*HStack {
                    Text(qualityToString(quality: snippet.quality))
                    Text(snippet.annotation.description  + " -").bold()
                    Text("Diagnosis:")
                    Text(snippet.anomalyDetected?.description ?? "Unknown").bold()
                }*/
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("ID")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(snippet.uuid.uuidString)
                                .font(.headline)
                                .bold()
                                .lineLimit(1)
                            Spacer()
                        }
                        HStack {
                            Text("Residual")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(String(snippet.residual ?? -1.0))
                                .font(.headline)
                                .bold()
                        }
                        
                        /*HStack {
                            Text("Diagnosis")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(snippet.annotation.description)
                                .font(.headline)
                                .bold()
                            Spacer()
                        }
                        
                        HStack {
                            Text("Anomaly")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(snippet.anomalyDetected?.description ?? "Unknown")
                                .font(.headline)
                                .bold()
                        }*/
                    }
                    .padding()
                }
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        modelContext.delete(snippet)
                    }
                }
            }
        }.navigationTitle("Heart Beats")
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
    
    func dateToString(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}
