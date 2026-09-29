import Foundation

// =============================================================================
// main.swift — the CLI mode switch, and nothing else · Member 1
//
// Top-level statements are legal ONLY in a file named main.swift; every other
// file in an executable target may contain declarations only. That is the whole
// reason this file exists — and why it's where a code walkthrough starts.
//
//   Models.swift       Member 1   Song, Playlist, PlaybackDelegate, DemoLog
//   StackDemo.swift    Member 2   recursive merge sort + Stack<Song>
//   HeapDemo.swift     Member 3   ARC, the retain cycle, and its fix
//   BufferDemo.swift   Member 4   chunked playback through one reused buffer
//   CompareDemo.swift  Member 5   append vs reserveCapacity, and the tools
//
// All one module (PlaylistStreamer), so these files see each other with no
// imports. The split lets five people work without merge conflicts — each
// member owns one file.
//
//   swift run PlaylistStreamer stack
//   swift run PlaylistStreamer heap
//   swift run PlaylistStreamer buffer
//   swift run -c release PlaylistStreamer compare   <- release, for measurements
//   swift run PlaylistStreamer all
// =============================================================================

// dropFirst() discards argv[0], the executable's own path.
let arguments = CommandLine.arguments.dropFirst()

/// First non-flag argument. Defaulting to "all" means a bare `swift run` still
/// demonstrates the whole assignment.
let mode = arguments.first(where: { !$0.hasPrefix("--") }) ?? "all"

// Each case is one labelled demonstration from the debrief.
switch mode {
case "stack":
    runStackDemo()
case "heap":
    runHeapDemo()
case "buffer":
    runBufferDemo()
case "compare":
    runCompareDemo()
case "all":
    // Demo order: how functions run, then where objects live, then how data
    // moves through memory, then what that costs.
    runStackDemo()
    runHeapDemo()
    runBufferDemo()
    runCompareDemo()
default:
    print("usage: PlaylistStreamer [stack|heap|buffer|compare|all]")
    exit(1)   // non-zero: a mistyped mode is a failure, not a silent no-op
}
