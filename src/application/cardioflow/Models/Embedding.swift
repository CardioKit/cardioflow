import Foundation
import SwiftData

@Model
class Embedding {
    
    @Attribute(.unique) var uuid = UUID()
    var values: [Float32]
    var snippet: EcgSnippet?
    
    init(values: [Float32]) {
        self.values = values
    }
    
    var stringRepresentation: String {
        values.map { String($0) }.joined(separator: ";")
    }

    var latentDimensions: Int {
        self.values.count
    }
    var distanceToZero: Float32 {
        let sumOfPowers = self.values.reduce(0) { (result, value) -> Float32 in
            return result + pow(value, 2)
        }
        let result = sqrt(sumOfPowers)
        return result
    }
}
