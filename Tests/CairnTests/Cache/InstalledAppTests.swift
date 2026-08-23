import Foundation
import SwiftData
import Testing

@testable import Cairn

@MainActor
@Suite(.serialized)
struct InstalledAppTests {
    private func makeEnvironment() -> AppEnvironment {
        AppEnvironment(inMemory: true)
    }

    @Test
    func insertedAppCanBeFetchedBack() throws {
        let environment = makeEnvironment()
        let context = environment.modelContainer.mainContext
        let app = InstalledApp(
            bundleIdentifier: "com.example.App",
            appName: "Example",
            installedVersion: "1.0.0",
            installDate: Date(timeIntervalSince1970: 4000)
        )
        context.insert(app)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<InstalledApp>())

        #expect(fetched.count == 1)
        #expect(fetched.first?.appName == "Example")
    }

    @Test
    func duplicateBundleIdentifierOverwritesExistingRecord() throws {
        // CachedRepositoryTestsと同様、SwiftDataの`.unique`制約はエラーではなく
        // 既存レコードの上書き(upsert)として実機で確認された挙動を期待値とする。
        let environment = makeEnvironment()
        let context = environment.modelContainer.mainContext

        context.insert(
            InstalledApp(
                bundleIdentifier: "com.example.Duplicate",
                appName: "First",
                installedVersion: "1.0.0",
                installDate: Date(timeIntervalSince1970: 1000)
            )
        )
        try context.save()

        context.insert(
            InstalledApp(
                bundleIdentifier: "com.example.Duplicate",
                appName: "Second",
                installedVersion: "2.0.0",
                installDate: Date(timeIntervalSince1970: 2000)
            )
        )
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<InstalledApp>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.appName == "Second")
    }

    @Test
    func fetchDescriptorSortsByInstallDate() throws {
        let environment = makeEnvironment()
        let context = environment.modelContainer.mainContext
        context.insert(
            InstalledApp(
                bundleIdentifier: "com.example.Newer",
                appName: "Newer",
                installedVersion: "1.0.0",
                installDate: Date(timeIntervalSince1970: 2000)
            )
        )
        context.insert(
            InstalledApp(
                bundleIdentifier: "com.example.Older",
                appName: "Older",
                installedVersion: "1.0.0",
                installDate: Date(timeIntervalSince1970: 1000)
            )
        )
        try context.save()

        var descriptor = FetchDescriptor<InstalledApp>()
        descriptor.sortBy = [SortDescriptor(\.installDate, order: .forward)]
        let fetched = try context.fetch(descriptor)

        #expect(fetched.map(\.appName) == ["Older", "Newer"])
    }
}
