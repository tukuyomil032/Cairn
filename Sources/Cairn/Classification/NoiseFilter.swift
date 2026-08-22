import Foundation

/// リポジトリを「発見」対象に含めるか判定するプロトコル。
/// 将来的に別の判定戦略（例: star数フィルタ）へ差し替えられるようStrategyパターン化する。
protocol NoiseFiltering: Sendable {
    func shouldInclude(repository: Repository, releases: [Release]) -> Bool
}

/// topicsタグの一致（条件A）とインストール可能な資産の存在（条件B）のANDで判定する実装。
/// star数閾値は採用しない（知る人ぞ知る新規アプリの取りこぼしを避けるため）。
struct NoiseFilter: NoiseFiltering {
    let requiredTopicsAny: Set<String>
    let validAssetExtensions: Set<String>

    init(
        requiredTopicsAny: Set<String> = ["macos", "macos-app"],
        // .pkgのみの資産は今回スコープ外（Phase7のInstallerが.pkgに未対応のため）。
        // 将来Installer側が対応したらここに"pkg"を追加する。
        validAssetExtensions: Set<String> = ["dmg", "zip"]
    ) {
        self.requiredTopicsAny = requiredTopicsAny
        self.validAssetExtensions = validAssetExtensions
    }

    func shouldInclude(repository: Repository, releases: [Release]) -> Bool {
        hasRequiredTopic(repository) && hasValidAsset(in: releases)
    }

    private func hasRequiredTopic(_ repository: Repository) -> Bool {
        !requiredTopicsAny.isDisjoint(with: Set(repository.topics.map { $0.lowercased() }))
    }

    private func hasValidAsset(in releases: [Release]) -> Bool {
        releases.contains { release in
            release.assets.contains { asset in
                validAssetExtensions.contains((asset.name as NSString).pathExtension.lowercased())
            }
        }
    }
}
