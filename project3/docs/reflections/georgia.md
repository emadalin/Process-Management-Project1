# Georgia — Project 3 Learning Log

**I built:** snap / still capture (section 3b)

**I may be asked to present:** any of the five sections.

When you press Space the current frame of the live feed is copied into its own memory and shown on the captured panel. The saved photo will stay frozen while the live feed will continue to move.

---

## My part

**What I built, and the OS concept behind it** — not what the code does, but what it shows about
how the operating system works:

The OS concept is copying data vs holding a reference to reused memory. That means that the snap is copying the memory from the camera and remembers it until the next snap, then it erases that and replaces it with new memory.


---

## Everyone else's parts

Two sentences each, written during or right after the team meeting. Aim for the **concept**, not
a description of the code.

- **Device stack** — I/O layers, abstraction *(Sarah)*:

- **Camera & cleanup** — permissions, resource release, background queues *(Stephen)*:

- **Snap** — copying vs. holding a reference to a reused buffer *(Georgia)*:

- **Filter** — how pixels are stored, where the work runs *(Calli)*:

- **Testing** — how OS version, permissions and hardware change behaviour *(Ella)*:

**The section that took me longest to get, and what made it click:**

---

## The drill

**Section I was drawn for, and how it went:**

---

## AI use

**What I asked, what I checked, and what was wrong or missing:**
I used Claude Code to pull and build the project, set up my test record, write `snap()`, and explain the code and OS concepts to me. I checked `snap()` by running the app myself: the wave test (the CAPTURED panel stayed still while I moved), pressing Space before the camera started ("No frame yet", no crash), and quitting to see the camera light go off. It first added a Save to PNG button that the app's sandbox would have blocked, so I had it removed, and my first explanation of the OS concept said the camera made the copy until checking the code showed it is `snap()` that copies.

*(This AI use section was drafted by Claude Code from what happened in my sessions.)*

(Also add a row to [`ai-use-log.md`](ai-use-log.md).)

---

## Looking back

**The OS concept I understand much better now:**

**How this connects to threads (Project 1) and memory (Project 2):**
