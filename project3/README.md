# BoothCam: Webcam Photo Booth — Process Management Project 3

A Photo Booth–style macOS app: live webcam feed, a filter applied to it, and a still you can
snap and compare. Built to show how an app reaches a physical device through the operating
system, and what each layer in between is responsible for.

> **Status:** project scaffolded and building; camera permission and entitlement declared.
> Live video, snap and the filters are stubs — see the owner named in each file. Sections
> marked _TODO_ below name whose they are.

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

`AVCaptureDevice.default(for: .video)` takes whatever macOS considers the default camera. On a
laptop with a USB webcam plugged in, that may not be the one you expect — note which camera your
test record used. _TODO — Stephen: say what the code does when there is more than one._

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
    test-record-template.md          blank; copy to test-record-<name>.md   (Ella collects)
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

One per Mac, five in total. Template: [`docs/test-record-template.md`](docs/test-record-template.md).

| Member | Record | Live | Filter | Snap | Filtered still | Quit releases camera |
|---|---|---|---|---|---|---|
| Sarah Rae | _TODO_ | | | | | |
| Stephen | _TODO_ | | | | | |
| Georgia | _TODO_ | | | | | |
| Calli | _TODO_ | | | | | |
| Ella | _TODO_ | | | | | |

## Research & troubleshooting record

_TODO — Ella (demo section 4). Sources, what we adapted, problems by category with fixes, and
AI use with how we checked it._

## Strengths, limitations, and one improvement

_TODO — Ella (demo section 5)._

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

A readiness box is only ticked by a **teammate** who heard you explain the section with no notes
and answer a "what if" question. Total cost per person is about **75 minutes**, most of it a
60-minute team meeting we need anyway.

## Team contribution statement

_TODO — Sarah Rae collects. 3–5 sentences from each member, plus how we made sure everyone can
explain the whole app._

## Sources

_TODO — Sarah Rae collects, including AI assistants and what each was used for, matching how
projects 1 and 2 disclosed it._
