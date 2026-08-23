import SwiftData
import SwiftUI

@main
struct CairnApp: App {
    private let environment = CairnEnvironment()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // CairnEnvironment自体の本格的なDI拡張（GitHubClient/AuthenticationState等の保持）は
                    // Phase5で行う。Phase4時点ではここで都度生成し、起動時1回だけ軽量更新を実行する。
                    let scheduler = CacheRefreshScheduler(
                        gitHubClient: GitHubClient(),
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
