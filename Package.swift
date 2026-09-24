// swift-tools-version: 6.0
//
// Tools version 6.0 turns on the Swift 6 language mode, where the compiler
// checks concurrency: anything shared across threads must be Sendable. That is
// why our shared classes are marked @unchecked Sendable — an explicit promise
// that we handle thread safety, which unsync mode deliberately breaks.
//
//   swift run ThreadLab all                        (debug)
//   swift run -c release ThreadLab all             (optimized)
//   swift run --sanitize=thread ThreadLab unsync   (ThreadSanitizer)
import PackageDescription

let package = Package(
    name: "ThreadLab",
    platforms: [.macOS(.v13)],
    targets: [
        // One executable target = one module, so every file here sees the
        // others with no imports.
        .executableTarget(
            name: "ThreadLab",
            path: "Sources/ThreadLab"
        )
    ]
)
