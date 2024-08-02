import Foundation
import SwiftData
import PeakSwift
import SwiftCSV
import UniformTypeIdentifiers
import CoreML

@Observable
class ProcessEcg {
    
    static let shared = ProcessEcg()
    
    public var isEmbedd: Bool = false
    public var isReconstruct: Bool = false
    public var outlierThreshold: Float = 0.05
    
    public var isSegment: Bool = false
    public var progressSegment: Double = 0.0
    public var whichSegment: Int = 0
    public var totalSegments: Int = 0
    
    public var isPredict: Bool = false
    public var progressPredict: Double = 0.0
    
    public var isExport: Bool = false
    public var progressExport: Double = 0.0
    
    public var isAnomaly: Bool = false
    public var progressAnomaly: Double = 0.0
    
    public var isLoadCSV: Bool = false
    public var progressLoadCSV: Double = 0.0
    
    private var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            EcgRecording.self,
            EcgSnippet.self,
            Embedding.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    func segmentEcg() {
        
        self.isSegment = true
        
        let final_length = 500
        let batchSizeStorage = 2048
        let signalQualityEvaluator = ECGQualityEvaluator()
        
        Task {
            do {
                let context = ModelContext(sharedModelContainer)
                var unprocessedEcgRecordings = FetchDescriptor<EcgRecording>(predicate: #Predicate { $0.processed == false })
                unprocessedEcgRecordings.propertiesToFetch = [\.uuid]
                let uuids: [UUID] = try context.fetch(unprocessedEcgRecordings).map { $0.uuid }
                self.totalSegments = uuids.count
                
                for (uuidIndex, uuid) in uuids.enumerated() {
                    self.whichSegment = uuidIndex + 1
                    let ecgRecordingsFetchDescriptor = FetchDescriptor<EcgRecording>(predicate: #Predicate { $0.uuid == uuid })
                    let ecgRecordings: [EcgRecording] = try context.fetch(ecgRecordingsFetchDescriptor)
                    let ecgRecording = ecgRecordings[0]
                    
                    // Extract long-term ECG recording and annotations
                    let parentId = ecgRecording.uuid
                    let ecg = ecgRecording.values
                    let samplingRate = ecgRecording.source.frequency
                    let annotations = ecgRecording.annotations
                    let hasAnnotations = !annotations.isEmpty
                    let onset = UInt(samplingRate / 2.0)
                    let offset = UInt(samplingRate / 2.0)
                    
                    // Detect R-peaks in the long-term ECG recording
                    let qrsResult = Preprocess.shared.getQRSResult(ecg: ecg, samplingRate: samplingRate)
                    //ecgRecording.rPeaks = qrsResult.rPeaks
                    
                    // Determine the center of the final one-second ECG sample, either the annotation or detected R-peak
                    let sampleCenters = hasAnnotations ? ecgRecording.annotations.map { $0.index } : qrsResult.rPeaks
                    
                    // Use the cleaned signal to cut the long-term ECG into segments and finally upsample
                    let cleanedSignal = qrsResult.cleanedElectrocardiogram
                    let segments = Preprocess.shared.cutElectrocardiogramInSegments(signal: cleanedSignal.ecg, center: sampleCenters, onset: onset, offset: offset)
                    let upsampledEcgData = segments.map { Preprocess.shared.upsampleToLength(signal: $0, finalLength: final_length) }
                    let normalizedEcgData = Preprocess.shared.normalizeSignals(upsampledEcgData, factor: 1.0)
                    let matrix = Preprocess.shared.convertToFloat32(normalizedEcgData)
                    
                    // Assign annotation
                    let diagnosis = hasAnnotations ? ecgRecording.annotations.map(\.diagnosis) : sampleCenters.map { _ in Diagnosis.none }
                    let ecgsWithDiagnosis = zip(matrix, diagnosis)
                    
                    // Remove ECGs that shall not be considered
                    let filteredEcgsWithDiagnosis = ecgsWithDiagnosis.filter { $0.1 != .unknown }
                    
                    let totalCount = matrix.count
                    
                    var ecgSnippetArray: [EcgSnippet] = []
                    
                    for (index, ecgWithDiagnosis) in filteredEcgsWithDiagnosis.enumerated() {
                        
                        await MainActor.run {
                            self.progressSegment = Double(index) / Double(totalCount)
                        }
                        
                        let (element, diagnosis) = ecgWithDiagnosis
                        
                        // Assess signal quality using Zhao's 2018 method implemented in PeakSwift
                        let ecgDouble = element.map { Double($0) }
                        let signalQuality = signalQualityEvaluator.evaluateECGQuality(
                            electrocardiogram: Electrocardiogram(ecg: ecgDouble, samplingRate: samplingRate),
                            algorithm: .zhao2018(.fuzzy)
                        )
                        
                        // Generate the ECG snippet with the relevant information
                        let ecgSnippet = EcgSnippet(values: element, lengthMS: Int64(final_length), parent: parentId, quality: signalQuality, annotation: diagnosis)
                        
                        ecgSnippetArray.append(ecgSnippet)
                        if index % batchSizeStorage == 0 || index == totalCount - 1 {
                            ecgRecording.snippets.append(contentsOf: ecgSnippetArray)
                            try context.save()
                            ecgSnippetArray.removeAll()
                        }
                    }
                    ecgRecording.processed = true
                }
                try context.save()
            } catch {
                self.isSegment = false
                print(error)
            }
            await MainActor.run {
                self.isSegment = false
            }
        }
    }
    
    func predictECG() {
        
        MachineLearning.loadUpdatedModel()
        let batchSize = 1024
        self.isPredict = true
        
        Task {
            do {
                
                let context = ModelContext(sharedModelContainer)
                var ecgSnippetsFetch = FetchDescriptor<EcgSnippet>()
                let totalSnippets = try context.fetchCount(ecgSnippetsFetch)
                
                for startIndex in stride(from: 0, to: totalSnippets, by: batchSize)  {
                    await MainActor.run {
                        progressPredict = Double(startIndex) / Double(totalSnippets)
                    }
                    ecgSnippetsFetch.fetchLimit = batchSize
                    ecgSnippetsFetch.fetchOffset = startIndex
                    ecgSnippetsFetch.propertiesToFetch = [\.values, \.residual, \.reconstruction, \.embedding]
                    
                    let ecgSnippets: [EcgSnippet] = try context.fetch(ecgSnippetsFetch)
                    let batch = ecgSnippets.map { $0.values }
                    if let multiArray = MachineLearning.shared.convertToMLMultiArray(matrix: batch) {
                        let input = ecgVAECInput(x: multiArray)
                        guard let prediction = MachineLearning.shared.predict(input: input),
                              let reconstructions = MachineLearning.shared.convertToFloatMatrix(mlMultiArray: prediction.var_22),
                              let embeddings = MachineLearning.shared.convertToFloatMatrix(mlMultiArray: prediction.linear_1)
                        else {
                            print("Prediction or conversion to float matrix failed for batch starting at index \(startIndex)")
                            continue
                        }
                        let residuals = Preprocess.shared.calculateMatrixDifference(matrix1: reconstructions, matrix2: batch)
                        
                        for (index, elements) in reconstructions.enumerated() {
                            ecgSnippets[index].reconstruction = elements
                            ecgSnippets[index].residual = residuals[index]
                            
                            ecgSnippets[index].embedding = Embedding(values: embeddings[index])
                            ecgSnippets[index].embedded = true
                        }
                        try context.save()
                        
                    } else {
                        print("Failed to convert batch starting at index \(startIndex) to MLMultiArray")
                    }
                }
                await MainActor.run {
                    self.isPredict = false
                }
            } catch {
                self.isPredict = false
                print("Failed to fetch ECG snippets: \(error)")
            }
        }
    }
    
    func detectAnomalies(threshold: Float = 0.02) {
        
        let batchSize = 1024
        self.isAnomaly = true
        
        Task {
            do {
                let context = ModelContext(sharedModelContainer)
                var ecgSnippetsFetch = FetchDescriptor<EcgSnippet>()
                let totalSnippets = try context.fetchCount(ecgSnippetsFetch)
                
                for startIndex in stride(from: 0, to: totalSnippets, by: batchSize)  {
                    
                    ecgSnippetsFetch.fetchLimit = batchSize
                    ecgSnippetsFetch.fetchOffset = startIndex
                    ecgSnippetsFetch.propertiesToFetch = [\.residual, \.anomalyDetected]
                    
                    let ecgSnippets: [EcgSnippet] = try context.fetch(ecgSnippetsFetch)
                    
                    for (index, elements) in ecgSnippets.enumerated() {
                        await MainActor.run {
                            self.progressAnomaly = Double(startIndex+index) / Double(totalSnippets)
                        }
                        if let residual = elements.residual {
                            elements.anomalyDetected = residual > threshold
                        } else {
                            print("No residual available")
                        }
                    }
                    try context.save()
                }
            } catch {
                print(error)
                self.isAnomaly = false
            }
            await MainActor.run {
                self.isAnomaly = false
            }
        }
    }
    
    func prepareCSVasURL(completion: @escaping (URL?) -> Void) {
        
        self.isLoadCSV = true
        Task {
            do {
                var rowsCSV: [String] = []
                let batchSize = 2048
                let id = UUID()
                let fileManager = FileManager.default
                let documentsURL = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                let fileURL = documentsURL.appendingPathComponent(id.uuidString + "_ecg_data.csv")
                let context = ModelContext(sharedModelContainer)
                
                var ecgSnippetsFetch = FetchDescriptor<EcgSnippet>()
                let totalSnippets = try context.fetchCount(ecgSnippetsFetch)
                
                for startIndex in stride(from: 0, to: totalSnippets, by: batchSize)  {
                    await MainActor.run {
                        self.progressLoadCSV = Double(startIndex) / Double(totalSnippets)
                    }
                    ecgSnippetsFetch.fetchLimit = batchSize
                    ecgSnippetsFetch.fetchOffset = startIndex
                    ecgSnippetsFetch.propertiesToFetch = [\.values, \.residual, \.reconstruction, \.embedding]
                    
                    let ecgs: [EcgSnippet] = try context.fetch(ecgSnippetsFetch)
                    
                    let items = ecgs.map { ecg in
                        let uuid = ecg.parent
                        let error = (ecg.residual != nil) ? String(format: "%.5f", ecg.residual!) : "NA"
                        let embeddingData = (ecg.embedding != nil) ? ecg.embedding!.stringRepresentation : ""
                        let quality = qualityToString(quality: ecg.quality)
                        return "\(uuid.uuidString),\(quality),\(ecg.annotation.description),\(error),\(embeddingData)"
                    }
                    rowsCSV.append(contentsOf: items)
                }
                
                let csvString = rowsCSV.joined(separator: "\n")
                try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
                await MainActor.run {
                    self.isLoadCSV = false
                }
                
                return completion(fileURL)
                
            } catch {
                print("Error creating CSV file: \(error)")
                self.isLoadCSV = false
                return completion(nil)
            }
        }
    }
    
    func qualityToString(quality: ECGQualityRating) -> String {
        switch quality {
        case .excellent:
            return "excellent"
        case .barelyAcceptable:
            return "medium"
        case .unacceptable:
            return "bad"
        }
    }
    
    func deleteAll() {
        sharedModelContainer.deleteAllData()
    }
    
    
    func loadCSV(from url: URL) -> EcgRecording? {
        guard url.startAccessingSecurityScopedResource() else {
            print("Could not access security scoped resource")
            return nil
        }
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        guard let csv = try? CSV<Named>(url: url) else {
            print("Failed to load CSV from URL")
            return nil
        }
        
        guard let signal = csv.columns?["signal"]?.compactMap(Double.init) else {
            print("Failed to parse 'signal' column")
            return nil
        }
        
        guard let annotations = csv.columns?["annotation"]?.compactMap(Diagnosis.init) else {
            print("Failed to parse 'annotation' column")
            return nil
        }
        let relevantValues = [Diagnosis.pac, Diagnosis.pvc, Diagnosis.normal]
        let elements = annotations.enumerated().compactMap { relevantValues.contains($0.element) ? Annotation(index: UInt($0.offset), diagnosis: $0.element) : nil }
        let lastPathComponent = url.lastPathComponent
        let fileNameWithoutExtension = (lastPathComponent as NSString).deletingPathExtension
        let recording = EcgRecording(signal: signal, name: fileNameWithoutExtension, source: Source.icentia(frequency: 250), annotations: elements)
        return recording
    }
    
    func loadCSVs(urls: [URL]) {
        self.isLoadCSV = true
        Task {
            let context = ModelContext(sharedModelContainer)
            let numberFiles = urls.count
            let batchSize = 1 // Define a batch size for processing
            
            for batch in stride(from: 0, to: numberFiles, by: batchSize) {
                autoreleasepool {
                    let batchUrls = urls[batch..<min(batch + batchSize, numberFiles)]
                    for (index, url) in batchUrls.enumerated() {
                        self.progressLoadCSV = Double(batch + index) / Double(numberFiles)
                        let recording = self.loadCSV(from: url)
                        if let recording = recording {
                            context.insert(recording)
                        }
                    }
                    do {
                        try context.save()
                    } catch {
                        self.isLoadCSV = false
                        print("Failed to save context: \(error)")
                    }
                }
            }
            await MainActor.run {
                self.isLoadCSV = false
            }
        }
    }
    
    func loadSnippetsOfRecording(recordingID: UUID, fetchLimit: Int = 500) -> [EcgSnippet] {
        
        // To keep the plot clean, only a subset of points is returned
        // To account for "randomness" we sort by uuid
        var fetchDescriptor = FetchDescriptor<EcgSnippet>(predicate: #Predicate { $0.parent == recordingID }, sortBy: [SortDescriptor(\.uuid)])
        fetchDescriptor.propertiesToFetch = [\.embedding, \.residual, \.anomalyDetected]
        fetchDescriptor.fetchLimit = fetchLimit
        
        var ecgSnippets: [EcgSnippet] = []
        do {
            let context = ModelContext(sharedModelContainer)
            ecgSnippets = try context.fetch(fetchDescriptor)
        } catch {
            print("Failed to load ECG Snippets")
            return ecgSnippets
        }
        return ecgSnippets
    }
}
