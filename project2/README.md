# PlaylistStreamer: Process Management Project 2

Memory management in Swift on macOS — **stacks, heaps and buffers** — demonstrated by a
program that simulates streaming audio. No sound is played: each "song" is a file of raw
bytes, which is what makes the memory behaviour easy to watch.

> **Status:** stack, heap and buffer demos implemented; the memory comparison and the IDE
> tools investigation are outstanding. Sections marked _TODO_ are owned by the member named
> beside them; see [`teamTask.md`](teamTask.md).

## What the program demonstrates

| Mode | Idea | What you see | Owner |
|---|---|---|---|
| `stack` | The call stack | Recursive merge sort of the playlist, with indented enter/return output and a real `Thread.callStackSymbols` dump at the deepest call | Ella |
| `heap` | ARC and object lifetime | `Song`/`Playlist` allocation, use and `deinit` — then a retain cycle that stops `deinit` firing, and the `weak` fix that restores it | Stephen |
| `buffer` | Moving data in chunks | Each song "played" through one reused 4096-byte buffer, with capacity vs. valid count, every chunk boundary case, and checksums proving nothing was lost | Calli |
| `compare` | What it costs | The same array built two ways — `append` alone vs. `reserveCapacity` first — with reallocation counts and Instruments measurements | Georgia |

The one-sentence version: **the stack tracks which functions are running, the heap holds data
that outlives a single function, and a buffer is a chunk of memory used to move data in pieces.**

How the four layers divide the work — our code, ARC, libmalloc and the macOS kernel — is written
up in [`docs/section1-memory-model.md`](docs/section1-memory-model.md).

---

## Requirements

- macOS 13 or later
- Swift 6.0 or later (Xcode 16+ or the Command Line Tools)
- Xcode (any recent version) for the Instruments and Memory Graph sections

```bash
xcode-select --install   # only if `swift` isn't found
swift --version
```

## Build & run

```bash
swift run PlaylistStreamer all        # every mode, in demo order
swift run PlaylistStreamer stack      # one mode: stack | heap | buffer | compare
```

**Measurements must use a release build.** A debug build leaves the optimiser off, so
allocation and timing numbers from it say nothing about the real cost:

```bash
swift run -c release PlaylistStreamer compare
```

**Save output for submission:**
```bash
swift run PlaylistStreamer buffer | tee output-buffer-run1.txt
swift run -c release PlaylistStreamer compare | tee output-compare-run1.txt
```

The buffer demo generates its song files under the system temporary directory and prints the
path. They are small (about 18 KB in total), are regenerated on every run, and are not checked
in. They are left in place after the run, which is handy for inspecting them with `xxd` during
the demo; macOS clears that directory itself.

---

## Project layout

```
Package.swift                      swift-tools-version 6.0 (Swift 6 language mode)
Sources/PlaylistStreamer/
  main.swift                       mode switch, and nothing else          (Sarah Rae)
  Models.swift                     Song, Playlist, PlaybackDelegate, DemoLog, sample data (Sarah Rae)
  StackDemo.swift                  merge sort, callStackSymbols, Stack<Song>   (Ella)
  HeapDemo.swift                   ARC, the retain cycle and its fix           (Stephen)
  BufferDemo.swift                 chunked playback through one reused buffer  (Calli)
  CompareDemo.swift                append vs. reserveCapacity, Instruments     (Georgia)
docs/
  section1-memory-model.md         who owns what, stack vs heap, value vs reference, ARC vs GC
  section7-pros-cons-limitations.md  what the approach buys, costs, and cannot show
  practice-questions.md            team answer sheet — rehearsal runs on this
  submission-checklist.md          Canvas deliverables vs. what is actually in the repo
  machine-details.md               every team Mac's OS, chip, RAM, page size, toolchain
verify.sh                          one command: builds, runs every mode, prints your machine row
output-stack-run1.txt              saved runs, one per mode
output-heap-run1.txt
output-buffer-run1.txt
projectDebrief.md                  scope, concepts, checklists, practice questions
teamTask.md                        per-member task list and demo timing
```

All source files are one module, so they see each other with no imports. The split is by
owner: five people, five files, no merge conflicts.

### The shared models

`Song` and `Playlist` are **classes, not structs**. That is the decision everything else rests
on: it puts them on the heap, gives them identity, lets ARC free them at a moment we can
observe with `deinit`, and makes a retain cycle possible at all. `PlaybackDelegate` is
constrained to `: AnyObject` because `weak` does not compile otherwise.

So `[Song]` is an array of *references*: the array is a struct whose element storage is a heap
buffer, and each element in that buffer points to a `Song` object elsewhere on the heap. Two
allocations, two lifetimes — the distinction the stack demo turns on.

---

## Machine details

Every captured number must record macOS version, chip, RAM, Swift version, and debug vs.
release. See [`docs/machine-details.md`](docs/machine-details.md).

**All comparison measurements must come from one machine.** Array growth is a standard-library
implementation detail that can differ between Swift versions, and the team's toolchains are not
identical — numbers from two different Macs are not a comparison.

---

## Sample output

One labelled block per mode, each with a short "what this shows". Saved runs are committed
beside this file as `output-<mode>-run1.txt`. All captured on Sarah's M2 (see
[`docs/machine-details.md`](docs/machine-details.md)); the comparison numbers, when they land,
must all come from a single machine.

### Buffer demo
Run: `swift run PlaylistStreamer buffer` (saved as
[`output-buffer-run1.txt`](output-buffer-run1.txt), Sarah's M2).

```
===== BUFFER DEMO =====
BUFFER DEMO: one reused buffer, capacity 4096 bytes
BUFFER DEMO: song files in /var/folders/qx/2_r_w58s5x53q9201lvp0s3r0000gn/T/PlaylistStreamer
BUFFER DEMO: 
BUFFER DEMO: ▶ 'Normal' — file is 10000 bytes
BUFFER DEMO:   chunk 1: capacity 4096, valid n = 4096
BUFFER DEMO:   chunk 2: capacity 4096, valid n = 4096
BUFFER DEMO:   chunk 3: capacity 4096, valid n = 1808  ← partial: buffer[1808..<4096] is 2288 stale/unused bytes, not played
BUFFER DEMO:   read returned 0 → end of song
BUFFER DEMO:   played 10000 / 10000 bytes in 3 chunk(s) ✓
BUFFER DEMO:   checksum played 0xa34dce5867b20521 vs original 0xa34dce5867b20521 ✓
BUFFER DEMO:   buffer storage address across chunks: 0x12381a820  (one allocation, reused)
BUFFER DEMO: 
BUFFER DEMO: ▶ 'Exact Fit' — file is 8192 bytes
BUFFER DEMO:   chunk 1: capacity 4096, valid n = 4096
BUFFER DEMO:   chunk 2: capacity 4096, valid n = 4096
BUFFER DEMO:   read returned 0 → end of song
BUFFER DEMO:   played 8192 / 8192 bytes in 2 chunk(s) ✓
BUFFER DEMO:   checksum played 0x9da4b2bab9d9edd1 vs original 0x9da4b2bab9d9edd1 ✓
BUFFER DEMO:   buffer storage address across chunks: 0x12400a420  (one allocation, reused)
BUFFER DEMO: 
BUFFER DEMO: ▶ 'Tiny' — file is 100 bytes
BUFFER DEMO:   chunk 1: capacity 4096, valid n = 100  ← partial: buffer[100..<4096] is 3996 stale/unused bytes, not played
BUFFER DEMO:   read returned 0 → end of song
BUFFER DEMO:   played 100 / 100 bytes in 1 chunk(s) ✓
BUFFER DEMO:   checksum played 0x18ed3fbf4acf7eef vs original 0x18ed3fbf4acf7eef ✓
BUFFER DEMO:   buffer storage address across chunks: 0x12400a420  (one allocation, reused)
BUFFER DEMO: 
BUFFER DEMO: ── what if we played the whole buffer instead of buffer[0..<n]? ──
BUFFER DEMO:   'Normal': buggy version played 12288 bytes (real: 10000), checksum WRONG
BUFFER DEMO:   'Exact Fit': buggy version played 8192 bytes (real: 8192), checksum matches — this size hides the bug
BUFFER DEMO:   'Tiny': buggy version played 4096 bytes (real: 100), checksum WRONG
BUFFER DEMO: 
BUFFER DEMO: ── error case: song file missing ──
BUFFER DEMO:   caught: read failed on chunk 1: The operation couldn’t be completed. No such file or directory — handled, not treated as end of song
BUFFER DEMO: 
BUFFER DEMO: all boundary cases: bytes played == file size, checksums match (measured)
BUFFER DEMO: deinit Song 'Missing Track'
BUFFER DEMO: deinit Playlist 'Buffer Cases'
BUFFER DEMO: deinit Song 'Normal'
BUFFER DEMO: deinit Song 'Exact Fit'
BUFFER DEMO: deinit Song 'Tiny'
```

**What this shows.** One 4096-byte buffer is allocated once and refilled — the storage address
is identical on every chunk of every song, so "reused" is observed, not asserted. Capacity
stays 4096 while the valid count `n` varies, and only `buffer[0..<n]` is ever played, which is
why every checksum matches.

The three song sizes are the test suite. 10,000 bytes ends in a partial chunk of 1808; 8,192
ends exactly on a boundary; 100 never fills the buffer at all. The loop stops on `n == 0`
rather than on a short read, which is what makes the exact-fit song come out right.

**The part worth pausing on:** the final block replays each song using the whole buffer instead
of `buffer[0..<n]`. The 10,000- and 100-byte songs come out corrupted — but the 8,192-byte
song's checksum *still matches*, because its last read filled the buffer exactly and left no
stale bytes behind. A test suite without an exact-fit case would have passed this bug.

### Stack demo
Recursive merge sort over `Playlist.sampleEight()` (8 songs, sorted by duration). Each
`-> mergeSort depth N [songs lo...hi]` / `<- return depth N` pair brackets one stack frame's
lifetime; the indentation mirrors the stack's actual shape — it grows while a call is waiting on
its children and shrinks as each one returns.

```
===== STACK DEMO =====
STACK DEMO: -> mergeSort depth 0 [songs 0...7]
STACK DEMO:   -> mergeSort depth 1 [songs 0...3]
STACK DEMO:     -> mergeSort depth 2 [songs 0...1]
STACK DEMO:       -> mergeSort depth 3 [songs 0...0]
STACK DEMO:          deepest call — Thread.callStackSymbols:
STACK DEMO:          0   mergeSort(_:lo:hi:depth:by:) + 1660
STACK DEMO:          1   mergeSort(_:lo:hi:depth:by:) + 808
STACK DEMO:          2   mergeSort(_:lo:hi:depth:by:) + 808
STACK DEMO:          3   mergeSort(_:lo:hi:depth:by:) + 808
STACK DEMO:          4   runStackDemo() + 252
STACK DEMO:          5   PlaylistStreamer_main + 508
STACK DEMO:          6   start + 6992
STACK DEMO:       <- return  depth 3
STACK DEMO:       -> mergeSort depth 3 [songs 1...1]
STACK DEMO:       <- return  depth 3
STACK DEMO:     <- return  depth 2
       ... (symmetric recursion over songs 2...7) ...
STACK DEMO: <- return  depth 0
STACK DEMO: sorted by duration: ["Almanac", "Ceiling Fan", "Half Light", "Ash Wednesday", "Meridian", "Dovetail", "Blue Harbour", "Ravel"]
```
_(Raw memory addresses trimmed from the `callStackSymbols` lines above for readability — see the
Xcode breakpoint screenshot in the IDE tools section for the untrimmed call stack.)_

**What this shows:** 8 songs split in half every call, so every base case (one song) bottoms out
at exactly depth 3 (`log₂8`) — visible both in the `depth 3` lines above and in the four stacked
`mergeSort` frames (depths 3, 2, 1, 0) the Xcode screenshot shows when paused at the breakpoint.
Each frame holds its own independent copy of `lo`, `hi`, and `depth` — confirmed in Xcode's
variables pane, where the selected frame reads `lo = 0, hi = 0, depth = 3`. This is the call
stack used for control flow, not data: contrast with `Stack<Song>` below, a stack we built
ourselves to hold values on purpose.

**`Stack<Song>` — a data structure we chose, not the call stack:**

```
STACK DEMO: recently played — Stack<Song>, a data structure we chose, not the call stack:
STACK DEMO:   pushed 'Meridian' -> top is now 'Meridian'
STACK DEMO:   pushed 'Half Light' -> top is now 'Half Light'
       ... (pushes continue for all 8 songs, in playback order) ...
STACK DEMO:   pushed 'Ash Wednesday' -> top is now 'Ash Wednesday'
STACK DEMO:   popping back off, most-recently-played first:
STACK DEMO:   popped 'Ash Wednesday'
STACK DEMO:   popped 'Dovetail'
       ... (pops continue in reverse push order) ...
STACK DEMO:   popped 'Meridian'
```

**What this shows:** same LIFO shape as the call stack above — the last thing pushed is the first
thing popped — but for a different reason and owned by different code. The call stack grows and
shrinks automatically: the runtime pushes a frame on every call and pops it on every return, and
we never touch its storage directly, only observe it (via `callStackSymbols` or the Xcode
Navigator). `Stack<Song>` only moves when *our* code calls `push`/`pop` — the Swift runtime has no
idea "recently played" history exists. We own its storage (the `elements` array inside the
struct, a heap buffer this type wraps) the same way we own `Playlist.songs`.

**Scope vs. lifetime, and three different things that look like "the array":**
- **Scope** is where in the *source code* a name is visible — e.g. `songs`, `lo`, `hi` are only
  nameable inside `mergeSort`'s body and its nested closures. **Lifetime** is how long the
  *value* those names point to actually exists in memory, which is a runtime question, not a
  source-code one. A `weak var` (see the heap demo) can be in scope while the object it refers to
  has already been deallocated — that gap is exactly the difference between the two.
- The `songs: [Song]` **parameter** is a value (a struct) that lives in each `mergeSort` stack
  frame — that's the thing `lo`/`hi`/`depth` sit next to, and it disappears the instant the frame
  pops.
- The **heap buffer behind it** is a separate allocation that the `[Song]` struct points to and
  manages; it's what actually holds the sequence of references, and it can be shared between
  array copies until one of them mutates (copy-on-write).
- Each individual **`Song` object** is yet another, independent heap allocation — the array's
  heap buffer holds *pointers* to these, not the songs themselves. That's why passing `songs`
  around (into `left`/`right` slices, into `Stack<Song>`) never copies a `Song`; it only copies
  references to the same 8 underlying objects, which is why the `deinit 'Meridian'` line at the
  very end only fires once, after every reference to it (the original array, the sorted result,
  the stack) has gone out of scope.

**The deep-recursion risk (described, not run):** merge sort recurses `log₂n` times because it
halves the problem every call — 8 songs is only depth 3, and even a playlist of a million songs
would only reach depth ~20. A *shuffle* that recursed once per song instead of once per halving
would be depth **n**, not log₂n — a million-song shuffle would need a million stacked frames.
Swift places no limit on recursion depth (unlike Python, which raises
`RecursionError` past a few thousand); it will simply keep pushing frames until it runs off the
end of the stack — 8 MB on the main thread, 512 KB on a secondary thread — and the process traps
with `EXC_BAD_ACCESS`, not a catchable error. We did not implement or run that version here; it's
included only as the point of contrast for why merge sort's `log₂n` depth is the safer shape.

### Heap demo

Full run: [`output-heap-run1.txt`](output-heap-run1.txt).

```
HEAP DEMO: allocated 'Meridian' (10000 bytes)
HEAP DEMO: using 'Meridian': duration 211s
HEAP DEMO: dropping the only reference (song = nil)
HEAP DEMO: deinit Song 'Meridian'
...
HEAP DEMO: --- LEAKY version: delegate held STRONG, both directions ---
HEAP DEMO: playlist 'Leaky Mix' holds 2 leaky songs
HEAP DEMO: dropping the only OUTSIDE reference (leakyPlaylist = nil)
HEAP DEMO: (silence above is the leak — no 'deinit Leaky...' line will ever print)
HEAP DEMO: --- FIXED version: same shape, using the real weak Song/Playlist ---
HEAP DEMO: playlist 'Fixed Mix' holds 2 songs, delegate wired
HEAP DEMO: dropping the only outside reference (playlist = nil)
HEAP DEMO: deinit Playlist 'Fixed Mix'
HEAP DEMO: deinit Song 'Open Link'
HEAP DEMO: deinit Song 'Free'
```

**What this shows:** the plain allocate → use → drop → `deinit` case proves ARC frees an
object the instant its last strong reference goes away. The leaky case builds the same shape
with a strong reference pointing back (`LeakySong.delegate`) — dropping the only reference from
*outside* the cycle leaves both objects still holding each other at a strong count of 1, so
neither `deinit` ever prints; that silence is the leak. The fixed case is identical except
`Song.delegate` is `weak`, which doesn't count toward the reference total, so dropping the
outside reference genuinely brings the count to 0 and every `deinit` fires. Same two-object
cycle shape, one keyword different, opposite outcome.

### Memory comparison
_TODO — Georgia. Include the measured/inferred table and all 5 runs per approach._

---

## IDE tools investigation

_TODO — Georgia. Xcode version, which features are built in vs. separate (Instruments is a
separate app bundled with Xcode), at least one tool demonstrated on our own code with
screenshots, and — the part the rubric actually weights — what each tool cannot establish._

---

## What we found along the way

**The exact-fit song hides the bug.** Replaying the whole buffer instead of `buffer[0..<n]`
corrupts the 10,000- and 100-byte songs, but the 8,192-byte song's checksum still *matches* —
because its final read fills the buffer exactly, so there are no stale bytes to replay. A test
suite with only "nice" sizes would have passed a broken implementation.

**`deinit` firing does not mean memory came back.** ARC releasing an object, libmalloc keeping
the block on a free list, and the kernel's page count staying flat are all true at the same
time. Most of our early confusion came from assuming those three layers move together.

**A local variable is not simply "on the stack."** `let songs = playlist.songs` puts an `Array`
struct in the stack frame, its element storage in a heap buffer, and the `Song` objects
somewhere else on the heap again — so merge sort shuffles pointers and never copies a song.

_More to add as the comparison lands — Sarah Rae._

## Pros, cons, limitations

Full write-up: [`docs/section7-pros-cons-limitations.md`](docs/section7-pros-cons-limitations.md).

**Pros.** ARC's determinism is what makes the demo provable — `deinit` lands at an exact,
repeatable point, so the retain-cycle leak shows up as *missing output* anyone can check
without a tool. The song sizes are chosen as test cases rather than arbitrarily, and the
8,192-byte case is the one that hides a stale-buffer bug, so the suite catches something the
obvious test misses. Checksums turn "the buffer logic is correct" into a number.

**Cons.** ARC's retain/release traffic is real work we never measure, and `weak` has its own
bookkeeping cost we present as free. We demonstrate exactly one heap risk, and a cycle through
a *closure* is more common in practice than our delegate cycle. The 4096-byte buffer is
conventional, not justified by measurement.

**Limitations.** `deinit` proves ARC released the object, not that memory went back to macOS.
Our peak-memory claim is **inferred**, not measured — we count reallocations directly but never
sampled memory mid-copy. Process-level numbers move in 16 KB pages, not objects. All
comparison figures come from one machine, because array growth is an unspecified
implementation detail that can differ by toolchain.

**With more time:** memory-map the file as a third strategy. It is the only addition that puts
the *kernel* on stage — our demo currently stops at libmalloc — and it would give us an honest
case where chunked buffering is the wrong tool.

## Team contribution statement

_TODO — Sarah Rae collects 3–5 sentences from each member, plus how we made sure everyone can
explain sections they did not write._

## AI tools and outside sources

_TODO — Sarah Rae collects from everyone. Starting list is in
[`projectDebrief.md`](projectDebrief.md) section 8._
