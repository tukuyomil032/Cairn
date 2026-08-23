import SwiftData
import SwiftUI

/// `swift run`経由の未バンドル実行ファイルとして起動された場合、LaunchServices登録がないため
/// ウィンドウサーバーとのアクティベートにレースが起き、クリックしても一瞬で直前のアプリへ
/// フォーカスが戻ることがある。`applicationDidFinishLaunching`で明示的にアクティベートすることで
/// これを防ぐ（`App.init()`時点ではNSApplicationの初期化が完了していないため、そこでは呼ばない）。
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct CairnApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            DiscoveryView()
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
