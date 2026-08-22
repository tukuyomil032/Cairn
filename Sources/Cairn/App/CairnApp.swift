import SwiftData
import SwiftUI

@main
struct CairnApp: App {
    private let environment = CairnEnvironment()

    var body: some Scene {
        WindowGroup {
            ContentView()
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
