import Foundation
import CoreML
import SwiftData
import PeakSwift

@Observable
class MachineLearning {
    
    static let shared = MachineLearning()
    
    public var processECG = ProcessEcg.shared
    
    private static var model: ecgVAEC?
    
    public var epochs: Int = 10
    
    public var isPrepareBatch: Bool = false
    public var progressPrepareBatch: Double = 0.0
    
    public var isMachineLearning: Bool = false
    public var progressMachineLearning: Double = 0.0
    
    private static let appDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    private static let defaultModelURL = ecgVAEC.urlOfModelInThisBundle
    public static var updatedModelURL = appDirectory.appendingPathComponent("ecgVaeUpdated.mlmodelc")
    private static var tempUpdatedModelURL = appDirectory.appendingPathComponent("ecgVAECTmp.mlmodelc")
    
    public static var modelURL: URL {
        get {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: updatedModelURL.path) {
                return updatedModelURL
            } else {
                return defaultModelURL
            }
        }
        set {
            updatedModelURL = newValue
        }
    }
    
    static func updateModelURL(to newURL: URL) {
        MachineLearning.modelURL = newURL
    }
    
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
    
    func convertToMLMultiArray(matrix: [[Float32]]) -> MLMultiArray? {
        let numRows = matrix.count
        let numColumns = matrix.first?.count ?? 0
        
        do {
            let multiArray = try MLMultiArray(shape: [numRows as NSNumber, numColumns as NSNumber], dataType: .float32)
            
            for (i, row) in matrix.enumerated() {
                for (j, value) in row.enumerated() {
                    multiArray[[i, j] as [NSNumber]] = NSNumber(value: value)
                }
            }
            return multiArray
        } catch {
            print("Error creating MLMultiArray: \(error)")
            return nil
        }
    }
    
    func convertToFloatMatrix(mlMultiArray: MLMultiArray) -> [[Float32]]? {
        guard mlMultiArray.shape.count == 2 else {
            print("MLMultiArray is not 2D.")
            return nil
        }
        
        let rows = mlMultiArray.shape[0].intValue
        let cols = mlMultiArray.shape[1].intValue
        
        var array: [[Float32]] = []
        
        for i in 0..<rows {
            var row: [Float32] = []
            for j in 0..<cols {
                let index = [i, j] as [NSNumber]
                row.append(Float32(mlMultiArray[index].floatValue))
            }
            array.append(row)
        }
        
        return array
    }
    
    func predict(input: ecgVAECInput) -> ecgVAECOutput? {
        MachineLearning.loadUpdatedModel()
        do {
            guard let model = MachineLearning.model else {
                fatalError("No model available")
            }
            
            let prediction = try model.prediction(input: input)
            return prediction
            
        } catch {
            print(error)
            return nil
        }
    }
    
    static func saveUpdatedModel(_ updateContext: MLUpdateContext) {
        
        let updatedModel = updateContext.model
        let fileManager = FileManager.default
        let tempUpdatedModelURL = MachineLearning.tempUpdatedModelURL
        let updatedModelURL = MachineLearning.updatedModelURL
        do {
            try fileManager.createDirectory(at: tempUpdatedModelURL,
                                            withIntermediateDirectories: true,
                                            attributes: nil)
            try updatedModel.write(to: tempUpdatedModelURL)
            _ = try fileManager.replaceItemAt(updatedModelURL, withItemAt: tempUpdatedModelURL)
            updateModelURL(to: updatedModelURL)
            
            print("Updated model saved to:\n\t\(updatedModelURL)")
        } catch let error {
            print("Could not save updated model to the file system: \(error)")
            return
        }
    }
    
    static func loadUpdatedModel() {
        print(MachineLearning.modelURL)
        guard FileManager.default.fileExists(atPath: MachineLearning.modelURL.path) else {
            return
        }
        guard let model = try? ecgVAEC(contentsOf: MachineLearning.modelURL) else {
            return
        }
        MachineLearning.model = model
    }
    
    // TODO: Might require refactoring for more modularity
    func toFeatureValue(values: [Float32], shapeInput: [NSNumber], shapeOutput: [NSNumber], datatypeInput:  MLMultiArrayDataType, datatypeOutput:  MLMultiArrayDataType) -> [String: MLFeatureValue] {
        // TODO: Layer names should be placed somewhere globally
        let featureName = "x"
        let labelName = "var_22_true"
        do {
            let mlMultiArrayInput = try MLMultiArray(shape: shapeInput, dataType: datatypeInput)
            let mlMultiArrayOutput = try MLMultiArray(shape: shapeOutput, dataType: datatypeOutput)
            
            for k in 0..<values.count {
                let value = NSNumber(value: values[k])
                mlMultiArrayInput[k] = value
                mlMultiArrayOutput[k] = value
            }
            let mlFeatureValueInput = MLFeatureValue(multiArray: mlMultiArrayInput)
            let mlFeatureValueOutput = MLFeatureValue(multiArray: mlMultiArrayOutput)
            
            return [featureName: mlFeatureValueInput, labelName: mlFeatureValueOutput]
        }
        catch {
            print("\(error)")
            return [:]
        }
    }
    
    func snippetToMLBatchProvider(batchDescriptor: FetchDescriptor<EcgSnippet>) async -> MLArrayBatchProvider {
        var batchDataDescriptor = batchDescriptor
        
        do {
            var featureProviders = [MLFeatureProvider]()
            let context = ModelContext(sharedModelContainer)
            let batchSize = 1024
            let totalSnippets = try context.fetchCount(batchDataDescriptor)
            
            for startIndex in stride(from: 0, to: totalSnippets, by: batchSize)  {
                await MainActor.run {
                    progressPrepareBatch = Double(startIndex) / Double(totalSnippets)
                }
                batchDataDescriptor.fetchLimit = batchSize
                batchDataDescriptor.fetchOffset = startIndex
                batchDataDescriptor.propertiesToFetch = [\.values]
                
                let ecgSnippets: [EcgSnippet] = try context.fetch(batchDataDescriptor)
                // The output of the model is currently defined as doubel value. Therefore, we have to set the datatype to double
                let providers: [MLFeatureProvider] = ecgSnippets.compactMap({
                    let dataDictionary = toFeatureValue(values: $0.values, shapeInput: [1,500], shapeOutput: [500], datatypeInput: .float32, datatypeOutput: .double)
                    if let provider = try? MLDictionaryFeatureProvider(dictionary: dataDictionary) {
                        return provider
                    } else {
                        return nil
                    }
                })
                featureProviders.append(contentsOf: providers)
            }
            
            return MLArrayBatchProvider(array: featureProviders)
        } catch {
            print("\(error)")
            return MLArrayBatchProvider(array: [])
        }
    }
    
    func prepareMLBatchProvider(
        batchDataDescriptorTrain: FetchDescriptor<EcgSnippet>,
        batchDataDescriptorTest: FetchDescriptor<EcgSnippet>,
        completion: @escaping ((MLArrayBatchProvider, MLArrayBatchProvider)) -> Void) {
            
            Task {
                await MainActor.run {
                    self.isPrepareBatch = true
                }
                let batchProviderTrain = await snippetToMLBatchProvider(batchDescriptor: batchDataDescriptorTrain)
                let batchProviderTest = await snippetToMLBatchProvider(batchDescriptor: batchDataDescriptorTest)
                await MainActor.run {
                    self.isPrepareBatch = false
                }
                completion((batchProviderTrain, batchProviderTest))
            }
        }
    
    func fineTuneModel(testData: UUID) {
        
        MachineLearning.loadUpdatedModel()
        
        let batchDataDescriptorTrain = FetchDescriptor<EcgSnippet>(predicate: #Predicate { $0.parent != testData })
        let batchDataDescriptorTest = FetchDescriptor<EcgSnippet>(predicate: #Predicate { $0.parent == testData })
        
        print(MachineLearning.modelURL)
        let progressHandler = { (contextProgress: MLUpdateContext) in
            if let epochIndex = contextProgress.metrics[MLMetricKey.epochIndex] as? Int {
                self.progressMachineLearning = Double(epochIndex) / Double(self.epochs)
            }
            switch contextProgress.event {
            case .trainingBegin:
                print("Training began.")
            case .epochEnd:
                let loss = contextProgress.metrics[.lossValue] as! Double
                print("Epoch \(contextProgress.metrics[.epochIndex]!) ended. Training Loss: \(loss)")
            default:
                break
            }
        }
        
        let completionHandler = { (finalContext: MLUpdateContext) in
            print(finalContext)
            self.isMachineLearning = false
            MachineLearning.saveUpdatedModel(finalContext)
            MachineLearning.loadUpdatedModel()
        }
        
        let progressHandlers = MLUpdateProgressHandlers(
            forEvents: [.trainingBegin, .epochEnd],
            progressHandler: progressHandler,
            completionHandler: completionHandler
        )
        
        let configuration = MLModelConfiguration()
        configuration.parameters = [MLParameterKey.epochs: self.epochs, MLParameterKey.eps:0.0001]
        
        self.prepareMLBatchProvider(batchDataDescriptorTrain: batchDataDescriptorTrain, batchDataDescriptorTest: batchDataDescriptorTest) { batchProvider in
            
            let (batchProviderTrain, _) = batchProvider
            
            do {
                self.isMachineLearning = true
                let updateTask = try MLUpdateTask(
                    forModelAt: MachineLearning.modelURL,
                    trainingData: batchProviderTrain,
                    configuration: configuration,
                    progressHandlers: progressHandlers
                )
                updateTask.resume()
            }
            catch {
                self.isMachineLearning = false
                print("Failed \(error)")
            }
        }
    }
}
