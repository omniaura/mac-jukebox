// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacJukebox",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "jukebox", targets: ["Jukebox"])
    ],
    targets: [
        .executableTarget(
            name: "Jukebox",
            path: "Sources/Jukebox",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "JukeboxTests",
            dependencies: ["Jukebox"],
            path: "Tests/JukeboxTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
