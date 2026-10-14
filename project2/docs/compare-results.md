# Comparison results: append vs `reserveCapacity` · Member 5

Command: `swift run -c release PlaylistStreamer compare --samples=N` (release build, 5 runs per size).

**Machine:** Apple M1 (arm64), 16 GB RAM, macOS 26.6.2 (25G83), Apple Swift 6.4 (swiftlang-6.4.0.34.1), Xcode 27.0 (27A266a) for Instruments.
**Every number below was measured in one session on 2026-10-14.** See *Same Mac, different session* at the end for why that matters.

## Memory: identical across all 5 runs (measured)

| Samples | A reallocations | B reallocations | A capacity / count | B capacity / count | `samplesA == samplesB` |
|---|---|---|---|---|---|
| 10,000,000 | 22 | 0 | 12,582,904 / 10,000,000 | 10,002,424 / 10,000,000 | ✓ all 5 runs |
| 50,000,000 | 24 | 0 | 50,331,640 / 50,000,000 | 50,003,960 / 50,000,000 | ✓ all 5 runs |

A's growth at 10M: `0 → 4 → 8 → 16 → 32 → 72 → 152 → … → 786,424 → 1,572,856 → 3,145,720 → 6,291,448 → 12,582,904`. That is ×2 at almost every step (one ×2.40 and a few ×2.0x steps early on). **Observed, not promised:** Swift does not document a growth factor.

Doubling has a side effect. A finishes with **2.58 million unused slots** (about 10 MB), because the last doubling overshot 10M. B finishes with 2,424 spare slots.

## Time, in seconds (measured; includes file reads, which both sides pay)

| Samples | Side | Run 1 | Run 2 | Run 3 | Run 4 | Run 5 | Mean | Median |
|---|---|---|---|---|---|---|---|---|
| 10M | A | 0.0678 | 0.0692 | 0.0688 | 0.0684 | 0.0686 | 0.0686 | 0.0686 |
| 10M | B | 0.0625 | 0.0613 | 0.0611 | 0.0609 | 0.0611 | 0.0614 | 0.0611 |
| 50M | A | 0.3493 | 0.3400 | 0.3421 | 0.3398 | 0.3447 | 0.3432 | 0.3421 |
| 50M | B | 0.3417 | 0.3160 | 0.3060 | 0.3064 | 0.3117 | 0.3164 | 0.3117 |

B is about **11% faster at 10M and 9% faster at 50M** by median. B's run 1 at 50M is the slowest of its five, probably a cold file cache (**inferred**).

## Instruments Allocations (measured, 10M samples, one recorded run per side)

Recorded with Xcode 27.0's Allocations template, one side at a time:
`xcrun xctrace record --template Allocations --launch -- .build/release/PlaylistStreamer compare --only=a` (then `--only=b`).
Screenshots: [`instruments-alloc-a.png`](instruments-alloc-a.png), [`instruments-alloc-b.png`](instruments-alloc-b.png). Traces: `docs/traces/`.

| Side | Total bytes (All Heap Allocations) | # Total allocations | # Transient (freed) | Persistent at exit |
|---|---|---|---|---|
| A (append) | 115.39 MiB | 2,073 | 719 | 204.45 KiB |
| B (reserve) | 57.55 MiB | 1,906 | 552 | 204.45 KiB |

Over its run, A asked libmalloc for **twice the bytes** B did. Both sides end with the same 204 KiB still alive, so the whole difference is memory that was allocated and then freed.

**The difference matches our own count exactly.** Adding up the 22 capacities A logged (× 4 bytes per `Float`) gives 95.99 MiB of array storage, against B's single block of 38.16 MiB. That is a difference of **57.84 MiB**, and Instruments' difference is 115.39 − 57.55 = **57.84 MiB**. The capacity log and Instruments measured the same thing two independent ways.

A also made 167 more allocations than B, while its log shows only 22 reallocations. We haven't explained the other 145. They are too small to show up in the byte total (**open question**).

How to repeat this: release binaries built by `swift build` cannot be attached to by Instruments ("Failed to attach to target process"). Re-sign the binary with the `com.apple.security.get-task-allow` entitlement first (`codesign -f -s - --entitlements ent.plist .build/release/PlaylistStreamer`). That changes the signature, not the code, and we checked that the results are identical either way.

## Process memory: `/usr/bin/time -l` (measured, 10M samples, 3 runs per side)

Each side ran on its own (`--only=a` / `--only=b`) so one side's freed blocks can't inflate the other's number. All 3 runs per side gave identical values.

| Side | Max RSS | Peak memory footprint | Final array storage |
|---|---|---|---|
| A (append) | 60,358,656 B (57.6 MiB) | 52.23 MB | 50.33 MB |
| B (reserve) | 46,841,856 B (44.7 MiB) | 41.88 MB | 40.01 MB |

A peaks **10.4 MB higher** than B. That is almost exactly the difference in final array size (10.3 MB): A's unused doubled capacity.

**This contradicts something we expected.** We assumed (inferred) that A's peak would be higher because the old and new blocks exist together while elements are copied: 25 MB + 50 MB at the last regrowth. If that were true at the page level, A's footprint would reach about 77 MB. It reached 52 MB. So the extra cost of append showed up as **total bytes allocated** (Instruments) and as **leftover capacity**, but not as a big simultaneous peak. Why not is **inferred only**. Possibly the large-block growth path avoids touching both blocks in full at the same time, but we did not trace it.

How this differs from object sizes: RSS counts **pages** (16 KB each on this M1) that macOS has mapped into the process. That includes everything: code, the 4096-byte read buffer, Foundation and allocator slack. RSS can't tell which object a page belongs to. The array's own size (`capacity × 4` bytes) is what the program prints. Instruments Allocations sits between the two: it sees each malloc/free but not pages.

## Same Mac, different session

The same code on the same Mac gave different memory numbers in earlier sessions:

| When | A reallocations (10M) | A final capacity | `time -l` peak footprint A / B |
|---|---|---|---|
| 2026-10-01, and 2026-10-14 before ~12:40 | 21 | 10,010,616 | not measured / ~88.7 / 62.2 MB (first 10-14 run) |
| 2026-10-14 afterwards (this document) | 22 | 12,582,904 | 52.2 / 41.9 MB |

In the 21-reallocation runs, the step after 786,424 jumped ×3.18 to 2,502,648. That means libmalloc handed back a block much bigger than requested, and Swift used the extra space as capacity. We ruled out the code signature, the toolchain/SDK used to build, and libmalloc's large-block cache setting (`MallocLargeCache=0/1`); the cause is still unknown. Within a session, every result above repeated exactly.

**What this means:** Swift grows the array from whatever block libmalloc actually returns, not just from what it asked for. That depends on the allocator's state, not only on our code. This is why the comparison only holds within one session: A and B were always measured back to back, under the same conditions.

## Measured vs inferred

| Claim | Status | Evidence |
|---|---|---|
| A reallocates 22× (10M) / 24× (50M); B 0× | **Measured** | capacity-change log, 5 runs each |
| `samplesA == samplesB` | **Measured** | element-wise compare, every run |
| Final capacity vs count (A 12,582,904 / B 10,002,424 at 10M) | **Measured** | `Array.capacity` |
| A allocates 115.39 MiB in 2,073 heap allocations; B 57.55 MiB in 1,906 | **Measured** | Instruments Allocations |
| A's extra 57.84 MiB is exactly its abandoned intermediate blocks | **Measured** (two ways) | sum of logged capacities = Instruments difference |
| A's peak footprint is 10.4 MB higher than B's | **Measured** | `/usr/bin/time -l` |
| That peak gap is A's unused overshoot capacity | **Inferred** | it matches the final-capacity difference to within 0.1 MB |
| A's peak is *not* raised by old + new blocks coexisting | **Measured that it isn't, inferred why** | footprint 52 MB vs ~77 MB predicted |
| B is ~9–11% faster by median | **Measured** | `ContinuousClock`, 5 runs, release build |
| Growth is "about ×2" | **Observed, not promised** | Swift documents no growth factor |
| Reallocation count depends on allocator state, not only on code | **Observed** | 21 vs 22 on the same Mac in different sessions; cause unknown |
| Capacity > count in B comes from libmalloc rounding up the block | **Inferred** | not observed directly |

## What this shows

- **Measured:** without a reserve, A moved its whole storage to a new heap block 22 times. B allocated once. Both produced identical samples.
- **Measured:** append cost twice the total heap traffic (115 vs 58 MiB). Our capacity log predicts that difference to the hundredth of a MiB.
- **Measured, and a correction:** the cost did *not* show up as a large simultaneous peak. What A still holds at the end is its unused doubled capacity, about 10 MB more than B.
- **Not a memory result:** the timing gap is small because copying is cheap next to reading the file. Faster doesn't mean less memory.
