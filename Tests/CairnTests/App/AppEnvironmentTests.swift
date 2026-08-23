import Testing

@testable import Cairn

@MainActor
@Suite
struct AppEnvironmentTests {
    @Test
    func inMemoryContainerInitializesWithoutError() {
        let environment = AppEnvironment(inMemory: true)
        let entityNames = environment.modelContainer.schema.entities.map(\.name).sorted()

        #expect(entityNames == ["CachedRelease", "CachedRepository", "InstalledApp"])
    }

    @Test
    func onDiskContainerInitializesWithoutError() {
        // デフォルト引数(inMemory: false)でも生成が失敗しないことのみ確認する。
        // Application Support配下に実ファイルが作られるが、後片付けは行わない。
        _ = AppEnvironment()
    }

    @Test
    func defaultInitBuildsGitHubClientAndAuthenticationState() {
        let environment = AppEnvironment(inMemory: true)

        // 引数を省略した場合でも本番用GitHubClient/AuthenticationStateが生成されること。
        // 実機のKeychainに既存トークンがある場合は`.authenticated`にもなり得るため、
        // 状態値そのものではなく生成が失敗しないことのみを検証する。
        _ = environment.authenticationState.status
        #expect(!(environment.gitHubClient is MockGitHubClient))
    }

    @Test
    func overridesAreUsedWhenProvided() {
        let mockClient = MockGitHubClient()
        let environment = AppEnvironment(inMemory: true, gitHubClient: mockClient)

        #expect(environment.gitHubClient is MockGitHubClient)
    }

    @Test
    func loadsLinguistColors() {
        let environment = AppEnvironment(inMemory: true)

        #expect(environment.linguistColors.hexByLanguage["Swift"] == "#F05138")
    }
}
