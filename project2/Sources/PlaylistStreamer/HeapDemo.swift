import Foundation

// =============================================================================
// HeapDemo.swift — ARC, and the one way it can be defeated · Member 3
//
// Demo section 3. Checklist (teamTask.md):
//
//   [x] Show allocation -> use -> drop the last reference -> deinit output
//       (the deinit prints already live on Song/Playlist in Models.swift)
//   [x] LEAKY version: a LeakySong whose `delegate` is STRONG. Set the playlist
//       to nil and show that NO deinit prints. That silence is the evidence.
//   [x] FIXED version: the real Song's `weak var delegate`. Every deinit prints.
//   [ ] Memory Graph Debugger screenshot of the leak (-> Member 5) — manual
//       Xcode step, not code: Debug Navigator -> Debug Memory Graph while
//       `heap` mode is paused right after leakyVersionDemo() runs.
//   [x] Explain ARC, strong / weak / unowned, and why PlaybackDelegate has to
//       be `: AnyObject` for `weak` to compile at all
//   [x] Explain what the deinit output proves (ARC released the object) and
//       what it does NOT prove (that the process's memory number went down —
//       libmalloc usually keeps freed space to reuse)
//
// LeakySong belongs in THIS file, not Models.swift: the shared model is the
// correct one, and the broken copy is a prop for this section.
//
// Watch for: `weak` alone does not make the leak. The cycle needs both
// directions strong. Build the leak deliberately, and use `var` locals set to
// nil (not just scope exit) so the demo controls exactly when release happens.
// =============================================================================

func runHeapDemo() {
    DemoLog.begin("HEAP DEMO")

    allocationLifecycleDemo()
    cascadeDemo()
    leakyVersionDemo()
    fixedVersionDemo()
    explainARC()
}

// MARK: - 1. Allocation -> use -> drop the last reference -> deinit

/// The plain lifecycle: ask the heap for space, use the object through a
/// reference, drop the only strong reference, and watch ARC free it —
/// immediately, not "eventually."
private func allocationLifecycleDemo() {
    DemoLog.say("--- allocation -> use -> drop the last reference ---")

    // ALLOCATION: `Song(...)` asks libmalloc for heap space for one Song and
    // returns a reference to it. `song` itself lives on the stack (it's a
    // local variable of this function) and holds that reference — the Song
    // object itself does not live on the stack.
    var song: Song? = Song(title: "Meridian", durationSeconds: 211, byteCount: 10_000)
    DemoLog.say("allocated '\(song!.title)' (\(song!.byteCount) bytes)")

    // USE: read through the reference. This step does not allocate anything.
    DemoLog.say("using '\(song!.title)': duration \(song!.durationSeconds)s")

    // DROP THE LAST STRONG REFERENCE: `song` is the only variable pointing at
    // this object, so this assignment drops its strong count to 0.
    DemoLog.say("dropping the only reference (song = nil)")
    song = nil
    // The very next line printed is Song's own `deinit` (Models.swift),
    // fired synchronously by ARC the instant the count hit zero.
}

// MARK: - 2. Dropping a Playlist cascades to the Songs it holds

/// A Playlist holds its Songs strongly (`var songs: [Song]`). Freeing the
/// Playlist drops that array, which drops each Song too — one dropped
/// reference, two kinds of object freed.
private func cascadeDemo() {
    DemoLog.say("--- dropping a Playlist cascades to its Songs ---")

    var playlist: Playlist? = Playlist(name: "Road Trip", songs: [
        Song(title: "Half Light", durationSeconds: 184, byteCount: 8_192),
        Song(title: "Ravel", durationSeconds: 298, byteCount: 14_000),
    ])
    // claimSongs() points each Song's `weak var delegate` back at the
    // playlist. Being weak, this does NOT add to the playlist's strong count.
    playlist!.claimSongs()

    DemoLog.say("playlist '\(playlist!.name)' holds \(playlist!.songs.count) songs")
    DemoLog.say("dropping the only outside reference (playlist = nil)")
    playlist = nil
    // Expect, in order: 'deinit Playlist ...' first (the object whose count
    // just hit 0), then 'deinit Song ...' x2 as the Playlist's own `songs`
    // array is torn down after its deinit body finishes — the array held the
    // only OTHER strong reference to each Song.
}

// MARK: - 3. The leak: a strong reference in both directions

/// The broken copy of Song for this section only: identical to Song except
/// the delegate reference is STRONG, which is the entire bug. Compare to
/// `Song.delegate` in Models.swift, which is `weak`. Never used anywhere else
/// in the program — Playlist and every other demo use the real Song.
private final class LeakySong {
    let title: String

    /// STRONG on purpose. This one line is the whole difference from Song.
    var delegate: PlaybackDelegate?

    init(title: String) {
        self.title = title
    }

    deinit {
        DemoLog.say("deinit LeakySong '\(title)'")
    }
}

/// A minimal stand-in for Playlist: holds its songs strongly and acts as
/// their delegate, exactly like the real Playlist does. `songDidFinish` takes
/// a `Song` (not `LeakySong`) only because it exists to satisfy the shared
/// `PlaybackDelegate` protocol — it is never actually called in this demo.
private final class LeakyPlaylist: PlaybackDelegate {
    let name: String
    var songs: [LeakySong]

    init(name: String, songs: [LeakySong]) {
        self.name = name
        self.songs = songs
        for song in songs {
            song.delegate = self   // the second strong arrow — this closes the cycle
        }
    }

    func songDidFinish(_ song: Song) {}

    deinit {
        DemoLog.say("deinit LeakyPlaylist '\(name)'")
    }
}

private func leakyVersionDemo() {
    DemoLog.say("--- LEAKY version: delegate held STRONG, both directions ---")

    var leakyPlaylist: LeakyPlaylist? = LeakyPlaylist(name: "Leaky Mix", songs: [
        LeakySong(title: "Broken Link"),
        LeakySong(title: "Stuck"),
    ])
    DemoLog.say("playlist '\(leakyPlaylist!.name)' holds \(leakyPlaylist!.songs.count) leaky songs")
    DemoLog.say("dropping the only OUTSIDE reference (leakyPlaylist = nil)")
    leakyPlaylist = nil
    // Nothing should print above this comment but the two DemoLog.say lines
    // above. LeakyPlaylist -> songs (strong) and each LeakySong -> delegate
    // (strong) point at each other. Losing the local `leakyPlaylist` variable
    // removes the only reference from OUTSIDE the cycle, but the cycle still
    // holds itself up: LeakyPlaylist's strong count is still 1 (from its
    // songs' delegate pointers) and each LeakySong's is still 1 (from the
    // playlist's array). Neither ever reaches 0, so neither deinit ever runs.
    DemoLog.say("(silence above is the leak — no 'deinit Leaky...' line will ever print)")
}

// MARK: - 4. The fix: same shape, one direction made weak

/// Same cycle shape as the leaky version, but built from the real Song and
/// Playlist — where `Song.delegate` is `weak`. One word is the entire fix.
private func fixedVersionDemo() {
    DemoLog.say("--- FIXED version: same shape, using the real weak Song/Playlist ---")

    var playlist: Playlist? = Playlist(name: "Fixed Mix", songs: [
        Song(title: "Open Link", durationSeconds: 200, byteCount: 9_000),
        Song(title: "Free", durationSeconds: 150, byteCount: 7_000),
    ])
    playlist!.claimSongs()   // identical wiring to the leaky version above
    DemoLog.say("playlist '\(playlist!.name)' holds \(playlist!.songs.count) songs, delegate wired")
    DemoLog.say("dropping the only outside reference (playlist = nil)")
    playlist = nil
    // Expect 'deinit Playlist ...' then 'deinit Song ...' x2, all printing.
    // Song.delegate is weak, so it never counted toward Playlist's reference
    // count — Playlist's count genuinely reached 0 here, same as cascadeDemo().
}

// MARK: - 5. What this proves, and what it doesn't

private func explainARC() {
    DemoLog.say("--- what this demo shows ---")
    DemoLog.say("ARC (Swift runtime + compiler): every class instance carries a strong-reference count. The compiler inserts retain/release calls at every assignment, and the instant that count hits 0, `deinit` runs — immediately, not on a timer or a GC pass.")
    DemoLog.say("strong (default): counts toward the total. weak (Song.delegate): does NOT count, and is automatically set back to nil when the thing it points to is freed — which is why it has to be an Optional var. unowned: also does not count, but assumes the thing it points to always outlives it and crashes if that assumption is wrong — not used here because a delegate can legitimately be freed first.")
    DemoLog.say("PlaybackDelegate is constrained `: AnyObject` because `weak` only means something for reference counting, and only classes are reference-counted. Without that constraint, `weak var delegate: PlaybackDelegate?` fails to compile: 'weak must not be applied to non-class-bound protocol.'")
    DemoLog.say("what the deinit output PROVES: ARC actually released the object. ARC is deterministic, so this moment is exact — not a guess about when a GC pass might run.")
    DemoLog.say("what it does NOT prove: that the process's memory number went down. libmalloc (Apple's allocator) usually keeps freed space around to reuse for the next allocation instead of handing it back to macOS. Section 4's RSS numbers measure THAT layer, not this one — don't conflate the two.")
}
