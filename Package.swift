// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Mwah",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey.git", from: "0.2.1"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "Mwah",
            dependencies: [
                "HotKey",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/Mwah"
        ),
    ]
)
