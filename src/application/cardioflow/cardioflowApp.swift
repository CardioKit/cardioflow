import SwiftUI
import SwiftData
import BackgroundTasks
import flwr

@main
struct cardioflowApp: App {
    @Environment(\.scenePhase) private var phase
    var sharedModelContainer: ModelContainer = {
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
    
    var body: some Scene {
        WindowGroup {
            TabView {
                HomeView()
                    .tabItem { Label("Home", systemImage: "house") }
                EcgView()
                    .tabItem { Label("ECG", systemImage: "waveform.path.ecg") }
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
            }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: phase) { oldPhase, newPhase in
                    switch newPhase {
                    case .background:
                        scheduleAppSegment()
                        scheduleAppEmbedd()
                    default: break
                    }
                }
        .backgroundTask(.appRefresh("org.digital-medicine.cardioflow.segment")) {
            ProcessEcg.shared.segmentEcg()
        }
        .backgroundTask(.appRefresh("org.digital-medicine.cardioflow.embedd")) {
            ProcessEcg.shared.predictECG()
        }
    }
    
    func scheduleAppSegment() {
        let request = BGAppRefreshTaskRequest(identifier: "org.digital-medicine.cardioflow.segment")
        try? BGTaskScheduler.shared.submit(request)
    }
    
    func scheduleAppEmbedd() {
        let request = BGAppRefreshTaskRequest(identifier: "org.digital-medicine.cardioflow.embedd")
        try? BGTaskScheduler.shared.submit(request)
    }
}
