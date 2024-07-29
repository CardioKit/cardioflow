import Foundation
import SwiftUI
import Charts



struct DistributionPlotView: View {
    struct Histogram: Identifiable {
        var id = UUID()
        
        let number: String
        let frequency: Int
    }
    var data: [Float]
    let binCount: Int // Adjust the number of bins based on your needs
    private var distributionData: [Histogram] {
        calculateDistributionData()
    }
    
    var body: some View {
        Chart(distributionData, id: \.number) {
            BarMark(
                x: .value("Number", $0.number),
                y: .value("Frequency", $0.frequency)
            )
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel()
                    .font(.system(size: 8))
                
            }
        }
    }
    
    private func calculateDistributionData() -> [Histogram] {
        guard !data.isEmpty else { return [] }
        
        let minValue = data.min() ?? 0
        let maxValue = data.max() ?? 1
        let binSize = (maxValue - minValue) / Float(binCount)
        
        var distribution = [Histogram]()
        
        for i in 0..<binCount {
            let lowerBound = minValue + (binSize * Float(i))
            let upperBound = lowerBound + binSize
            let binRange = lowerBound...upperBound
            
            let frequency = data.filter { binRange.contains($0) }.count
            let mean = Double(binRange.lowerBound + binRange.upperBound) / 2.0
            
            distribution.append(Histogram(number: String(round(mean*100.0)/100.0), frequency: frequency))
        }
        return distribution
    }
}
