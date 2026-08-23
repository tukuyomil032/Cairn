import SwiftData
import SwiftUI

@main
struct CairnApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(environment)
                .task {
                    let scheduler = CacheRefreshScheduler(
                        gitHubClient: environment.gitHubClient,
                        modelContext: environment.modelContainer.mainContext
                    )
                    await scheduler.refreshTopCategoryOnLaunch()
                }
        }
        .modelContainer(environment.modelContainer)
    }
}

struct ContentView: View {
    var body: some View {
        Text("Cairn")
            .font(.largeTitle)
            .padding()
    }
}
