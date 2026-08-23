import Defaults
import Foundation
import SwiftData
import Testing

@testable import Cairn

@MainActor
@Suite(.serialized)
struct DiscoveryViewModelTests {
    // AppEnvironmentを戻り値のModelContextだけでなくインスタンスごと保持し続けないと、
    // スコープを抜けた時点でModelContainerが解放されクラッシュするため、
    // 各テストで環境そのものをローカル変数に束縛する（CachedRepositoryTestsと同様のパターン）。
    private func makeEnvironment() -> AppEnvironment {
        AppEnvironment(inMemory: true)
    }

    private func withLastTopCategory<T>(_ category: Cairn.Category?, _ body: () throws -> T) rethrows -> T {
        let original = Defaults[.lastTopCategory]
        Defaults[.lastTopCategory] = category
        defer { Defaults[.lastTopCategory] = original }
        return try body()
    }

    private func makeRepository(githubId: Int, category: Cairn.Category, fullName: String? = nil) -> CachedRepository {
        CachedRepository(
            githubId: githubId,
            fullName: fullName ?? "owner/app\(githubId)",
            starCount: 0,
            primaryLanguage: "Swift",
            htmlURL: "https://github.com/owner/app\(githubId)",
            category: category.rawValue,
            lastFetchedAt: Date(timeIntervalSince1970: 1000)
        )
    }

    @Test("カテゴリ選択でリポジトリがフィルタされる")
    func filtersByCategorySelection() throws {
        try withLastTopCategory(nil) {
            let environment = makeEnvironment()
            let context = environment.modelContainer.mainContext
            context.insert(makeRepository(githubId: 1, category: .productivity))
            context.insert(makeRepository(githubId: 2, category: .utilities))
            context.insert(makeRepository(githubId: 3, category: .utilities))
            try context.save()

            let viewModel = DiscoveryViewModel(modelContext: context, initialCategory: nil)
            #expect(viewModel.repositoriesByCategory.count == 3)

            viewModel.selectedCategory = .utilities
            #expect(viewModel.repositoriesByCategory.count == 2)
            #expect(viewModel.repositoriesByCategory.allSatisfy { $0.category == Cairn.Category.utilities.rawValue })
        }
    }

    @Test("categoryCountsがカテゴリごとの件数を正しく返す")
    func computesCategoryCounts() throws {
        try withLastTopCategory(nil) {
            let environment = makeEnvironment()
            let context = environment.modelContainer.mainContext
            context.insert(makeRepository(githubId: 1, category: .productivity))
            context.insert(makeRepository(githubId: 2, category: .utilities))
            context.insert(makeRepository(githubId: 3, category: .utilities))
            try context.save()

            let viewModel = DiscoveryViewModel(modelContext: context, initialCategory: nil)

            #expect(viewModel.categoryCounts[.productivity] == 1)
            #expect(viewModel.categoryCounts[.utilities] == 2)
            #expect(viewModel.categoryCounts[.games] == nil)
        }
    }

    @Test("具体カテゴリを選択するとlastTopCategoryへ書き込まれる")
    func selectingCategoryWritesLastTopCategory() throws {
        try withLastTopCategory(nil) {
            let environment = makeEnvironment()
            let context = environment.modelContainer.mainContext
            let viewModel = DiscoveryViewModel(modelContext: context, initialCategory: nil)

            viewModel.selectedCategory = .music
            #expect(Defaults[.lastTopCategory] == .music)
        }
    }

    @Test("すべて(nil)を選択してもlastTopCategoryは変更されない")
    func selectingAllDoesNotOverwriteLastTopCategory() throws {
        try withLastTopCategory(.developerTools) {
            let environment = makeEnvironment()
            let context = environment.modelContainer.mainContext
            let viewModel = DiscoveryViewModel(modelContext: context, initialCategory: .developerTools)

            viewModel.selectedCategory = nil
            #expect(Defaults[.lastTopCategory] == .developerTools)
        }
    }
}
