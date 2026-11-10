// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "anotherMusic",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "anotherMusic",
            path: "Sources"
        ),
        .testTarget(
            name: "anotherMusicTests",
            dependencies: ["anotherMusic"],
            path: "Tests"
        )
    ]
)
