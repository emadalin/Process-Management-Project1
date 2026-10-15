<!--
PlaylistStreamer — 30-minute demo deck.

Slides are separated by `---` on its own line, which is what Deckless, Marp,
Slidev and reveal-md all read. Presenter notes are HTML comments and will not
render.

Time budget matches the table in teamTask.md:
  1. Memory model        3 min
  2. Stack               4 min
  3. Heap                5 min
  4. Buffer + compare    6 min
  5. IDE tools           4 min
  6. Code walkthrough    4 min
  7. Pros/cons           2 min
     Questions           2 min

Rule for every slide: the slide shows code or output, the speaker does the
teaching. Do not read a slide aloud.

Code and output are quoted from the real files, with two deliberate exceptions:
some blocks are reflowed or elided with an ellipsis to fit slide width, and the
buffer slide shows the literal 4096 where the source reads `bufferCapacity`
(its default value). The `Data(contentsOf:options:.mappedIfSafe)` line in
section 7 is the proposed improvement and is NOT in the codebase.
-->

# PlaylistStreamer

### Stacks, heaps and buffers in Swift

Memory management on macOS — demonstrated, not defined

Sarah Rae · Ella · Stephen · Calli · Georgia

<!--
Opening line, do not read the slide: "We built a music streamer that plays no
music. Every song is a file of raw bytes, because that makes memory behaviour
something you can watch instead of something you take on faith."
-->

---

## What you'll see

```
swift run PlaylistStreamer stack     # how functions run
swift run PlaylistStreamer heap      # where objects live, and die
swift run PlaylistStreamer buffer    # how data moves in pieces
swift run -c release PlaylistStreamer compare   # what it costs
```

One Swift package. Five files, five owners. Every claim on screen is either
**measured** or labelled **inferred**.

<!--
That last sentence is the thesis of the whole demo. Say it deliberately.
-->

---

## Swift in 90 seconds

For anyone who hasn't written Swift — everything in this demo uses these:

```swift
let x = 5            // constant. `var` for a variable.
var y: Int? = nil    // Optional: Int or nothing. `y!` unwraps it.

struct Point { }     // VALUE type — copying makes an independent copy
class Song { }       // REFERENCE type — copying copies the pointer

guard x > 0 else { return }     // early exit, or the rest can't run
defer { stream.close() }        // runs when the scope ends, however it ends

deinit { print("gone") }        // runs the instant ARC frees the object
```

**The one that matters most today:** `struct` vs `class`.

<!--
Don't drill this. Point at struct vs class and say "hold onto that distinction,
every section comes back to it."
-->

---

# 1. Language and memory model

**3 minutes**

---

## Four layers, not one

| Layer | Decides |
|---|---|
| **Our code** | `struct` vs `class`; strong / `weak` / `unowned`; buffer sizes |
| **Swift compiler + ARC** | *When* each object dies. Inserts retain/release, runs `deinit` |
| **libmalloc** | *Where* bytes come from, and whether they go back to the OS |
| **macOS kernel** | What the process gets at all: pages, thread stacks |

> "The system handles memory" is the wrong answer. Name the layer.

<!--
The key consequence, say it out loud: these layers are INDEPENDENT. An object
can be freed by ARC while the process's memory number never moves, because
libmalloc kept the block. Both true at once. Most confusion about memory is
assuming they move together.
-->

---

## Stack and heap, in this program

**Stack** — per-thread, automatic, LIFO. Parameters, locals, return address.
Fast, and **fixed**: 8 MB main thread, 512 KB secondary.

**Heap** — process-wide. Anything that outlives its call, or whose size isn't
known at compile time. Flexible, slower, and someone must decide when space is
reusable. In Swift that's ARC.

```swift
let songs = playlist.songs     // one line, three places
```

- `songs` — an `Array` struct, ~8 bytes, **on the stack**
- its elements — a **heap buffer** of 8 pointers
- each `Song` — **a separate heap object**

<!--
This is the slide to slow down on. "Is this local variable on the stack?" has
no single answer, and that IS the answer. The variable is; the storage isn't;
the objects aren't.
-->

---

## Why `Song` is a `class`

```swift
final class Song {
    let title: String
    weak var delegate: PlaybackDelegate?
    deinit { DemoLog.say("deinit Song '\(title)'") }
}
```

A `struct Song` would be **copied** into the array. No identity, not
reference-counted — so no `deinit` to observe, and no retain cycle possible.

Every single thing in section 3 depends on this one keyword.

<!--
Expect to be asked why. This is a design decision, not a default.
-->

---

## ARC is not garbage collection

| | ARC (Swift) | Tracing GC (Java, Go) |
|---|---|---|
| Frees when | **count hits 0 — immediately** | collector next runs |
| `deinit` timing | deterministic, exact | late, or never |
| Reference cycles | **leak** | collected |

Determinism is what lets us *prove* things on stage.

The price is the last row — and that's section 3.

<!--
Honest trade, both directions. Don't present ARC as strictly better.
-->

---

# 2. Stack demonstration

**4 minutes** · `swift run PlaylistStreamer stack`

---

## Recursive merge sort — the code

```swift
private func mergeSort(_ songs: [Song], lo: Int, hi: Int, depth: Int,
                       by areInOrder: (Song, Song) -> Bool) -> [Song] {
    DemoLog.say("\(indent)-> mergeSort depth \(depth) [songs \(lo)...\(hi)]")

    guard hi > lo else {                    // base case: one song
        DemoLog.say("\(indent)<- return  depth \(depth)")
        return [songs[lo]]
    }

    let mid = (lo + hi) / 2
    let left  = mergeSort(songs, lo: lo,      hi: mid, depth: depth + 1, by: areInOrder)
    let right = mergeSort(songs, lo: mid + 1, hi: hi,  depth: depth + 1, by: areInOrder)
    return merge(left, right, by: areInOrder)
}
```

8 songs → depth `log₂8` = 3. Merge sort, not shuffle, **on purpose**.

<!--
Swift note worth one sentence: `by areInOrder: (Song, Song) -> Bool` is a
function taken as a parameter, and the call site passes it as a trailing
closure: `{ $0.durationSeconds < $1.durationSeconds }`.
-->

---

## The call stack, printed

```
-> mergeSort depth 0 [songs 0...7]
  -> mergeSort depth 1 [songs 0...3]
    -> mergeSort depth 2 [songs 0...1]
      -> mergeSort depth 3 [songs 0...0]
         deepest call — Thread.callStackSymbols:
         0  $s16PlaylistStreamer9mergeSort…F + 1664
         1  $s16PlaylistStreamer9mergeSort…F + 808
         2  $s16PlaylistStreamer9mergeSort…F + 808
         3  $s16PlaylistStreamer9mergeSort…F + 808
         4  $s16PlaylistStreamer12runStackDemoyyF + 312
         5  PlaylistStreamer_main + 500
      <- return  depth 3
```

Four live `mergeSort` frames. The **repeated `+ 808`** is the same recursive
call site, once per level.

<!--
Point at the +808 lines. That repetition is the recursion, visible. The one
different offset (+1664) is the frame that is actually executing.
-->

---

## Two things called "stack"

```swift
struct Stack<Element> {
    private var elements: [Element] = []
    mutating func push(_ element: Element) { elements.append(element) }
    mutating func pop() -> Element? { elements.popLast() }
}
```

| The call stack | `Stack<Song>` |
|---|---|
| Created by the OS for the thread | Created by us |
| Driven by calls and returns | Driven by `push` / `pop` |
| We never see its storage | Storage is a **heap** buffer |

Same LIFO shape. Two completely different reasons something is on top.

<!--
Swift notes: `<Element>` is a generic; `mutating` is required because a struct
method that changes the struct must say so. Both worth naming for non-Swift
people.
-->

---

## The risk we describe instead of causing

- Each call consumes a frame. The stack is **fixed** — 8 MB / 512 KB.
- Swift has **no recursion limit**. Python raises `RecursionError`; Swift just
  runs off the end and traps with `EXC_BAD_ACCESS`.
- Merge sort is depth **log n** — a million songs is 20 frames.
- A shuffle recursing once per song is depth **n**. *That's* the dangerous shape.

Nothing is copied: `[Song]` holds **references**. Merge sort moves 8 pointers.
No `Song` is duplicated, no `deinit` fires mid-sort.

<!--
Scope vs lifetime, if asked: scope is where a name is visible (compile time);
lifetime is how long the object exists (runtime). Independent for classes.
-->

---

# 3. Heap demonstration

**5 minutes** · `swift run PlaylistStreamer heap`

---

## Allocation → use → release

```swift
var song: Song? = Song(title: "Meridian", durationSeconds: 211, byteCount: 10_000)
DemoLog.say("using '\(song!.title)'")
song = nil          // last strong reference gone
```

```
HEAP DEMO: allocated 'Meridian' (10000 bytes)
HEAP DEMO: using 'Meridian': duration 211s
HEAP DEMO: dropping the only reference (song = nil)
HEAP DEMO: deinit Song 'Meridian'      ← fired on the previous line
```

`song` is on the stack. The `Song` **object** is not.

<!--
We use `var x: T? = ...; x = nil` rather than scope exit so the demo controls
the exact moment. Swift may release a local after its last USE, not at the
closing brace.
-->

---

## One drop, two kinds of object freed

```swift
var playlist: Playlist? = Playlist(name: "Road Trip", songs: [ … ])
playlist = nil
```

```
HEAP DEMO: deinit Playlist 'Road Trip'
HEAP DEMO: deinit Song 'Half Light'
HEAP DEMO: deinit Song 'Ravel'
```

`Playlist` holds its songs **strongly**, so releasing it releases them.

Order matters: the playlist's own `deinit` runs first, *then* its `songs` array
is torn down.

---

## The leak: strong in both directions

```swift
private final class LeakySong {
    var delegate: PlaybackDelegate?    // STRONG on purpose — the whole bug
}

private final class LeakyPlaylist: PlaybackDelegate {
    var songs: [LeakySong]
    init(…) { for song in songs { song.delegate = self } }   // closes the cycle
}
```

```
HEAP DEMO: dropping the only OUTSIDE reference (leakyPlaylist = nil)
HEAP DEMO: (silence above is the leak — no 'deinit Leaky...' will ever print)
```

**The evidence is the absence of output.**

<!--
Why it leaks: dropping the local removes the only reference from OUTSIDE the
cycle. Inside, playlist count is still 1 (from each song's delegate) and each
song's is still 1 (from the playlist's array). Neither reaches 0, ever.
-->

---

## The fix is one word

```swift
final class Song {
    weak var delegate: PlaybackDelegate?     // ← the entire difference
}
```

```
HEAP DEMO: deinit Playlist 'Fixed Mix'
HEAP DEMO: deinit Song 'Open Link'
HEAP DEMO: deinit Song 'Free'
```

Same shape. Same wiring. Every `deinit` fires.

`weak` doesn't count toward the total, and ARC **zeroes it** when the target
dies — which is why it must be an Optional `var`.

---

## Why the protocol says `: AnyObject`

```swift
protocol PlaybackDelegate: AnyObject { … }
```

Remove it and this won't compile:

```
error: 'weak' must not be applied to non-class-bound protocol
```

`weak` is a **reference-counting** mechanism, and only classes are
reference-counted. A struct could conform otherwise — and there'd be nothing to
zero out.

<!--
`unowned` also doesn't count, but assumes the target outlives the reference and
traps if wrong. A playlist can legitimately die before a song, so weak is
correct here. Name this; it's a likely question.
-->

---

## What `deinit` proves — and doesn't

**Proves:** ARC released the object, at an exact and repeatable moment.

**Does not prove:** that the process's memory went down.

libmalloc usually keeps the freed block on a free list to reuse. The kernel's
page count never changed.

> Three layers, three answers, all true simultaneously.

<!--
This is the single most important sentence in the heap section, and it sets up
section 4: RSS measures a DIFFERENT layer. Don't let anyone conflate them.
-->

---

# 4. Buffer demonstration and comparison

**6 minutes** · `buffer` and `compare`

---

## The buffer loop

```swift
var buffer = [UInt8](repeating: 0, count: 4096)   // ONE heap block, allocated once

while true {
    let n = stream.read(&buffer, maxLength: buffer.count)

    if n == 0 { break }                            // end of song
    if n < 0  { throw PlaybackError.readFailed(…) } // error, not end

    let valid = buffer[0..<n]                      // ONLY the valid bytes
    checksum.add(valid)
}
```

**capacity** = 4096, fixed. **count** = `n`, varies.

They're equal on every chunk *except the last*.

<!--
Swift notes: `&buffer` passes it mutably (inout). `buffer[0..<n]` is an
ArraySlice — a view, not a copy. `defer { stream.close() }` above guarantees
cleanup on every exit path including the throw.
-->

---

## The boundary cases ARE the test suite

```
▶ 'Normal' — file is 10000 bytes
  chunk 1: capacity 4096, valid n = 4096
  chunk 2: capacity 4096, valid n = 4096
  chunk 3: capacity 4096, valid n = 1808  ← partial
  played 10000 / 10000 bytes in 3 chunk(s) ✓
  checksum played 0xa34dce58… vs original 0xa34dce58… ✓
```

| Song | Size | Chunks | Case |
|---|---|---|---|
| Normal | 10,000 | 4096 · 4096 · **1808** | partial last chunk |
| Exact Fit | 8,192 | 4096 · 4096 | **exact boundary** |
| Tiny | 100 | **100** | smaller than the buffer |

Memory stays flat whatever the file size. That's the whole point of buffering.

---

## The bug, and the size that hides it

What if we processed the whole buffer instead of `buffer[0..<n]`?

```
'Normal':    buggy played 12288 bytes (real: 10000), checksum WRONG
'Exact Fit': buggy played  8192 bytes (real:  8192), checksum MATCHES ← !
'Tiny':      buggy played  4096 bytes (real:   100), checksum WRONG
```

The exact-fit song **passes** the broken code — its last read fills the buffer
exactly, so there are no stale bytes to replay.

> A test suite with only "nice" sizes would have shipped this bug.

<!--
This is the best slide in the buffer section. Land it, then pause.
-->

---

## Two ways to fill the same array

```swift
func fillSamples(from song: Song, reserve: Bool) throws -> FillResult {
    var samples: [Float] = []

    if reserve {
        samples.reserveCapacity(song.byteCount)   // ← B's entire difference
    }

    try playSong(song) { _, valid, _ in
        for byte in valid {
            samples.append(Float(byte) / 255)
            if samples.capacity != capacities[capacities.count - 1] {
                capacities.append(samples.capacity)   // COUNT reallocations
            }
        }
    }
}
```

Identical code path. We **log every capacity change** rather than estimate.

---

## Results — 10 million samples, release build

```
A: count 10000000, capacity 12582904, 22 reallocation(s)
B: count 10000000, capacity 10002424,  0 reallocation(s)
   samplesA == samplesB: ✓ identical
```

| | A: append | B: reserve |
|---|---|---|
| Reallocations | **22** | **0** |
| Instruments, total bytes | **115.39 MiB** | **57.55 MiB** |
| Allocations | 2,073 | 1,906 |
| `time -l` peak footprint | 52.2 MB | 41.9 MB |
| Persistent at exit | 204 KiB | 204 KiB |

Same 204 KiB left at exit → A's extra **57.84 MiB** was all allocated then
freed: the abandoned blocks from regrowth.

<!--
Equality first, always. If samplesA != samplesB the comparison is void and
nothing else on this slide means anything.
-->

---

## Measured vs inferred — say which

| Claim | Status |
|---|---|
| A reallocates 22×, B 0× | **Measured** — capacity log, 5 runs |
| `samplesA == samplesB` | **Measured** — element-wise, every run |
| A allocates 115.39 MiB vs B's 57.55 | **Measured** — Instruments |
| A's peak 52.2 vs 41.9 MB | **Measured** — `/usr/bin/time -l` |
| That gap is A's unused capacity | **Inferred** |
| The growth factor | **Not ours to claim** — Swift promises none. Observed ≈2×. |

Faster ≠ less memory. We don't let a timing number stand in for an allocation
number.

---

## Why every number comes from one Mac

Same code. Same 10M samples. Three answers:

| Where | Toolchain | A's final capacity |
|---|---|---|
| Georgia's M1, earlier session | Swift 6.4 | 10,010,616 |
| Georgia's M1, reported session | Swift 6.4 | **12,582,904** |
| Sarah's M2 | Swift 6.2.1 | 16,777,208 |

Array growth is an **unspecified implementation detail**. Numbers from two
different Macs aren't a comparison — they're two experiments.

Reference machine: **Georgia's M1**, one session, 2026-10-14.

<!--
This slide is the answer to "what evidence supports your conclusions." It shows
we understand WHY the rule exists, not just that we followed it.
-->

---

# 5. IDE tools investigation

**4 minutes**

---

## What we used, and what each can't tell us

| Tool | Built in / separate | Showed | Can't establish |
|---|---|---|---|
| Call stack at breakpoint | Built into Xcode | 4 live `mergeSort` frames + locals | How big a frame is, or *where* its memory lives |
| Memory Graph Debugger | Built into Xcode | The cycle, flagged ⚠ | *When* the leak started, or that memory grew |
| Instruments: Allocations | **Separate app**, bundled | 115.39 vs 57.55 MiB | Which allocation was "the array"; counts mallocs, not pages |
| `/usr/bin/time -l` | macOS CLI | Peak footprint 52.2 / 41.9 MB | Which object used it; whole process, 16 KB pages |

<!--
Be precise: Memory Graph and the call-stack view are built into Xcode.
Instruments ships inside Xcode.app but is a separate application.
-->

---

## A documented limitation, and the way round it

Xcode's live **Debug Memory Graph** button failed on this command-line program:

```
Unable to build memory graph
```

So we captured it from the command line instead:

```bash
leaks --atExit --outputGraph=leak.memgraph -- .build/debug/PlaylistStreamer heap
```

…then opened the `.memgraph` in Xcode's viewer. **Same viewer, fed from a file.**

`leaks` agrees independently: *4 leaks for 240 total leaked bytes*, one ROOT CYCLE.

<!--
The rubric explicitly allows explaining a documented limitation and the
alternative evidence used. This is that, and the independent agreement between
two tools is the strong part.
-->

---

## What the tools taught us they can't do

- **No tool showed the stack's memory.** Frames living on the stack is still
  **inferred** from how Swift and the CPU work.
- **A leak flag isn't a measurement.** It proves unreachable-but-alive, not
  that memory grew.
- **Instruments and RSS disagree, and both are right.** A allocated 2× B's
  bytes, but peaked at only 1.25×. *Total traffic* and *peak resident* are
  different questions.
- **Results depend on allocator state.** Same binary, same Mac: 21
  reallocations one session, 22 the next. A and B must be measured back to back.

---

# 6. Code walkthrough

**4 minutes** — the blocks that carry the project

---

## The five blocks that matter

| Block | Why it exists |
|---|---|
| `Song` / `Playlist` as **classes** | Puts them on the heap; enables `deinit` and the cycle |
| `weak var delegate` + `: AnyObject` | Breaks the cycle; the constraint is what makes `weak` legal |
| `buffer[0..<n]` | The correctness boundary — stale bytes live past `n` |
| `if n == 0 break` / `if n < 0 throw` | End and error are different; conflating them truncates files |
| `samples.capacity != capacities[…]` | Counting reallocations instead of guessing |

Everything else is scaffolding.

<!--
Rubric says don't explain every obvious line. Each person takes ~45 seconds on
the block of the SECTION THEY PRESENT, not their own file, and names the ONE
decision in it: Models Stephen, stack Georgia, heap Calli, buffer and compare
Sarah Rae, tool evidence Ella.
-->

---

## One block worth reading closely

```swift
var buffer = [UInt8](repeating: 0, count: 4096)

while true {
    let n = stream.read(&buffer, maxLength: buffer.count)
    if n == 0 { break }
    if n < 0  { throw PlaybackError.readFailed(chunk: chunk + 1, …) }
    let valid = buffer[0..<n]
    checksum.add(valid)
}
```

- **allocation** — one heap block, outside the loop
- **reuse** — every read writes into that same block
- **boundary** — `0..<n`, never `buffer.count`
- **ownership** — the slice is a *view*; it dies on the next read, so copy out
- **reclamation** — the array is a local; ARC frees its buffer at scope exit

Five of the seven things the rubric asks about, in nine lines.

---

# 7. Pros, cons, limitations

**2 minutes**

---

## Strengths of this approach

- **Determinism makes it provable.** `deinit` lands at an exact point, so the
  leak is visible as *silence* anyone can check without a tool.
- **The leak differs by one keyword**, so the only variable is `weak`.
- **One reused buffer, observed not asserted** — the same storage address on
  every chunk of a song.
- **Sizes chosen as test cases**, and the exact-fit case catches a bug the
  obvious test misses.
- **Checksums make correctness a number**, verified every run.

---

## Costs and what we can't show

**Cons**
- ARC's retain/release traffic is real work we never measure
- `weak` has side-table bookkeeping we present as free
- One heap risk demonstrated; a **closure** capturing `self` is more common in
  practice than our delegate cycle
- 4096 is conventional, not justified by measurement

**Limitations**
- Peak memory is **one number per run**; we never sampled mid-copy
- Chunk counts measure calls into Foundation, **not disk reads**
- The stack demo runs in **debug on purpose** — an optimiser may flatten
  recursion
- Single-threaded, simulated audio, 5 runs

---

## With more time: memory-map the file

```swift
let data = try Data(contentsOf: url, options: .mappedIfSafe)
```

Why this one, out of everything:

It's the only addition that puts a **fourth** actor on stage. Our demo stops at
libmalloc — mapping hands the job to the **kernel**, which faults pages in on
demand. The 16 KB page size stops being trivia and becomes the mechanism.

It would also give us an honest case where our approach **loses**: for random
access across a large file, mapping is simpler and faster.

<!--
Why we didn't: needs a file large enough for paging to be observable (hundreds
of MB), which breaks the input sizes the rest of the demo uses, and it would
need its own measurement methodology.
-->

---

## The one sentence to leave behind

> The stack tracks **which functions are running**, the heap holds **data that
> outlives a single function**, and a buffer is **a chunk of memory used to
> move data in pieces**.

And the layers underneath — our code, ARC, libmalloc, the kernel — move
**independently**.

### Questions

<!--
2 minutes. Answer sheet is docs/practice-questions.md — everyone has worked
through it, and any of us can take any question.
-->

---

## Backup: reproduce everything

```bash
git clone … && cd project2
./verify.sh                  # builds, runs every mode, prints machine row

swift run PlaylistStreamer all
swift run -c release PlaylistStreamer compare
```

- `docs/compare-results.md` — all 5 runs, both sizes, Instruments, `time -l`
- `docs/machine-details.md` — every Mac; reference machine named
- `docs/practice-questions.md` — team answer sheet
- `output-*.txt` — saved runs, one per mode

---

## Backup: likely questions

**"Is this local on the stack or the heap?"** — The variable is. Its storage
may not be. `Array`/`String` are structs on the stack with heap element storage.

**"Does leaving the function free it?"** — Only if it held the *last strong*
reference.

**"Why `weak` not `unowned`?"** — A playlist can legitimately be freed before a
song, so `unowned` would trap.

**"One chunk = one disk read?"** — No, and we don't claim it. We count calls
into `InputStream`; the page cache sits underneath.

**"Is the comparison fair?"** — Identical work, identical input, equality
asserted before any number is reported. Fair for these two approaches on one
machine and one toolchain.
