# BoothCam: Webcam Photo Booth — Process Management Project 3

A Photo Booth–style macOS app: live webcam feed, a filter applied to it, and a still you can
snap and compare. Built to show how an app reaches a physical device through the operating
system, and what each layer in between is responsible for.

> **Due: Thursday 5 November, in class.** Learning session and random drill: Thursday 29 October,
> 9:35–10:55.
>
> **Status:** the app is feature-complete — live video, filter, snap and the filtered still all
> work, and four of five Macs pass every check. What remains is write-up: the research record,
> the sources list, and the contribution statement. Sections marked _TODO_ below name whose they
> are.

**Stack:** AVFoundation (capture) · Core Image (filters) · SwiftUI (window and UI)

---

## Requirements

- macOS **15.8** or later (`MACOSX_DEPLOYMENT_TARGET = 15.8`)
- **Xcode 16.0 or later.** The project file is format `objectVersion = 77`, which older Xcode
  cannot open. The team runs 26.1 to 27.0, so everyone is fine
- A webcam — built-in or USB. `system_profiler SPCameraDataType` lists what macOS sees

The app uses **Swift 5 language mode** (`SWIFT_VERSION = 5.0`), unlike projects 1 and 2 which
ran Swift 6. Worth knowing if you are comparing concurrency behaviour across the three.

## Build & run

```bash
git clone https://github.com/emadalin/Process-Management-Project1.git
open Process-Management-Project1/project3/BoothCam/BoothCam.xcodeproj
```

Then **⌘R** in Xcode. From the command line:

```bash
cd project3/BoothCam
xcodebuild -project BoothCam.xcodeproj -scheme BoothCam -configuration Debug build
```

**Signing:** `CODE_SIGN_STYLE = Automatic` with **no `DEVELOPMENT_TEAM` set**, so Xcode signs
it to run locally on each machine. Nobody needs to pick a team, and nobody's Apple ID is baked
into the project.

## Permissions

The first time the app touches the camera, macOS shows a prompt. Two things make that work, and
both are **build settings** rather than a `.entitlements` file — Xcode 26 synthesizes the
entitlement at signing:

| Setting | Why |
|---|---|
| `INFOPLIST_KEY_NSCameraUsageDescription` | The sentence shown in the prompt. **Without it the app crashes** the instant it touches the camera — not a polite error |
| `ENABLE_RESOURCE_ACCESS_CAMERA = YES` | The `com.apple.security.device.camera` entitlement. A sandboxed app without it is refused whatever the user clicks |

Every other `ENABLE_RESOURCE_ACCESS_*` is `NO`, so the sandbox grants the camera and nothing
else. Confirm it reached the built app:

```bash
codesign -d --entitlements - --xml BoothCam.app | plutil -convert xml1 -o - -
```

To re-test the prompt from scratch:

```bash
tccutil reset Camera edu.samford.c335.BoothCam
```

Granted permission is also visible in **System Settings → Privacy & Security → Camera**.

## Device selection

`CameraManager` calls `AVCaptureDevice.default(for: .video)` and takes whatever macOS considers
the default. **We do not enumerate or choose** — if no device comes back the app reports
*"no camera found"* and stops, and if the input cannot be created it reports which device failed
and why.

Every Mac on the team that listed its cameras found **two** — a built-in camera and an iPhone
over Continuity — and on all of them `.default` returned the built-in one. So the behaviour is
consistent across five machines, but it is the system's choice rather than ours. An iPhone
waking nearby could change it, and the app would follow without saying so.

Letting the user pick from `AVCaptureDevice.DiscoverySession` is the obvious improvement and the
one we would make first.

## Controls

| Key | Action |
|---|---|
| Space | Snap a still |
| F | Toggle the filter / comparison view |
| I | Toggle invert (grayscale is the default) |
| ⌘Q | Quit — releases the camera |

## What you should see

```
LIVE ORIGINAL      |  LIVE FILTERED
CAPTURED ORIGINAL  |  CAPTURED FILTERED
```

The captured panels hold still while the live ones move. That is the point of the layout: the
still owns its own pixels rather than pointing at the live buffer.

---

## Project layout

```
project3/
  BoothCam/
    BoothCam.xcodeproj               project file — Member 1 only (see below)
    BoothCam/
      BoothCamApp.swift              app entry point                        (Sarah Rae)
      ContentView.swift              four-panel layout, keyboard shortcuts  (shared)
      CameraManager.swift            session, frames, cleanup               (Stephen)
      FrameFilter.swift              grayscale and invert                   (Calli)
      Assets.xcassets                app icon, accent colour
  docs/
    section2-device-stack.md         the stack, documented vs observed      (Sarah Rae)
    learning-reflection-plan.md      how we make the learning visible       (everyone)
    test-records/
      test-record-template.md        blank; copy to test-record-<name>.md
      test-record-sarah.md · -stephen.md · -georgia.md · -calli.md · -ella.md   one per Mac
    reflections/
      sarah.md · stephen.md · georgia.md · calli.md · ella.md   personal learning logs
      readiness-tracker.md           sign-off grid, the meeting and the drill
      ai-use-log.md                  what AI suggested, what we checked
      team-reflection.md             written together at the end
  teamTask.md                        roles, work order, demo timing, questions
  README.md                          this file
```

**Only Member 1 touches project settings.** The project uses Xcode's file-system synchronized
folders, so adding a `.swift` file to the folder adds it to the target automatically — no
project-file edit needed. That keeps `project.pbxproj` out of everyone's diffs, which matters
because it is the one file five people would otherwise collide in constantly.

---

## Known gotchas

Hit during setup, recorded so nobody loses time to them twice:

- **`@Published` needs an explicit `import Combine`** in this project. SwiftUI does not
  re-export it here, and the error does not name the real problem: *"static subscript
  'subscript(_enclosingInstance:wrapped:storage:)' is not available due to missing import of
  defining module 'Combine'"*
- **`.foregroundStyle(cond ? .secondary : .orange)` does not compile.** `.secondary` is a
  `HierarchicalShapeStyle` and `.orange` is a `Color`; write `Color.secondary` / `Color.orange`
- **There is no `Info.plist` file** to edit. The camera usage string lives in build settings, so
  looking for the file is a dead end
- **Xcode auto-stages files.** It staged `.DS_Store`, two submission zips and `xcuserdata/`
  without being asked. `.gitignore` does not help once a file is staged — check `git status`
  before committing

## Device stack

Full write-up: [`docs/section2-device-stack.md`](docs/section2-device-stack.md), with every
claim marked **documented** or **observed** and the command behind each observation.

The short version: BoothCam never speaks to the webcam. It asks AVFoundation, which is a client
of the CoreMediaIO camera service — `cameracaptured` and the driver daemons run in **separate
processes**, which `ps` confirms. There are **two** driver paths, not one chain:
`appleh13camerad` for the built-in camera and `UVCAssistant.systemextension` for USB webcams.
TCC sits beside the whole stack rather than inside it, gating whether any frame is delivered.

Measured with the camera live: `appleh13camerad` goes from 0.0% to 4.5% CPU, `UVCAssistant`
stays at 0.0% the whole time because no USB camera is attached, and quitting spikes
`appleh13camerad` to 29.8% as the device is released. The daemons do not start on demand — they
have been running since boot.

One finding the team needs: this Mac reports **two** cameras — the FaceTime HD camera and an
iPhone over Continuity. `AVCaptureDevice.default(for: .video)` may not pick the one you are
looking at, so **every test record must say which camera it used**.

## Test records

One per Mac, five in total. Template: [`docs/test-record-template.md`](docs/test-records/test-record-template.md).

**Four of five Macs pass all checks.** Every machine ran the app from its own build — nobody
copied a working binary across.

| Member | Record | macOS | Live | Filter | Snap | Filtered still | Quit releases camera |
|---|---|---|---|---|---|---|---|
| Sarah Rae | [record](docs/test-records/test-record-sarah.md) | 15.8.1 | ✅ | ✅ | ✅ | ✅ | ✅ |
| Stephen | [record](docs/test-records/test-record-stephen.md) | 26.5.2 | ✅ | ✅ | ⬜ | ⬜ | ⬜ |
| Georgia | [record](docs/test-records/test-record-georgia.md) | 26.6.2 | ✅ | ✅ | ✅ | ✅ | ✅ |
| Calli | [record](docs/test-records/test-record-calli.md) | 26.6.2 | ✅ | ✅ | ✅ | ✅ | ✅ |
| Ella | [record](docs/test-records/test-record-ella.md) | 26.5.1 | ✅ | ✅ | ✅ | ✅ | ✅ |

Stephen's three blanks are honest rather than missing: he tested before Georgia's snap landed,
and his quit test got tangled with a debugger-attached process. Needs one clean redo.

**macOS spread: 15.8.1 to 26.6.2.** Sarah's is the oldest, which is why the deployment target is
15.8 — the oldest Mac sets the floor and it blocks nobody.

**Every Mac that reported its cameras found two** — a built-in camera and an iPhone over
Continuity — and on every one of them `AVCaptureDevice.default(for: .video)` chose the built-in.
Worth knowing before the demo: an iPhone waking nearby can change what `.default` returns.

### Screenshots

All four panels, per person: [`docs/screenshots/`](docs/screenshots/).

| Member | Files |
|---|---|
| Sarah Rae | `sarah-window-all-four-panels.png`, `sarah-permission-denied.png` |
| Calli | `calli-all-panels.png` |
| Ella | `ella-window-1.png` … `ella-window-4.png` |
| Stephen, Georgia | _not yet committed_ |

## Research & troubleshooting record

Drawn from the five test records and [`ai-use-log.md`](docs/reflections/ai-use-log.md). The
full detail for each problem is in the record named next to it.

### Sources

Apple's developer documentation, every link fetched and confirmed on 2026-10-22. The full table,
with which claim each one supports, is in
[`section2-device-stack.md`](docs/section2-device-stack.md#sources).

| Source | Used for |
|---|---|
| [AVCaptureSession](https://developer.apple.com/documentation/avfoundation/avcapturesession), [AVCaptureDevice](https://developer.apple.com/documentation/avfoundation/avcapturedevice), [AVCaptureVideoDataOutput](https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput) | Opening the camera, picking the device, getting each frame |
| [Requesting authorization to capture and save media](https://developer.apple.com/documentation/avfoundation/requesting-authorization-to-capture-and-save-media), [NSCameraUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nscamerausagedescription) | The permission check and the prompt text |
| [CIImage](https://developer.apple.com/documentation/coreimage/ciimage) | Filters, and why the still has to be rendered to get its own copy |
| [Core Media I/O](https://developer.apple.com/documentation/coremediaio) | The layer under AVFoundation, for the device-stack diagram |

### What we adapted

- **Permission setup.** The usual advice is to edit `Info.plist` and a `.entitlements` file.
  Neither file exists in Xcode 26, so we used the matching build settings instead and checked the
  result with `codesign` (Sarah, Problem 2).
- **AI-written camera code.** The first `CameraManager` from Claude Code did not compile until we
  added `import Combine` (Sarah, Problem 1).
- **Measuring the camera daemons.** `ps` was suggested first but hides short bursts of CPU, so we
  switched to `top -l 2` (Sarah, Problem 4).

### Problems by category

| Category | Problem | Fix | Record |
|---|---|---|---|
| Install | `.gitignore` did not stop Xcode's auto-staged files | `git rm --cached` on each file | Sarah, 3 |
| Install | `xcodebuild` failed in Terminal: the active developer directory was the Command Line Tools, not Xcode | Point `DEVELOPER_DIR` (or `xcode-select -s`) at Xcode.app | Georgia, 1 |
| Install | `@Published` would not compile, and the error never mentioned it | `import Combine` | Sarah, 1 |
| Install | App stopped responding and survived `kill -9` because Xcode's debugger still held it | Stop it from inside Xcode (⌘.) | Stephen, 2 |
| Permissions | No `Info.plist` or `.entitlements` file to put the camera key in | Build settings `INFOPLIST_KEY_NSCameraUsageDescription` and `ENABLE_RESOURCE_ACCESS_CAMERA` | Sarah, 2 |
| Permissions | `tccutil reset` did not bring the prompt back on Stephen's Mac (it did on Ella's) | Turn the permission off in System Settings instead | Stephen, 1 |
| Device selection | Every Mac sees two cameras (built-in and an iPhone over Continuity) and the app cannot choose | No fix needed so far: every Mac got the built-in camera. Note which camera each test used | All |
| Frame acquisition | `ps` made the camera daemons look idle while frames were flowing | Measure with `top -l 2` | Sarah, 4 |
| Display / image format | None hit | | |

Calli and Ella needed no special fixes. Every problem we hit was in setup or tooling, not in the
app itself.

### Error cases tested

| Case | Result | Tested on |
|---|---|---|
| Permission denied | Clear message naming the fix, no crash | Sarah, Ella |
| Snap before any frame | *"No frame yet — wait for the live feed, then snap."*, no crash | Sarah, Georgia, Calli |
| No camera available | Not tested on any Mac | |

### AI use

Claude Code was used by Sarah (project setup and the device-stack research), Stephen and
Georgia (diagnosing setup problems), and Ella (gathering environment info and filling in the
test record). Each row in [`ai-use-log.md`](docs/reflections/ai-use-log.md) says what was
suggested and how we checked it. It was wrong or incomplete five times: the missing
`import Combine`, files that do not exist in Xcode 26, `.gitignore` advice that did not unstage
files, camera daemons it said would start on demand (they run from boot), and `ps` as a
measuring tool. Every claim was checked by building, running, or measuring on our own Macs.

## Strengths, limitations, and one improvement

**Strengths**
- Built from source and run on all five Macs, macOS 15.8.1 to 26.6.2. Nobody copied a working
  build across.
- The errors we tested fail cleanly. A denied permission and a snap before any frame both show a
  message that says what is wrong, and the app stays open.
- The captured still really is a copy. When we waved at the camera after snapping, the captured
  panels stayed still, and every screenshot shows the captured panels at a different moment from
  the live ones.
- Quitting releases the camera: the indicator light goes off on ⌘Q.

**Limitations**
- **We don't choose the camera.** `AVCaptureDevice.default(for: .video)` lets macOS pick.
  It picked the built-in camera on every Mac, but an iPhone nearby could change that without the
  app noticing.
- **The app uses about ten times the CPU the camera does** (about 41% against 4.4% on Sarah's Mac),
  because `ContentView` renders four separate images every frame.
- **Capture sometimes stopped when the window was fully covered** (seen once on Sarah's Mac).
  Our guess is that macOS slows down hidden windows, but we haven't tested it on purpose.
- **Snap's message is wrong when permission is denied.** It says to wait for the live feed,
  which will never arrive.
- **Not fully tested.** Nobody tested "no camera available", and Stephen's snap and quit checks
  still need a clean redo.

**One improvement with more time:** let the user pick the camera from a list built with
`AVCaptureDevice.DiscoverySession`, and show the chosen camera's name in the window. That fixes
the biggest gap above: right now the system picks the camera without telling the user.

## Learning & reflection

The professor draws presenters at random on the day, so every member has to be able to present
every section. [`docs/learning-reflection-plan.md`](docs/learning-reflection-plan.md) sets out
how we get there, and [`docs/reflections/`](docs/reflections/) holds the work:

| File | What it is | Effort |
|---|---|---|
| `sarah.md`, `stephen.md`, `georgia.md`, `calli.md`, `ella.md` | Personal learning log, each in that person's own words | one page |
| [`readiness-tracker.md`](docs/reflections/readiness-tracker.md) | Sign-off grid, plus the meeting and the drill | four boxes each |
| [`ai-use-log.md`](docs/reflections/ai-use-log.md) | What AI suggested, what we checked, where it was wrong | one row |
| [`team-reflection.md`](docs/reflections/team-reflection.md) | One shared reflection at the end | one paragraph each |

**Booked: Thursday 29 October, 9:35–10:55, in class** — the teaching session and the random
drill both fit in that slot. Agenda is in the plan.

A readiness box is only ticked by a **teammate** who heard you explain the section with no notes
and answer a "what if" question. Total cost per person is about **75 minutes**, most of it a
60-minute team meeting we need anyway.

## Team contribution statement

_TODO — Sarah Rae collects. 3–5 sentences from each member, plus how we made sure everyone can
explain the whole app._

**Ella Madalinski (Member 5)** owns testing, troubleshooting and the research record, and
presents demo sections 4 and 5. I built and ran BoothCam on my own Mac and completed its test
record: all five feature checks, the permission prompt, and the permission-denied error case,
with screenshots. I'm collecting the test records from all five Macs and running the app with
each teammate to sort any setup problems by type. I'm also writing the research and
troubleshooting record, including how the team used AI and how we checked it. I used Claude
Code to help fill in my test record, and I confirmed every result on my own machine.

## Sources

_TODO — Sarah Rae collects, including AI assistants and what each was used for, matching how
projects 1 and 2 disclosed it._
