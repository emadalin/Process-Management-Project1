import Foundation

// =============================================================================
// BufferDemo.swift — moving data in chunks · Member 4
//
// Demo section 4 (buffer half). Each song is written to a real .raw file, then
// "played" by reading it through ONE reused 4096-byte buffer. Checklist
// (teamTask.md):
//
//   [x] Generate each song's .raw file at startup, sized from Song.byteCount
//   [x] "Play" each song with InputStream into ONE REUSED 4096-byte [UInt8]
//   [x] Print per chunk: chunk #, capacity, valid bytes n
//   [x] Process ONLY buffer[0..<n]; handle n == 0 (end) and n < 0 (error)
//   [x] Verify: total bytes played == file size, and checksum(played) ==
//       checksum(original)
//   [x] Explain where the buffer's storage lives, the last partial chunk, and
//       input larger than the buffer
//   [x] Hand Member 5 the played bytes: playSong(_:bufferCapacity:onChunk:)
//
// Who does what here (shared rules):
//
//   OUR CODE    picks the capacity (4096), allocates the buffer once, and
//               decides that only buffer[0..<n] is valid
//   SWIFT       [UInt8] is a struct whose element storage is a heap
//               allocation; copy-on-write means that storage is not copied as
//               long as the buffer has one owner, so each read reuses it
//   LIBMALLOC   hands out that 4096-byte heap block, once
//   MACOS       the kernel copies file bytes into our buffer on each read(2)
//               and decides how many bytes a read returns
//
// The bug this demo exists to show: processing `buffer` instead of
// `buffer[0..<n]` on the final chunk replays stale bytes left over from the
// previous chunk. Capacity is how big the bucket is; count is how much is
// actually in it. They are equal on every chunk except the last.
// =============================================================================

/// 4 KB: the size the debrief suggests, and a common filesystem block size.
/// Small enough that every test song needs more than one chunk except Tiny.
let bufferDemoCapacity = 4096

// MARK: - Song files

/// Where the generated .raw files go. The temp directory, because these are
/// fixtures the program rebuilds on every run, not project files.
let songDirectory = FileManager.default.temporaryDirectory
    .appendingPathComponent("PlaylistStreamer", isDirectory: true)

func songFileURL(for song: Song) -> URL {
    songDirectory.appendingPathComponent(
        song.title.replacingOccurrences(of: " ", with: "-") + ".raw")
}

/// Deterministic stand-in "audio" for a song: byte i depends on i and the
/// title, so every song has different contents and the pattern repeats every
/// 251 bytes. 251 is prime and doesn't divide 4096, so a chunk's leftover
/// stale bytes never happen to equal the bytes that should be there — the
/// buffer bug shows up as a checksum mismatch instead of hiding.
func songBytes(for song: Song) -> [UInt8] {
    let seed = song.title.utf8.reduce(0) { ($0 &* 31 &+ Int($1)) & 0xFFFF }
    return (0..<song.byteCount).map { UInt8((($0 &* 7) &+ seed) % 251) }
}

/// Writes the song's .raw file and returns the checksum of what was written,
/// which is the "original" that playback is checked against.
@discardableResult
func writeSongFile(for song: Song) throws -> UInt64 {
    try FileManager.default.createDirectory(
        at: songDirectory, withIntermediateDirectories: true)
    let bytes = songBytes(for: song)
    try Data(bytes).write(to: songFileURL(for: song))
    var checksum = Checksum()
    checksum.add(bytes[...])
    return checksum.value
}

// MARK: - Checksum

/// FNV-1a, 64-bit. Order-sensitive, so a replayed or reordered chunk changes
/// it, and it runs incrementally: feeding chunk by chunk gives the same value
/// as feeding the whole file at once.
///
/// That incremental property is how this demo handles data split across a
/// chunk boundary. The checksum's state lives in this struct, OUTSIDE the
/// buffer, so it survives the buffer being overwritten. Anything that needs to
/// see across a boundary (a word cut in half, a 2-byte sample split 1 + 1) has
/// to carry its state the same way — the buffer itself forgets everything on
/// the next read.
struct Checksum {
    private(set) var value: UInt64 = 0xcbf2_9ce4_8422_2325

    mutating func add(_ bytes: ArraySlice<UInt8>) {
        for byte in bytes {
            value ^= UInt64(byte)
            value = value &* 0x100_0000_01b3
        }
    }
}

// MARK: - Playback

enum PlaybackError: Error, CustomStringConvertible {
    case cannotOpen(URL)
    case readFailed(chunk: Int, underlying: Error?)

    var description: String {
        switch self {
        case .cannotOpen(let url):
            return "could not open \(url.lastPathComponent)"
        case .readFailed(let chunk, let underlying):
            return "read failed on chunk \(chunk): "
                + (underlying.map { "\($0.localizedDescription)" } ?? "no error given")
        }
    }
}

struct PlaybackResult {
    let chunks: Int
    let totalBytes: Int
    let checksum: UInt64
    /// Address of the buffer's element storage, read at every chunk. One value
    /// means one allocation was reused for the whole song.
    let bufferAddresses: Set<UInt>
}

/// Streams a song's .raw file through one reused buffer and hands each chunk's
/// VALID bytes to `onChunk`.
///
/// This is the function Member 5 uses to get the played bytes for the
/// comparison: convert each byte in the slice to a Float sample there. The
/// slice is only valid during the call — the next read overwrites it — so copy
/// out what you need, don't keep the slice.
///
/// `onChunk` gets (chunk number, the valid bytes, the buffer's full capacity).
@discardableResult
func playSong(
    _ song: Song,
    bufferCapacity: Int = bufferDemoCapacity,
    onChunk: (Int, ArraySlice<UInt8>, Int) -> Void = { _, _, _ in }
) throws -> PlaybackResult {
    let url = songFileURL(for: song)
    guard let stream = InputStream(url: url) else {
        throw PlaybackError.cannotOpen(url)
    }
    stream.open()
    defer { stream.close() }

    // THE buffer. Allocated once, before the loop: the Array struct (pointer,
    // count, capacity) is a local, but its 4096 elements are one heap block
    // from libmalloc. Every read below writes into that same block. Allocating
    // inside the loop would also work, but costs one malloc/free per chunk.
    var buffer = [UInt8](repeating: 0, count: bufferCapacity)

    var chunk = 0
    var total = 0
    var checksum = Checksum()
    var addresses = Set<UInt>()

    while true {
        // n is how many bytes the read actually put in the buffer. The OS
        // decides it: up to maxLength, fewer at the end of the file, 0 at the
        // end, -1 on error. Never assume n == buffer.count.
        let n = stream.read(&buffer, maxLength: buffer.count)

        if n == 0 { break }       // end of song — the only way the loop ends normally
        if n < 0 {
            throw PlaybackError.readFailed(chunk: chunk + 1, underlying: stream.streamError)
        }

        chunk += 1
        total += n
        addresses.insert(buffer.withUnsafeBufferPointer { UInt(bitPattern: $0.baseAddress) })

        // ONLY the valid bytes. On a partial chunk, buffer[n...] still holds
        // bytes from the previous chunk — real data, just not THIS data.
        let valid = buffer[0..<n]
        checksum.add(valid)
        onChunk(chunk, valid, buffer.count)
    }

    return PlaybackResult(chunks: chunk, totalBytes: total,
                          checksum: checksum.value, bufferAddresses: addresses)
}

/// The bug, on purpose: identical to playSong except it processes the whole
/// buffer every time. Kept separate so the correct version stays the one
/// anybody calls. Only used to show what the mismatch looks like.
private func playSongBuggy(_ song: Song) throws -> PlaybackResult {
    guard let stream = InputStream(url: songFileURL(for: song)) else {
        throw PlaybackError.cannotOpen(songFileURL(for: song))
    }
    stream.open()
    defer { stream.close() }

    var buffer = [UInt8](repeating: 0, count: bufferDemoCapacity)
    var chunk = 0, total = 0
    var checksum = Checksum()
    while true {
        let n = stream.read(&buffer, maxLength: buffer.count)
        if n <= 0 { break }
        chunk += 1
        total += buffer.count             // BUG: should be n
        checksum.add(buffer[...])          // BUG: should be buffer[0..<n]
    }
    return PlaybackResult(chunks: chunk, totalBytes: total,
                          checksum: checksum.value, bufferAddresses: [])
}

// MARK: - Demo

func runBufferDemo() {
    DemoLog.begin("BUFFER DEMO")

    let playlist = Playlist.bufferCases()
    DemoLog.say("one reused buffer, capacity \(bufferDemoCapacity) bytes")
    DemoLog.say("song files in \(songDirectory.path)")

    // 1. The three boundary cases: partial last chunk, exact fit, smaller than
    //    the buffer. Each must play exactly its file size, and its checksum
    //    must match the file's.
    var allPassed = true
    for song in playlist.songs {
        do {
            let original = try writeSongFile(for: song)
            DemoLog.say("")
            DemoLog.say("▶ '\(song.title)' — file is \(song.byteCount) bytes")

            let result = try playSong(song) { chunk, valid, capacity in
                let n = valid.count
                var line = "  chunk \(chunk): capacity \(capacity), valid n = \(n)"
                if n < capacity {
                    line += "  ← partial: buffer[\(n)..<\(capacity)] is \(capacity - n) stale/unused bytes, not played"
                }
                DemoLog.say(line)
            }
            DemoLog.say("  read returned 0 → end of song")

            let sizeOK = result.totalBytes == song.byteCount
            let sumOK = result.checksum == original
            allPassed = allPassed && sizeOK && sumOK
            DemoLog.say("  played \(result.totalBytes) / \(song.byteCount) bytes in \(result.chunks) chunk(s) "
                + (sizeOK ? "✓" : "✗ MISMATCH"))
            DemoLog.say("  checksum played \(hex(result.checksum)) vs original \(hex(original)) "
                + (sumOK ? "✓" : "✗ MISMATCH"))
            DemoLog.say("  buffer storage address across chunks: "
                + result.bufferAddresses.map { hex(UInt64($0)) }.joined(separator: ", ")
                + (result.bufferAddresses.count == 1 ? "  (one allocation, reused)" : ""))
        } catch {
            allPassed = false
            DemoLog.say("  ✗ \(error)")
        }
    }

    // 2. The bug: process `buffer` instead of `buffer[0..<n]`. It breaks every
    //    song with a partial chunk: Normal replays 2,288 stale bytes from chunk
    //    2, Tiny plays 3,996 never-written zeros. Exact Fit has no partial
    //    chunk, so the bug passes there — which is why one size isn't a test.
    DemoLog.say("")
    DemoLog.say("── what if we played the whole buffer instead of buffer[0..<n]? ──")
    for song in playlist.songs {
        do {
            let good = try playSong(song)
            let bad = try playSongBuggy(song)
            let same = good.checksum == bad.checksum
            DemoLog.say("  '\(song.title)': buggy version played \(bad.totalBytes) bytes (real: \(song.byteCount)), checksum "
                + (same ? "matches — this size hides the bug" : "WRONG"))
        } catch {
            DemoLog.say("  ✗ \(error)")
        }
    }

    // 3. The error path, n < 0. A file deleted out from under us: the stream
    //    object is created fine, but the OS refuses the open and read reports -1.
    DemoLog.say("")
    DemoLog.say("── error case: song file missing ──")
    let missing = Song(title: "Missing Track", durationSeconds: 0, byteCount: 500)
    try? FileManager.default.removeItem(at: songFileURL(for: missing))
    do {
        try playSong(missing)
        DemoLog.say("  ✗ expected a read error, got none")
    } catch {
        DemoLog.say("  caught: \(error) — handled, not treated as end of song")
    }

    DemoLog.say("")
    DemoLog.say(allPassed
        ? "all boundary cases: bytes played == file size, checksums match (measured)"
        : "✗ at least one boundary case FAILED — see above")
}

private func hex(_ value: UInt64) -> String {
    "0x" + String(value, radix: 16)
}
