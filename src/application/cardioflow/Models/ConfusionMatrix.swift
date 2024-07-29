import Foundation

struct ConfusionMatrix: Identifiable {
    var id: UUID
    
    var groundtruth: String
    var prediction: String
    var num: Double
}
