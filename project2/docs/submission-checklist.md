# Submission Checklist

Owner: Member 1 (Sarah Rae). Due **Thursday, Oct 15, 11:59 pm**. Audited 2026-10-06.

Canvas deliverables from `projectDebrief.md` section 5, against what is actually in the repo
today. "Blocked on" names the person, not the task.

| # | Deliverable | State | Blocked on |
|---|---|---|---|
| 1 | Source code + input files, or a script that generates them | **Done** — `BufferDemo.swift` generates its own `.raw` songs at startup, so no binaries are checked in | — |
| 2 | Build/run instructions: Swift version, macOS version, how to run each mode | **Done** — README *Requirements* and *Build & run* | — |
| 3a | Labelled output: stack | **Done** — `output-stack-run1.txt`, README | — |
| 3b | Labelled output: heap | **Done** — `output-heap-run1.txt`, README | — |
| 3c | Labelled output: buffer, with boundary cases | **Done** — all three chunk cases covered | — |
| 3d | Labelled output: **both comparison approaches** | **Not started** | Georgia |
| 4 | IDE screenshots with explanations | **Not started** — no image committed | Georgia (Instruments, Memory Graph); Ella owes the call-stack screenshot |
| 5 | List of documentation sources used | **Not started** — starting list is `projectDebrief.md` section 8 | everyone → Sarah |
| 6 | Team contribution statement | **Not started** | everyone → Sarah |

## What this says

**Three of six are genuinely finished.** Deliverable 3 is three-quarters done.

**Two of the six are collection jobs** (5 and 6) that need four short paragraphs from four
people. They are the least work in the project and have the longest lead time, so they are the
likeliest to be the thing still missing on the 14th.

**Deliverable 4 has no owner moment scheduled.** Screenshots cannot be produced by whoever
happens to be free — Instruments and the Memory Graph Debugger have to be driven by someone
with the project open and a specific thing to look at. Ella's call-stack screenshot is ticked on
her checklist but **no image file exists in the repo**, so either it lives on her machine or the
box was ticked early. Worth confirming before the 14th.

## Not on the Canvas list, but required by the demo

- [ ] `swift build` + every mode confirmed on all five Macs — `./verify.sh` does this in one
      command; 1 of 5 machines reported
- [ ] `docs/machine-details.md` — 1 of 5 rows filled
- [ ] Which machine produced the comparison numbers — the block at the end of
      `machine-details.md` is still blank, and it must match the README
- [ ] Rehearsal scheduled, with everyone explaining a section they did not write
- [ ] Demo section 6 (code walkthrough) — currently "everyone, own file, ~45 s"; confirm or
      reassign at the rehearsal

## Suggested order once people are back

1. Everyone runs `./verify.sh` and pastes the row — unblocks two items in one message
2. Georgia starts the comparison; it gates deliverables 3d and 4, which are ~10 of the 30 demo minutes
3. Everyone sends 3–5 sentences for the contribution statement and their sources, while Georgia works
4. Rehearsal once the comparison runs, not after it is written up
