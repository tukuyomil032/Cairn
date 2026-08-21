import SwiftUI

@main
struct CairnApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        Text("Cairn")
            .font(.largeTitle)
            .padding()
    }
}
