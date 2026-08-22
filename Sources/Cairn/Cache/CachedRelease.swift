import Foundation
import SwiftData

@Model
final class CachedRelease {
    var tagName: String
    var assetNames: [String]
    var assetURLs: [String]

    // 元プランのスニペットにはない逆参照。CachedRepository側のdeleteRule: .cascadeを
    // 機能させるため双方向関係として明示的に追加している。
    var repository: CachedRepository?

    init(
        tagName: String,
        assetNames: [String] = [],
        assetURLs: [String] = [],
        repository: CachedRepository? = nil
    ) {
        self.tagName = tagName
        self.assetNames = assetNames
        self.assetURLs = assetURLs
        self.repository = repository
    }
}
