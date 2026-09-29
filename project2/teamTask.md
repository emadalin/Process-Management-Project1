# Project 2 Team Tasks: Music Playlist Streamer

**Language / OS:** Swift on macOS  **Due:** Thursday, Oct 15, 11:59 pm  **Demo:** 30 min
**Package name:** `PlaylistStreamer`  **Reference:** `projectDebrief.md`

Roles are assigned (see the table in `projectDebrief.md` section 9). Everyone explains at least one demo section they **did not** write.

---

## Shared rules (everyone)
- Output labels: `STACK DEMO`, `HEAP DEMO`, `BUFFER DEMO`, `MEMORY COMPARISON`
- Comments explain *memory decisions*, not obvious lines
- Never say "the system handles memory." Name who does it: our code, Swift runtime/ARC, libmalloc, or macOS
- Label every claim as **measured** or **inferred**
- Commit your own files only; talk before editing someone else's
- Each person writes 3–5 sentences for the contribution statement

---

## Member 1: Memory Model, Setup & Shared Models · `Sarah Rae`
Owns demo sections **1 (language & memory model)** and **7 (pros/cons/limitations)**, plus setup.

- [ ] Create the Swift package: `Package.swift`, `Sources/PlaylistStreamer/`, `.gitignore`
- [ ] `main.swift` with the mode switch: `stack | heap | buffer | compare | all`, each calling a stub function the owner fills in
- [ ] Write the shared models in `Models.swift`: `Song` (title, duration, byte count), `Playlist`, `PlaybackDelegate: AnyObject`. **Get Members 3 and 4 to agree on the shape before anyone else codes**
- [ ] Confirm `swift build` and `swift run PlaylistStreamer all` work on all five Macs
- [ ] Notes: who does what (our code / ARC + runtime / libmalloc / macOS), value vs reference types, ARC vs garbage collection
- [ ] Pros/cons/limitations section + one improvement with more time
- [ ] Record everyone's setup: `sw_vers`, `uname -m`, `swift --version`, Xcode version
- [ ] Own the README (build/run instructions, how to run each mode) and the team contribution statement
- [ ] Collect the sources list from everyone
- [ ] Schedule the rehearsal

## Member 2: Stack Demo · `Ella`
Owns demo section **2**. File: `StackDemo.swift`

- [ ] Recursive merge sort of the playlist (by title or duration), 8 songs
- [ ] Indented enter/return output with depth, e.g. `→ mergeSort depth 2 [songs 2...3]` / `← return depth 2`
- [ ] Print `Thread.callStackSymbols` at the deepest call
- [ ] Xcode breakpoint screenshot of the call-stack view at the deepest call (hand to Member 5)
- [ ] Small `Stack<Song>` struct ("recently played" history) to contrast with the call stack
- [ ] Explain: call stack vs `Stack<Song>`; the `[Song]` parameter vs the heap buffer behind it vs each `Song` reference; scope vs lifetime
- [ ] Explain the deep-recursion risk (a one-level-per-song recursive shuffle; no recursion limit in Swift; 8 MB main / 512 KB secondary thread stacks). Do **not** crash it
- [ ] Sample output + short "what this shows" for the README

## Member 3: Heap Demo · `Stephen`
Owns demo section **3**. File: `HeapDemo.swift`

- [ ] `deinit` prints on `Song` and `Playlist` (in the shared models, coordinated with Member 1)
- [ ] Show allocation → use → drop the reference → deinit output
- [ ] **Leaky version:** `LeakySong` with a strong `delegate` back to the playlist; set the playlist to `nil` and show **no** deinit prints
- [ ] **Fixed version:** `weak var delegate`; show all deinits print
- [ ] Explain ARC, strong/weak/unowned, why the protocol needs `AnyObject`
- [ ] Explain what deinit output proves (ARC released the object) and doesn't prove (process memory went down)
- [ ] Sample output + short "what this shows" for the README

## Member 4: Buffer Demo · `Calli`
Owns demo section **4 (buffer part)**. File: `BufferDemo.swift`

- [ ] Generate song files (`.raw`) at startup, or a small script that does. Sizes: **10,000 bytes**, **8,192 bytes**, **100 bytes**
- [ ] "Play" each song with `InputStream` into **one reused** 4096-byte `[UInt8]` buffer
- [ ] Print per chunk: chunk #, capacity, valid bytes `n`
- [ ] Only process `buffer[0..<n]`; handle `n == 0` (end) and `n < 0` (error)
- [ ] Verify: total bytes played == file size, and checksum played == checksum original
- [ ] Explain where the buffer's storage lives (heap), and what happens on the last partial chunk and when input > buffer
- [ ] Sample output with all three boundary cases + "what this shows"
- [ ] Help Member 5 with the comparison input (hand over the played bytes / a function that produces them)

## Member 5: Comparison & IDE Tools · `Georgia`
Owns demo sections **4 (comparison part)** and **5 (IDE tools)**. File: `CompareDemo.swift`

- [ ] **A:** build `samples: [Float]` by appending one at a time
- [ ] **B:** same task with `reserveCapacity(total)` first
- [ ] Verify `samplesA == samplesB`
- [ ] Log every capacity change in A (reallocation count); print final capacity vs count for both
- [ ] Run with a large input (5–50 million samples), `swift run -c release`, **5 runs each**, record the numbers
- [ ] Instruments → Allocations on A and B (total bytes, # of allocations), with screenshots
- [ ] Memory Graph Debugger screenshot of the heap leak (from Member 3's leaky mode)
- [ ] Collect Member 2's call-stack screenshot
- [ ] Write-up: Xcode version, built-in vs separate tool (Instruments), what each shows, what each can't establish
- [ ] Measured vs inferred table for the comparison
- [ ] Optional: `/usr/bin/time -l` max RSS, explaining how it differs from object sizes

---

## Work order
1. **Member 1** sets up the package and pushes it (day 1)
2. **Members 1, 3, 4** agree on the `Song` / `Playlist` / `PlaybackDelegate` shape; Member 1 commits `Models.swift`
3. **Members 2, 3, 4** build their demos in parallel
4. **Member 5** builds the comparison once Member 4's playback function exists (can start with fake bytes before that)
5. **Member 5** runs the tools and takes screenshots once Members 2 and 3 are done
6. Everyone adds sample output + explanations to the README
7. **Member 1** finishes the README, sources, and contribution statement
8. **Rehearsal:** each person explains a section they didn't write, then goes through the practice questions in the debrief

## Suggested demo timing (30 min)
| Section | Presenter | Time |
|---|---|---|
| 1. Language & memory model | Sarah Rae | 3 min |
| 2. Stack demo | Ella | 4 min |
| 3. Heap demo | Stephen | 5 min |
| 4. Buffer + comparison | Calli (buffer) + Georgia (comparison) | 6 min |
| 5. IDE tools | Georgia | 4 min |
| 6. Code walkthrough | Everyone — own file, ~45 s each | 4 min |
| 7. Pros, cons, limitations | Sarah Rae | 2 min |
| Questions | Everyone | 2 min |