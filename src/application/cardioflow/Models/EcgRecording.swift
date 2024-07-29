import Foundation
import SwiftData
import SwiftCSV
import UniformTypeIdentifiers

enum Source: Codable {
    
    case polar(frequency: Int32)
    case icentia(frequency: Int32)
    
    var description: String {
        switch self {
        case .icentia:
            return "Icentia11k"
        case .polar:
            return "Polar H10"
        }
    }
    
    var frequency: Double {
        switch self {
        case .icentia(let frequency):
            return Double(frequency)
        case .polar(frequency: let frequency):
            return Double(frequency)
        }
    }
}

@Model
class Annotation {
    var index: UInt
    var diagnosis: Diagnosis
    
    init(index: UInt, diagnosis: Diagnosis) {
        self.index = index
        self.diagnosis = diagnosis
    }
}

@Model
class EcgRecording {
    @Attribute(.unique) var uuid = UUID()
    @Attribute(.externalStorage) var values: [Double]
    @Attribute(.externalStorage) var annotations: [Annotation]
    var timestamp: Date
    var name: String
    var processed: Bool = false
    var source: Source
    var rPeaks: [UInt]
    var lengthMs: UInt
    
    @Relationship(deleteRule: .cascade)
    var snippets = [EcgSnippet]()
    
    init(signal: [Double], timestamp: Date = .now, name: String = "", lengthMs: UInt = 0, source: Source = .polar(frequency: 130), annotations: [Annotation] = [], rPeaks: [UInt] = []) {
        self.values = signal
        self.annotations = annotations
        self.timestamp = timestamp
        self.name = name
        self.source = source
        self.rPeaks = rPeaks
        self.lengthMs = lengthMs
    }
    
    var confusionMatrix: [[Int]] {
        var overallConfusionMatrix: [[Int]] = [[0, 0], [0, 0]]
        for snippet in self.snippets {
            let groundtruth = [Diagnosis.pvc, Diagnosis.pac, Diagnosis.arrhythmia].contains(snippet.annotation) ? 1 : 0
            let prediction = snippet.anomalyDetected ?? false ? 1 : 0
            overallConfusionMatrix[groundtruth][prediction] += 1
        }
        return overallConfusionMatrix
    }
}
