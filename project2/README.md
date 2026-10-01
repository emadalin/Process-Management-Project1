# PlaylistStreamer: Process Management Project 2

Memory management in Swift on macOS — **stacks, heaps and buffers** — demonstrated by a
program that simulates streaming audio. No sound is played: each "song" is a file of raw
bytes, which is what makes the memory behaviour easy to watch.

> **Status:** scaffolding + buffer demo done. Sections marked _TODO_ are owned by the member
> named beside them; see [`teamTask.md`](teamTask.md).

## What the program demonstrates

| Mode | Idea | What you see | Owner |
|---|---|---|---|
| `stack` | The call stack | Recursive merge sort of the playlist, with indented enter/return output and a real `Thread.callStackSymbols` dump at the deepest call | Ella |
| `heap` | ARC and object lifetime | `Song`/`Playlist` allocation, use and `deinit` — then a retain cycle that stops `deinit` firing, and the `weak` fix that restores it | Stephen |
| `buffer` | Moving data in chunks | Each song "played" through one reused 4096-byte buffer, with capacity vs. valid count, every chunk boundary case, and checksums proving nothing was lost | Calli |
| `compare` | What it costs | The same array built two ways — `append` alone vs. `reserveCapacity` first — with reallocation counts and Instruments measurements | Georgia |

The one-sentence version: **the stack tracks which functions are running, the heap holds data
that outlives a single function, and a buffer is a chunk of memory used to move data in pieces.**

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
  machine-details.md               every team Mac's OS, chip, RAM, page size, toolchain
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

_TODO — one labelled block per mode, each with a short "what this shows". Buffer output is
ready to paste (Calli); the rest follow as each demo lands._

### Buffer demo
_TODO — Calli_

### Stack demo
_TODO — Ella_

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

_TODO — Sarah Rae. Surprises worth reporting, e.g. the exact-fit song size that hides the
stale-buffer bug, and why `deinit` firing does not mean the process gave memory back._

## Pros, cons, limitations

_TODO — Sarah Rae (demo section 7), plus one improvement we would make with more time._

## Team contribution statement

_TODO — Sarah Rae collects 3–5 sentences from each member, plus how we made sure everyone can
explain sections they did not write._

## AI tools and outside sources

_TODO — Sarah Rae collects from everyone. Starting list is in
[`projectDebrief.md`](projectDebrief.md) section 8._
