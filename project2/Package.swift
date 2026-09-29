// swift-tools-version: 6.0
//
// Project 2 — memory management: stacks, heaps, buffers.
//
// Tools version 6.0 turns on the Swift 6 language mode. Unlike Project 1 this
// program is single-threaded, so the concurrency checker mostly stays out of
// the way; the one place it doesn't is DemoLog's mutable section label, which
// Models.swift marks `nonisolated(unsafe)` and explains there.
//
//   swift run PlaylistStreamer all                 (debug)
//   swift run -c release PlaylistStreamer compare  (optimized — use this for measurements)
import PackageDescription

let package = Package(
    name: "PlaylistStreamer",
    platforms: [.macOS(.v13)],
    targets: [
        // One executable target = one module, so every file here sees the
        // others with no imports. Same layout as Project 1's ThreadLab.
        .executableTarget(
            name: "PlaylistStreamer",
            path: "Sources/PlaylistStreamer"
        )
    ]
)
