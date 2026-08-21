// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Cairn",
    defaultLocalization: "ja",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "Cairn", targets: ["Cairn"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation", from: "0.9.19"),
        .package(url: "https://github.com/sindresorhus/Defaults", from: "9.0.0"),
        // ライセンス未確認（LICENSEファイルなし、GitHub API上でも licenseInfo が空）。
        // 実装着手前に作者(zats)へ確認すること。docs/dependencies.md 参照。
        .package(url: "https://github.com/zats/permiso", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "Cairn",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
                .product(name: "Defaults", package: "Defaults"),
                .product(name: "Permiso", package: "permiso")
            ],
            path: "Sources/Cairn",
            exclude: [
                "Resources/Info.plist",
                "Resources/Cairn.entitlements"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "CairnTests",
            dependencies: ["Cairn"],
            path: "Tests/CairnTests"
        )
    ]
)
