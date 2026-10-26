# Learning & Reflection Plan (Project 3, and going forward)

## Why we're doing this
Our professor said that to reach **A territory**, each team and each member needs to make their **learning and personal reflections clearly visible**. Specifically, he wants to see:
1. That we are actually learning the OS concepts (processes, memory, devices), not just getting code to run
2. How each of us is learning the parts **other teammates** built
3. How we make sure teammates understand our work at **more than a surface level**
4. That our AI use is visible: what it helped with, what we checked, and what we learned

> **On presentation day, the professor picks who presents each section at random.** Nobody knows ahead of time which part they'll get. So **every one of us has to understand ALL of the material**, every section, every file, every diagram, well enough to present it and answer questions on it. "That was Stephen's part" is not an answer we can give.

This plan turns those points into things we do and files we submit.

> **Rule:** Reflections are written by each person, in their own words. AI can help us understand a concept, but it does not write our reflections or teach-back answers. If AI explained something to you, say so in your log.

---

## Files to add to the repo
```
project3/docs/reflections/
├── sarah.md           ← personal learning log (template below)
├── stephen.md
├── georgia.md
├── calli.md
├── ella.md
├── readiness-tracker.md ← who has signed off on which sections
├── teach-back-log.md  ← record of each teaching session and how it went
├── ai-use-log.md      ← what AI suggested, what we checked or changed
└── team-reflection.md ← one shared reflection written together at the end
```
Add all of these to the Canvas submission and mention them in the README.

---

## 1. Concept map: what OS idea each part teaches
Everyone must be able to explain **every row** of this table and connect the code to the OS concept, not just describe the code. "Built by" only shows who teaches it first.

| Part of BoothCam | Built by | OS concept it shows |
|---|---|---|
| Device stack diagram | Sarah | I/O layers: app → library → OS service → driver → hardware; abstraction |
| Opening camera, live frames, cleanup | Stephen | Device access, permissions (TCC), resource ownership and release, background threads/queues |
| Snap (copying a frame) | Georgia | Memory: copying data vs. holding a reference to a reused buffer pool |
| Grayscale filter | Calli | How image data is stored in memory (pixels, RGB channels), where work runs (CPU vs. GPU) |
| Testing on 5 Macs | Ella | How OS versions, permissions, and hardware differences change behavior |

Also note links to earlier projects in your log, for example: the camera delivers frames on a **background queue** (Project 1, threads) into **reused buffers** (Project 2, memory).

---

## 2. Making sure everyone knows everything
Since anyone can be called on for anything, learning happens in three rounds. Each round is harder than the last.

### Round 1: Whole-team teaching sessions (one per section)
The person who built each section teaches it to **all four** teammates at once.
- **5 sessions total**, about 20–25 minutes each (can be done 2–3 in one meeting)
- The builder walks through the code or diagram (10 min)
- Then **each listener explains one piece back** without notes, pointing at the code (10 min)
- The builder asks the 4 check questions below, spread across different people
- Write one entry in `teach-back-log.md` per session

| Session | Teacher | Section |
|---|---|---|
| 1 | Sarah | Device stack & library selection |
| 2 | Stephen | Camera connection, live frames, errors, cleanup |
| 3 | Georgia | Snap / still capture (copy vs. reference) |
| 4 | Calli | Grayscale filter & comparison view |
| 5 | Ella | Testing, troubleshooting & research record |

### Round 2: Partner explain-backs
After Round 1, pair up and explain each section you **didn't build** to a partner, start to finish, with no notes. Switch partners so you explain to different people.
- Partner marks you ready or not ready in `readiness-tracker.md`
- If you get stuck, go back to the builder, then try again with a different partner

### Round 3: Random drills (practice exactly like presentation day)
Do this at least **twice** before the demo, including the full rehearsal.
- Write the 5 demo sections on slips of paper, and the 5 names on another set
- Draw a name and a section; that person presents it right now, no prep
- The rest of the team plays the professor and asks questions from the practice list
- Keep drawing until everyone has presented at least 2 sections they didn't build
- Log any section where someone struggled and review it before the next drill

### The 4 check questions (beyond surface level)
For any section, everyone should be able to answer:
1. **What** does this code do? (point to the lines)
2. **How** does it work, step by step?
3. **Why** is it done this way, and what OS concept is behind it?
4. **What if** it went wrong or was done differently? (e.g. "What if we didn't stop the session?" "What if snap kept a reference instead of a copy?")

Question 4 is the one that proves real understanding.

### Teach-back log entry template
```
## [Date] — [Teacher] taught [section] to [who was there]
- Who explained what back (in their own words):
- Check questions people struggled with:
- How the teacher cleared it up:
- Anyone who needs another pass on this section:
```

### Readiness tracker (`readiness-tracker.md`)
Everyone needs a ✅ in **every** box before the demo. A box is only checked when a teammate (not you) heard you explain it with no notes and answer a "what if" question.

| Section | Sarah | Stephen | Georgia | Calli | Ella |
|---|---|---|---|---|---|
| 1. Running the app on my Mac | ☐ | ☐ | ☐ | ☐ | ☐ |
| 2. Device stack & library selection | ☐ | ☐ | ☐ | ☐ | ☐ |
| 3a. Camera, live frames, errors, cleanup | ☐ | ☐ | ☐ | ☐ | ☐ |
| 3b. Snap / copy vs. reference | ☐ | ☐ | ☐ | ☐ | ☐ |
| 3c. Grayscale filter & comparison | ☐ | ☐ | ☐ | ☐ | ☐ |
| 4. Research, troubleshooting & AI use | ☐ | ☐ | ☐ | ☐ | ☐ |
| 5. Collaboration, tradeoffs, limitations | ☐ | ☐ | ☐ | ☐ | ☐ |
| All 10 practice questions | ☐ | ☐ | ☐ | ☐ | ☐ |

Next to each check, write who signed you off and the date (e.g. `✅ Calli 10/30`).

---

## 3. Personal learning log (each person)
Write short entries as you go, not all at the end. 3–5 sentences each is enough. Use your own voice.

```
# [Name] — Project 3 Learning Log

## Before we started
- What I already knew about how apps talk to hardware:
- What I expected to be hardest:

## Entries
### [Date] — [What I worked on]
- What I learned about the OS (not just Swift):
- Something that surprised me or that I got wrong at first:
- How I figured it out (docs, testing, a teammate, AI):

## Learning every other section
- Device stack — what I learned / what clicked:
- Camera & cleanup — what I learned / what clicked:
- Snap — what I learned / what clicked:
- Filter — what I learned / what clicked:
- Testing & troubleshooting — what I learned / what clicked:
- The section that was hardest for me to learn, and how I got there:

## Helping teammates understand my part
- How I taught it to the team:
- What people found confusing, and how I explained it differently:

## Random drills
- Section I got drawn and how it went:
- What I had to go back and study after:

## AI use (if any)
- What I asked AI and why:
- What I checked or changed in its answer:
- What I learned from it that I could now explain without it:

## End of project
- The OS concept I understand much better now, and how I'd explain it to someone:
- How this connects to Projects 1 and 2:
- What I'd still like to understand better:
```

---

## 4. AI use log (shared)
The professor wants to see that AI helped us learn rather than replaced the learning. Log the significant uses, not every small question.

```
## [Date] — [Who] — [Topic]
- What we asked:
- What AI suggested:
- What we checked (docs, testing, running it, a teammate):
- What was wrong, missing, or changed:
- What we learned:
```

Good examples to log from Project 3 setup: the `import Combine` error, the missing Info.plist, the App Sandbox camera checkbox, and Xcode auto-staging files. Each one has a "what we found and how we confirmed it" story. **Everyone** should be able to tell at least two of these stories, since anyone could get section 4.

---

## 5. Team reflection (written together, end of project)
One shared file, about one page. Everyone contributes at least one paragraph in their own words.

1. What did we learn about how an application reaches a physical device?
2. How did we make sure every member understood every part, knowing presenters would be random? What worked, and what would we do differently?
3. Where did a teammate's explanation change how someone else understood the system?
4. How did AI help, where did we have to correct it, and how did we keep it from replacing our learning?
5. How does this project connect to threads (Project 1) and memory (Project 2)?
6. One thing we're still unsure about.

---

## 6. Show it in the demo
- Whoever gets drawn for section 5 (collaboration) briefly shows the **readiness tracker** and one learning log entry
- Mention one concrete moment where someone learned a part they didn't build (e.g. "Ella could explain why snap copies the frame because Georgia walked the team through it, and she got drawn for it in our practice drill")
- The random draw itself is the real proof. If anyone can present anything, that shows the learning better than any document

---

## 7. Apply it to Projects 1 and 2 too
Since those grades are still being updated, each person writes a **short reflection** (half a page) for each earlier project:
- What I learned about threads/scheduling (P1) or memory (P2) that I didn't know before
- One part a teammate built that I can explain, and what it shows
- How we used AI and what we checked

Send these to the professor or add them to the repo under `project1/docs/reflections/` and `project2/docs/reflections/`.

---

## Checklist
- [ ] Create the `docs/reflections/` folder and files, including `readiness-tracker.md`
- [ ] Each person starts their learning log this week (the "Before we started" section)
- [ ] Round 1: all 5 whole-team teaching sessions, as soon as each section works
- [ ] Round 2: partner explain-backs for every section you didn't build
- [ ] Round 3: at least 2 random drills, including the full rehearsal
- [ ] Every box in the readiness tracker checked for every person before demo day
- [ ] Log AI uses as they happen
- [ ] Write the team reflection after testing is done
- [ ] Each person writes short P1 and P2 reflections
- [ ] Mention all reflection files in the README and include them in the Canvas submission
