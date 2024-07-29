// Copyright © 2022 Swift Charts Examples.
// Open Source - MIT License

import SwiftUI
import Charts


struct DimensionValues: Identifiable {
    var id = UUID()
    
    let x: String
    let y: String
    let intensity: Float
    
    var color: Color {
        let normalizedIntensity = abs(intensity) / 10
        let redComponent = Double(normalizedIntensity)
        let greenComponent = Double(1.0 - normalizedIntensity)
        return Color(red: redComponent, green: greenComponent, blue: 0)
    }
}

struct HeatMap: View {
    let data: Embedding
    var body: some View {
        Chart(dataToDimensionValues(embedding: data)) {
                BarMark(
                    x: .value("Dimension", $0.x),
                    y: .value("Intensity", $0.intensity)
                )
        }
    }
    
    private func colorForValue(value: Float) -> Color {
        
        let normalizedIntensity = abs(value) / 10.0
        let redComponent = Double(normalizedIntensity)
        let greenComponent = Double(1.0 - normalizedIntensity)
        return Color(red: redComponent, green: greenComponent, blue: 0)
    }
    
    func dataToDimensionValues(embedding: Embedding) -> [DimensionValues] {
        return embedding.values.enumerated().map { (index, element) in
            DimensionValues(x: String(index + 1), y: "0", intensity: element)
        }
    }
}
