import Foundation
import flwr
import SwiftUI
import CoreML

@Observable
class FederatedLearning {
    static let shared = FederatedLearning()
    public var hostname: String = "192.168.178.99"
    public var port: Int = 8080
    public var mlFlwrClient: MLFlwrClient? = nil
    public var compiledModelURL: URL = MachineLearning.updatedModelURL
    public var modelURL: URL = Bundle.main.url(forResource: "ecgVAEC", withExtension: "mlmodel")!
    
    init() {
    }
    
    func initFederatedLearning(trainingBatchProvider: MLBatchProvider, testBatchProvider: MLBatchProvider) {
        
        do {
            let dataLoader = MLDataLoader(trainBatchProvider: trainingBatchProvider, testBatchProvider: testBatchProvider)
            
            let modelInspect = try MLModelInspect(serializedData: Data(contentsOf: modelURL))
            let layerWrappers = modelInspect.getLayerWrappers()
            mlFlwrClient = MLFlwrClient(layerWrappers: layerWrappers,
                                        dataLoader: dataLoader,
                                        compiledModelUrl: compiledModelURL,
                                        modelUrl: modelURL)
        }
        catch {
            print("\(error)")
        }
    }
    
    func startFederatedLearning() {
        let flwrGRPC = FlwrGRPC(serverHost: hostname, serverPort: port)
        if let mlFlwrClient = mlFlwrClient {
            flwrGRPC.startFlwrGRPC(client: mlFlwrClient) {
                print("Federated learning completed")
            }
        }
        else {
            print("MLFlwrClient not valid.")
            return
        }
    }
}
