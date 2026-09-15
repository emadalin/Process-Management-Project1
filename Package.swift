// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThreadLab",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ThreadLab",
            path: "Sources/ThreadLab"
        )
    ]
)
