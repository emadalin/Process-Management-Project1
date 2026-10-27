# Ella — Project 3 Learning Log

**I built:** testing and the research record (section 4)
**I may be asked to present:** any of the five sections.

> Your own words, short. Two sentences per answer is fine. AI can explain a concept to you; it
> does not write this. If it helped, say so at the bottom.

---

## My part

**What I built, and the OS concept behind it** — not what the code does, but what it shows about
how the operating system works: I was in charge of the testing. The OS concept is that an app never talks to the camera directly. The OS sits between the two and acts as a gate that decides what the app is allowed to use. For example, the camera permissions is the first thing to pop up when you build and run BoothCam because BoothCam wasn't on MacOS's list of apps that are allowed to use the camera. The popup was from MacOS, but the line saying "BoothCam shows your webcam..." is the only part provided by BoothCam. If the user clicks don't allow, then the OS doesn't allow BoothCam to access the camera, so the app had to adjust with the line that said why the camera wasn't working and how to change the permissions in settings. Additionally, the Mac listed two cameras: the built-in one and your iPhone through Continuity Camera. BoothCam asked for the default camera, so macOS picked the built-in one. The app didn't search for the hardware itself; the OS is in charge of the list of devices. Finally, when the user presses command-Q, the app released the camera and the OS took it back, so the green light by the camera went off. 

**One thing I got wrong at first, and how I found out:**

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

10-27: used Claude Code to pull changes, collect my Mac's version and camera info, and fill in
`../test-records/test-record-ella.md` from what I reported. I ran every check myself, including watching the
camera light go off on quit, which Claude had ticked before I confirmed it. I first gave the
app's "permission denied" message as the prompt wording; I reset permission with `tccutil` and
confirmed the real system prompt from a screenshot.

(Also add a row to [`ai-use-log.md`](ai-use-log.md).)

---

## Looking back

**The OS concept I understand much better now:**

**How this connects to threads (Project 1) and memory (Project 2):**
