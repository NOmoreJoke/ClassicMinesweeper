// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ClassicMines",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "GameCore", targets: ["GameCore"]),
        .library(name: "ClassicMinesUI", targets: ["ClassicMinesUI"]),
        .executable(name: "ClassicMines", targets: ["ClassicMinesApp"]),
    ],
    targets: [
        .target(name: "GameCore"),
        .target(
            name: "ClassicMinesUI",
            dependencies: ["GameCore"]
        ),
        .executableTarget(
            name: "ClassicMinesApp",
            dependencies: ["GameCore", "ClassicMinesUI"]
        ),
        .testTarget(
            name: "GameCoreTests",
            dependencies: ["GameCore"]
        ),
        .testTarget(
            name: "ClassicMinesUITests",
            dependencies: ["ClassicMinesUI", "GameCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
