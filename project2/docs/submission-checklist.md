# Submission Checklist

Owner: Member 1 (Sarah Rae). Due **Thursday, Oct 15, 11:59 pm**. Audited 2026-10-15.

Canvas deliverables from `projectDebrief.md` section 5, against what is actually in the repo.

| # | Deliverable | State |
|---|---|---|
| 1 | Source code + input files, or a script that generates them | **Done** — `BufferDemo.swift` generates its own `.raw` songs at startup, so no binaries are checked in |
| 2 | Build/run instructions: Swift version, macOS version, how to run each mode | **Done** — README *Requirements* and *Build & run*; `./verify.sh` checks a machine in one command |
| 3a | Labelled output: stack | **Done** — `output-stack-run1.txt`, README |
| 3b | Labelled output: heap | **Done** — `output-heap-run1.txt`, README |
| 3c | Labelled output: buffer, with boundary cases | **Done** — all three chunk cases, checksums, and the stale-buffer bug |
| 3d | Labelled output: both comparison approaches | **Done** — `output-compare-run1.txt`; all 5 runs at both sizes in [`compare-results.md`](compare-results.md) |
| 4 | IDE screenshots with explanations | **Done** — `stack-call-stack-xcode.png`, `heap-memory-graph-leak.png`, `instruments-alloc-a.png`, `instruments-alloc-b.png`, each explained in the README *IDE tools investigation* section |
| 5 | List of documentation sources used | **Done** — [`sources.md`](sources.md), every member's entries confirmed |
| 6 | Team contribution statement | **Done** — README *Team contribution statement*, with the demo running order and who presents whose section |

## Still open

- [ ] Calli's row in [`machine-details.md`](machine-details.md) is still carried over from
      project 1 and marked **†**; four of five machines have reported fresh. Nothing in the
      report depends on it, since every measured number came from Georgia's M1

All six Canvas deliverables are done. The reference machine is recorded, every comparison
figure comes from one session on it, and each claim is labelled measured, inferred or observed.
The one open item above does not block submission.
