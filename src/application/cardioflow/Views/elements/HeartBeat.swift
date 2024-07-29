import Foundation
//
// Copyright © 2022 Swift Charts Examples.
// Open Source - MIT License

import SwiftUI
import Charts

struct HeartBeat: View {
    let isOverview: Bool
    let isContinuous: Bool
    let voltage: [Double]
    let reconstruction: [Double]
    let samplingRate: Double
    let date: Date
    let bpm: UInt8
    
    @State private var lineWidth = 2.0
    @State private var chartColor: Color = .pink
    @State private var chartColorRec: Color = .blue
    
    var body: some View {
        if isOverview {
            chartAndLabels
        } else {
            List {
                Section {
                    chartAndLabels
                }
            }
            .navigationBarTitle("Electrocardiograms (ECGs)", displayMode: .inline)
        }
    }
    
    private var chartAndLabels: some View {
        VStack(alignment: .leading) {
            Group {
                Text(date, style: .date) +
                Text(" at ") +
                Text(date, style: .time)
            }
            .foregroundColor(.secondary)
            chart
            HStack {
                if bpm > 0 {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.pink)
                        .symbolEffect(.pulse, options: .repeating.speed(1 ), isActive: true)
                    Text(String(bpm))
                        .contentTransition(.numericText())
                        .animation(.linear, value: bpm)
                    
                    Text(" BPM Average")
                }
            }
            .foregroundColor(.secondary)
        }
        .frame(height: 300)
    }
    
    private var startIdx: Int {
        if (isContinuous) {
            max(voltage.count - 2*Int(samplingRate), 0)
        } else {
            0
        }
    }
    
    private var startIdxRec: Int {
        if (isContinuous) {
            max(reconstruction.count - 2*Int(samplingRate), 0)
        } else {
            0
        }
    }
    
    private var samples: [Double] {
        Array(voltage[startIdx..<voltage.count])
    }
    
    private var samplesReconstruction: [Double] {
        Array(reconstruction[startIdxRec..<reconstruction.count])
    }
    
    struct Combined: Identifiable {
        var id: UUID
        
        var value: Double
        var timestamp: Int
        var signal: String
        var signalColor: Color
        
        init(value: Double, timestamp: Int, signal: String, signalColor: Color = .red) {
            self.id = UUID()
            self.value = value
            self.timestamp = timestamp
            self.signal = signal
            self.signalColor = signalColor
        }
    }
    
    private var combinedData: [Combined] {
        let originalData = samples.enumerated().map { (index, value) in
            Combined(value: value, timestamp: 2*index, signal: "Original")
        }
        let reconstructionData = reconstruction.enumerated().map { (index, value) in
            Combined(value: value, timestamp: 2*index, signal: "Reconstruction", signalColor: .blue)
        }
        return originalData + reconstructionData
    }
    
    private var chart: some View {
        Chart(combinedData) { item in
            LineMark(
                x: .value("Time [ms]", item.timestamp),
                y: .value("mV", item.value)
            )
            .foregroundStyle(by: .value("Signal", item.signal))
            .lineStyle(StrokeStyle(lineWidth: lineWidth))
            .interpolationMethod(.cardinal)
            .accessibilityLabel("\(item.timestamp + startIdx)s")
            .accessibilityValue("\(item.value) mV")
            .accessibilityHidden(isOverview)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 8)) { value in
                if let doubleValue = value.as(Double.self),
                   let intValue = value.as(Int.self) {
                    if doubleValue - Double(intValue) == 0 {
                        AxisTick(stroke: .init(lineWidth: 1))
                            .foregroundStyle(.gray)
                        AxisValueLabel() {
                            Text("\(intValue)ms")
                        }
                        AxisGridLine(stroke: .init(lineWidth: 1))
                            .foregroundStyle(.gray)
                    } else {
                        AxisGridLine(stroke: .init(lineWidth: 1))
                            .foregroundStyle(.gray.opacity(0.25))
                    }
                }
            }
        }
        .chartXAxis(isContinuous ? .hidden : .visible)
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 14)) { value in
                AxisGridLine(stroke: .init(lineWidth: 1))
                    .foregroundStyle(.gray.opacity(0.25))
            }
        }
        .chartPlotStyle {
            $0.border(Color.gray)
        }
        .accessibilityChartDescriptor(self)
    }
}

// MARK: - Accessibility

extension HeartBeat: AXChartDescriptorRepresentable {
    func makeChartDescriptor() -> AXChartDescriptor {
        let min = voltage.min() ?? 0.0
        let max = voltage.max() ?? 0.0
        
        let xAxis = AXNumericDataAxisDescriptor(
            title: "Time",
            range: Double(0)...Double(voltage.count),
            gridlinePositions: []
        ) { value in "\(value)ms" }
        
        
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Millivolts",
            range: Double(min)...Double(max),
            gridlinePositions: []
        ) { value in "\(value) mV" }
        
        let series = AXDataSeriesDescriptor(
            name: "ECG data",
            isContinuous: true,
            dataPoints: voltage.enumerated().map {
                .init(x: Double($0), y: $1)
            }
        )
        
        return AXChartDescriptor(
            title: "ElectroCardiogram (ECG)",
            summary: nil,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

// MARK: - Preview

//struct HeartBeat_Previews: PreviewProvider {
//    static var previews: some View {
//        HeartBeat(isOverview: true)
//        HeartBeat(isOverview: false)
//    }
//}
