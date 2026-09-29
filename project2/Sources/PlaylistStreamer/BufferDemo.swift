import Foundation

// =============================================================================
// BufferDemo.swift — moving data in chunks · Member 4
//
// Demo section 4 (buffer half). Fill in runBufferDemo(); the stub below is
// scaffolding, not a design. Checklist (teamTask.md):
//
//   [ ] Generate each song's .raw file at startup, sized from Song.byteCount
//       (Playlist.bufferCases() already picks the three sizes that matter)
//   [ ] "Play" each song with InputStream into ONE REUSED 4096-byte [UInt8]
//   [ ] Print per chunk: chunk #, capacity, valid bytes n
//   [ ] Process ONLY buffer[0..<n]; handle n == 0 (end) and n < 0 (error)
//   [ ] Verify: total bytes played == file size, and checksum(played) ==
//       checksum(original)
//   [ ] Explain where the buffer's storage lives (heap), the last partial
//       chunk, and input larger than the buffer
//   [ ] Hand Member 5 the played bytes (or a function producing them)
//
// The shape, for reference:
//
//     var buffer = [UInt8](repeating: 0, count: 4096)          // capacity
//     while true {
//         let n = stream.read(&buffer, maxLength: buffer.count) // valid count
//         if n == 0 { break }                                   // end of song
//         if n < 0 { throw stream.streamError! }                // read error
//         play(buffer[0..<n])                                   // ONLY n bytes
//     }
//
// The bug this demo exists to show: processing `buffer` instead of
// `buffer[0..<n]` on the final chunk replays stale bytes left over from the
// previous chunk. Capacity is how big the bucket is; count is how much is
// actually in it. They are equal on every chunk except the last.
// =============================================================================

func runBufferDemo() {
    DemoLog.begin("BUFFER DEMO")
    DemoLog.say("not implemented yet — Member 4 owns BufferDemo.swift")
}
