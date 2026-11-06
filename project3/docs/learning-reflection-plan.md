# Learning & Reflection Plan (Project 3)

## Why

To reach A territory the professor wants our **learning** visible, not just working code:

1. that we understand the OS concepts, not just the Swift
2. that each of us learned the parts **other people** built
3. that our AI use is visible — what it helped with and what we checked

> **The professor draws presenters at random on the day.** So each of us has to be able to
> present **any** section. "That was Stephen's part" is not an answer we can give. Everything
> below exists to make that true; nothing below exists for its own sake.

**Rule:** you write your own reflection, in your own words. AI can explain a concept to you —
it does not write this. If it helped, say so.

---

## 📅 Held: Thursday 29 October, 9:35–10:55, in class

**A week before the demo on Thursday 5 November** — deliberately, so there is time to
fix whatever it exposes. **Eighty minutes — the whole thing fits in that one slot.** Bring your laptop with the app
building, and have your own log open in a second window.

| Time | What |
|---|---|
| 9:35–9:40 | Everyone opens BoothCam and their own `reflections/<name>.md` |
| 9:40–10:30 | **Five sections, 10 minutes each** — 5 min walking your part, 5 min answering questions on it |
| 10:30–10:55 | Finish your log entries, tick the readiness tracker for each other |

Order: Sarah (device stack) → Stephen (camera) → Georgia (snap) → Calli (filter) → Ella (testing).

**You write your two sentences per section as each person speaks.** That is the whole record —
there is nothing to write up afterwards, and nothing to catch up on if you do it live.

Come having already added your AI rows to [`reflections/ai-use-log.md`](reflections/ai-use-log.md);
that is the one thing that does not work well as a group activity.

## What this costs you

Per person: **the 80-minute class slot, plus about 5 minutes** adding your AI rows beforehand.
There is no second round, no separate partner exercise, and no per-session write-up.

---

## 1. The concept map

Everyone should be able to connect each part to the **OS idea** behind it — that connection is
what's being graded, not a description of the code.

| Part of BoothCam | Built by | OS concept |
|---|---|---|
| Device stack diagram | Sarah | I/O layers: app → library → OS service → driver → hardware |
| Camera, live frames, cleanup | Stephen | Device access, TCC permissions, resource release, background queues |
| Snap | Georgia | Copying data vs. holding a reference to a reused buffer pool |
| Grayscale filter | Calli | How pixels are stored in memory; CPU vs. GPU |
| Testing on 5 Macs | Ella | How OS version, permissions and hardware change behaviour |

Links back: frames arrive on a **background queue** (Project 1) into **reused buffers**
(Project 2) — which is the whole reason snap has to copy.

## 2. The one meeting — Thursday 29 Oct, 9:35 in class

Each person takes **10 minutes**:

- 5 min walking their own code or diagram
- 5 min answering the four questions below, asked by whoever hasn't spoken yet

Everyone else writes **two sentences per section** in their own log as they go. That is the
record — there is no separate session write-up to produce afterwards.

### The four questions

1. **What** does this do? (point at the lines)
2. **How** does it work, step by step?
3. **Why** this way — what OS concept is behind it?
4. **What if** it were done differently, or went wrong?

Question 4 is the one that shows real understanding. *What if we never stopped the session? What
if snap kept a reference instead of a copy?*

[`reflections/readiness-tracker.md`](reflections/readiness-tracker.md) records who heard each
section taught and discussed it.

## 3. The files

In [`reflections/`](reflections/) — all skeletons, fill in the blanks:

| File | Who | Effort |
|---|---|---|
| `<yourname>.md` | each person | one page, after the meeting |
| `readiness-tracker.md` | entered after the session | a tick and a date |
| `ai-use-log.md` | anyone who used AI | one row each |

## 4. Showing it in the demo

Whoever is drawn for section 5 shows the readiness tracker and names one moment where somebody
learned a part they didn't build. The random draw itself is the real evidence — if any of us can
present any section, that proves more than any document does.

## Checklist

- [x] Skeletons exist in `docs/reflections/`
- [x] Book the meeting — **Thursday 29 October, 9:35–10:55, in class**
- [ ] Everyone fills in their own log straight after it — **Sarah ✔, Calli ✔ and Ella ✔ have**,
      Georgia has started; Stephen has not yet
- [x] Readiness tracker complete before demo day — filled 29 Oct
