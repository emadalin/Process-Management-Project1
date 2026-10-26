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

## What this costs you

Honest total, per person: **about 75 minutes**, and most of it is a meeting we need anyway.

| What | When | Your time |
|---|---|---|
| One team meeting — everyone walks their section | Once, when the app works | 60 min (together) |
| Fill in your own log | Right after that meeting | 15 min |
| One random drill | At the rehearsal we're already having | 0 extra |
| Add your AI rows | As you go | 5 min |

That's it. There is no second round, no separate partner exercise, no per-session write-up.

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

## 2. The one meeting

Book 60 minutes once the app works. Each person takes **10 minutes**:

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

Whoever answers a section's questions well gets ticked off for it in
[`reflections/readiness-tracker.md`](reflections/readiness-tracker.md) — by someone else, not
themselves.

## 3. One drill, at the rehearsal

We're rehearsing anyway. Spend 15 minutes of it drawing names and sections from a hat and
presenting cold, exactly like the real thing. Log anything shaky in the tracker and review it
before the demo.

## 4. The files

In [`reflections/`](reflections/) — all skeletons, fill in the blanks:

| File | Who | Effort |
|---|---|---|
| `<yourname>.md` | each person | one page, after the meeting |
| `readiness-tracker.md` | whoever signs someone off | a tick and a date |
| `ai-use-log.md` | anyone who used AI | one row each |
| `team-reflection.md` | together, at the end | one paragraph each |

## 5. Showing it in the demo

Whoever is drawn for section 5 shows the readiness tracker and names one moment where somebody
learned a part they didn't build. The random draw itself is the real evidence — if any of us can
present any section, that proves more than any document does.

## Checklist

- [x] Skeletons exist in `docs/reflections/`
- [ ] Book the 60-minute meeting (needs the app working — so Georgia and Calli first)
- [ ] Everyone fills in their own log straight after it
- [ ] 15-minute random drill at the rehearsal
- [ ] Readiness tracker complete before demo day
- [ ] Team reflection, one paragraph each
