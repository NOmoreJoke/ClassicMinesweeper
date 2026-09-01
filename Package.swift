// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ClassicMines",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "GameCore", targets: ["GameCore"]),
        .executable(name: "ClassicMines", targets: ["ClassicMinesApp"]),
    ],
    targets: [
        .target(name: "GameCore"),
        .executableTarget(
            name: "ClassicMinesApp",
            dependencies: ["GameCore"]
        ),
        .testTarget(
            name: "GameCoreTests",
            dependencies: ["GameCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

