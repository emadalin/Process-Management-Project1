import Foundation

// =============================================================================
// Models.swift — the shared Song / Playlist shape · Member 1
//
// Every demo builds on these two types, so this file is the one that has to be
// agreed BEFORE Members 2-5 start (teamTask.md, work order step 2). Members 3
// and 4 sign off: Member 3 owns the deinit output and the delegate, Member 4
// owns byteCount.
//
// The choices here are deliberately the ones the demo has to explain:
//
//   Song and Playlist are CLASSES (reference types), not structs. That is what
//   puts them on the heap, gives them identity, lets ARC free them at a moment
//   we can observe with deinit, and makes a retain cycle possible at all. A
//   struct Song would be copied into the array and none of Section 3 would work.
//
//   `[Song]` is therefore an array of REFERENCES. The array is a struct whose
//   element storage is a heap buffer; each element in that buffer is a pointer
//   to a Song object elsewhere on the heap. Two heap allocations, two different
//   lifetimes — that distinction is Section 2's main talking point.
// =============================================================================

// MARK: - Output labelling

/// One labelled print path for the whole program.
///
/// The shared rules in teamTask.md fix four output labels (`STACK DEMO`,
/// `HEAP DEMO`, ...). deinit is the awkward case: an object can be freed in any
/// mode, but `deinit` takes no arguments and can't be told which section is
/// running. So the current label lives here and each demo sets it on entry.
///
/// `nonisolated(unsafe)` is how Swift 6 lets a global stay mutable. It means
/// "the compiler is no longer checking this for data races." That is honest
/// here and only here: this program is single-threaded, unlike Project 1. If
/// anyone adds a thread, this becomes a real race and needs a lock.
enum DemoLog {
    nonisolated(unsafe) static var section = "PLAYLIST"

    static func say(_ message: String) {
        print("\(section): \(message)")
    }

    /// Prints the section banner and sets the label every later line uses.
    static func begin(_ name: String) {
        section = name
        print("\n===== \(name) =====")
    }
}

// MARK: - Playback delegate

/// Playback callbacks, used by Section 3 to build (and then break) a cycle.
///
/// `: AnyObject` constrains this protocol to classes, and that constraint is
/// load-bearing: `weak` needs something reference counted to zero out, so
/// `weak var delegate: PlaybackDelegate?` does not compile without it. Expect
/// to be asked why — the error ("'weak' must not be applied to non-class-bound
/// protocol") is the whole reason this line reads the way it does.
protocol PlaybackDelegate: AnyObject {
    func songDidFinish(_ song: Song)
}

// MARK: - Song

/// One track. Carries no audio: `byteCount` is how many bytes of stand-in
/// sample data the buffer demo streams for it.
final class Song {
    let title: String
    let durationSeconds: Int

    /// Size of this song's `.raw` file, in bytes. Member 4 picks the values
    /// that cover the chunk boundary cases; see `Playlist.bufferCases()`.
    let byteCount: Int

    /// Back-reference to whatever is playing this song.
    ///
    /// `weak` is the fix demonstrated in Section 3: Playlist holds its Songs
    /// strongly, so if a Song held its Playlist strongly too, neither reference
    /// count could ever reach 0 and both would leak. `weak` makes this
    /// direction not count, which breaks the cycle. It is also why this is an
    /// Optional `var` — ARC sets it to nil when the delegate goes away.
    ///
    /// Member 3's LeakySong (HeapDemo.swift) is this class with `weak` removed,
    /// kept separate so the fixed version stays the one everything else uses.
    weak var delegate: PlaybackDelegate?

    init(title: String, durationSeconds: Int, byteCount: Int) {
        self.title = title
        self.durationSeconds = durationSeconds
        self.byteCount = byteCount
    }

    /// Runs when ARC frees this object — i.e. the instant the last STRONG
    /// reference to it goes away. It proves the object was released. It does
    /// NOT prove the process gave memory back to the OS: libmalloc usually
    /// keeps that space to reuse. Say it that precisely in the demo.
    deinit {
        DemoLog.say("deinit Song '\(title)'")
    }
}

// MARK: - Playlist

/// An ordered set of songs, and the delegate they report back to.
final class Playlist: PlaybackDelegate {
    let name: String

    /// Strong references: the playlist is what keeps its songs alive. Clearing
    /// this array (or freeing the Playlist) drops the last strong reference to
    /// each Song, and their deinits fire immediately.
    var songs: [Song]

    init(name: String, songs: [Song] = []) {
        self.name = name
        self.songs = songs
    }

    /// Points every song's delegate at this playlist. Separate from `init`
    /// because Section 3 needs to show the un-wired state first.
    func claimSongs() {
        for song in songs {
            song.delegate = self
        }
    }

    // MARK: PlaybackDelegate

    func songDidFinish(_ song: Song) {
        DemoLog.say("playlist '\(name)' noted that '\(song.title)' finished")
    }

    deinit {
        DemoLog.say("deinit Playlist '\(name)'")
    }
}

// MARK: - Sample data

extension Playlist {

    /// Eight songs for the stack demo. Eight because merge sort on 8 elements
    /// is only ~3 levels deep (log2 8), which fits on one screen of indented
    /// enter/return output. Titles are deliberately NOT in alphabetical order.
    static func sampleEight() -> Playlist {
        Playlist(name: "Road Trip", songs: [
            Song(title: "Meridian",     durationSeconds: 211, byteCount: 10_000),
            Song(title: "Half Light",   durationSeconds: 184, byteCount:  8_192),
            Song(title: "Blue Harbour", durationSeconds: 247, byteCount: 12_500),
            Song(title: "Almanac",      durationSeconds: 163, byteCount:  6_400),
            Song(title: "Ravel",        durationSeconds: 298, byteCount: 14_000),
            Song(title: "Ceiling Fan",  durationSeconds: 176, byteCount:  7_300),
            Song(title: "Dovetail",     durationSeconds: 225, byteCount: 11_100),
            Song(title: "Ash Wednesday", durationSeconds: 192, byteCount: 9_050),
        ])
    }

    /// Three songs whose sizes cover every chunk case against a 4096-byte
    /// buffer (teamTask.md, Member 4). The sizes ARE the test:
    ///
    ///   10,000 -> 4096, 4096, 1808   last chunk partial (the normal case)
    ///    8,192 -> 4096, 4096         exact fit, no partial chunk
    ///      100 -> 100                input smaller than the buffer
    ///
    /// The exact-fit case is the one that catches the classic bug: code that
    /// stops on a short read instead of on `n == 0` looks correct on the first
    /// song and silently truncates this one.
    static func bufferCases() -> Playlist {
        Playlist(name: "Buffer Cases", songs: [
            Song(title: "Normal",    durationSeconds: 60, byteCount: 10_000),
            Song(title: "Exact Fit", durationSeconds: 48, byteCount:  8_192),
            Song(title: "Tiny",      durationSeconds:  1, byteCount:    100),
        ])
    }
}
