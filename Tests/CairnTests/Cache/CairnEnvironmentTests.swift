import Testing

@testable import Cairn

@MainActor
@Suite
struct CairnEnvironmentTests {
    @Test
    func inMemoryContainerInitializesWithoutError() {
        let environment = CairnEnvironment(inMemory: true)
        let entityNames = environment.modelContainer.schema.entities.map(\.name).sorted()

        #expect(entityNames == ["CachedRelease", "CachedRepository", "InstalledApp"])
    }

    @Test
    func onDiskContainerInitializesWithoutError() {
        // デフォルト引数(inMemory: false)でも生成が失敗しないことのみ確認する。
        // Application Support配下に実ファイルが作られるが、後片付けは行わない。
        _ = CairnEnvironment()
    }
}
