// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Mwah",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey.git", from: "0.2.1"),
    ],
    targets: [
        .executableTarget(
            name: "Mwah",
            dependencies: ["HotKey"],
            path: "Sources/Mwah"
        ),
    ]
)
