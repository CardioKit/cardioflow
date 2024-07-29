import Foundation
import CoreML
import SwiftData
import PeakSwift


enum Diagnosis: Codable, CaseIterable, Identifiable, CustomStringConvertible {
    case none
    case pac
    case pvc
    case normal
    case arrhythmia
    case unknown
    
    var id: Diagnosis { self }
    
    init?(rawValue: String) {
        switch rawValue {
        case "none":
            self = .none
        case "pac":
            self = .pac
        case "pvc":
            self = .pvc
        case "normal":
            self = .normal
        case "arrhythmia":
            self = .arrhythmia
        case "unknown":
            self = .unknown
        default:
            self = .none
        }
    }
    
    var description: String {
        switch self {
        case .none:
            return "None"
        case .pac:
            return "PAC"
        case .pvc:
            return "PVC"
        case .normal:
            return "Normal"
        case .arrhythmia:
            return "Arrhythmia"
        case .unknown:
            return "Unknown"
        default:
            return "None"
        }
    }
}

enum Flashcard: Codable {
    case first
    case second
    case third
    case fourth
    case fifth
}

@Model
class EcgSnippet {
    @Attribute(.unique) var uuid = UUID()
    var parent: UUID
    var values: [Float32]
    var reconstruction: [Float32]?
    var residual: Float32?
    var trainingRounds: Int32
    var lengthMS: Int64
    var timestamp: Date
    var quality: ECGQualityRating
    var embedded: Bool = false
    var annotation: Diagnosis
    var anomalyDetected: Bool? = nil
    
    @Relationship(deleteRule: .cascade, inverse: \Embedding.snippet)
    var embedding: Embedding?
    
    init(values: [Float32], lengthMS: Int64, parent: UUID, reconstruction: [Float32]? = nil, residual: Float32? = nil, trainingRounds: Int32 = 0, timestamp: Date = .now, quality: ECGQualityRating = .excellent, embedding: Embedding? = nil, annotation: Diagnosis = .none) {
        self.values = values
        self.lengthMS = lengthMS
        self.parent = parent
        
        self.reconstruction = reconstruction
        self.residual = residual
        self.trainingRounds = trainingRounds
        self.timestamp = timestamp
        self.quality = quality
        self.embedding = embedding
        self.annotation = annotation
    }
    
    func updateTrainingRounds(updateValue: Int32) {
        self.trainingRounds += updateValue
    }
    
    var flashCard: Flashcard {
        return Flashcard.first
    }
    
    var featureValueInput: MLFeatureValue {
        let mlMultiArray = try! MLMultiArray(shape: [1, NSNumber(value: values.count)], dataType: .float32)
        for k in 0..<values.count {
            let value = NSNumber(value: values[k])
            mlMultiArray[k] = value
        }
        let mlFeatureValue = MLFeatureValue(multiArray: mlMultiArray)
        return mlFeatureValue
    }
    
    var featureValueOutput: MLFeatureValue {
        let mlMultiArray = try! MLMultiArray(shape: [NSNumber(value: values.count)], dataType: .double)
        for k in 0..<values.count {
            let value = NSNumber(value: values[k])
            mlMultiArray[k] = value
        }
        let mlFeatureValue = MLFeatureValue(multiArray: mlMultiArray)
        return mlFeatureValue
    }
}
