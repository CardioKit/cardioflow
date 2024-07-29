import Foundation
import PeakSwift

class Preprocess {
    static let shared = Preprocess()
    
    func convertToFloat32(_ doubleArray: [[Double]]) -> [[Float32]] {
        return doubleArray.map { innerArray in
            innerArray.map { Float32($0) }
        }
    }
    
    func normalizeSignals(_ signals: [[Double]], factor: Double = 1.0) -> [[Double]] {
        return signals.map { signal -> [Double] in
            guard let minVal = signal.min(), let maxVal = signal.max(), maxVal > minVal else {
                // Return the original signal if all values are the same or if it's empty
                return signal.map({ sig in
                    sig*factor
                })
            }
            return signal.map { factor*(($0 - minVal) / (maxVal - minVal)) }
        }
    }
    
    func upsampleToLength(signal: [Double], finalLength: Int) -> [Double] {
        guard finalLength > signal.count, !signal.isEmpty else { return signal }
        
        var upsampledSignal = [Double](repeating: 0, count: finalLength)
        let scaleFactor = Double(signal.count - 1) / Double(finalLength - 1)
        
        for i in 0..<finalLength {
            let originalIndex = Double(i) * scaleFactor
            let lowerIndex = Int(originalIndex)
            let upperIndex = lowerIndex + 1 < signal.count ? lowerIndex + 1 : lowerIndex
            let interpolationRatio = originalIndex - Double(lowerIndex)
            
            // Linear interpolation
            let interpolatedValue = signal[lowerIndex] + (signal[upperIndex] - signal[lowerIndex]) * interpolationRatio
            upsampledSignal[i] = interpolatedValue
        }
        return upsampledSignal
    }
    
    func cutElectrocardiogramInSegments(signal: [Double], center: [UInt], onset: UInt = 65, offset: UInt = 65) -> [[Double]]{
        var segments: [[Double]] = []
        
        for centerIndex in center {
            // Ensure centerIndex, onset, and offset are valid for conversion to Int
            if centerIndex > UInt(Int.max) || onset > UInt(Int.max) || offset > UInt(Int.max) {
                continue
            }
            
            let start = Int(centerIndex) - Int(onset)
            let end = Int(centerIndex) + Int(offset)
            
            // Check if the calculated start and end indices are within the bounds of the signal array
            if start >= 0 && end < signal.count {
                let segment = Array(signal[start..<end])
                segments.append(segment)
            }
            // If start or end index is out of bounds, skip this center
        }
        return segments
    }
    
    func getQRSResult(ecg: [Double], samplingRate: Double, algorithm: PeakSwift.Algorithms = .neurokit) -> QRSResult {
        let electrocardiogram = Electrocardiogram(ecg: ecg, samplingRate: samplingRate)
        let qrsDetector = QRSDetector()
        let qrsResult = qrsDetector.detectPeaks(electrocardiogram: electrocardiogram, algorithm: algorithm)
        return qrsResult
    }
    
    func calculateMatrixDifference(matrix1: [[Float32]], matrix2: [[Float32]]) -> [Float32] {
        guard matrix1.count == matrix2.count else {
            fatalError("Matrices must have the same number of rows")
        }
        
        let differences: [Float32] = matrix1.enumerated().map { (i, row1) in
            guard row1.count == matrix2[i].count else {
                fatalError("Matrices must have the same number of columns in each row")
            }
            
            let row2 = matrix2[i]
            let rowDifference = zip(row1, row2).map { abs($0 - $1) }.reduce(0, +) / Float32(row1.count)
            
            return rowDifference
        }
        
        return differences
    }
}
