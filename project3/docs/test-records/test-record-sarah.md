# Test Record — BoothCam · Sarah Rae (Member 1)

Hand this to Ella (Member 5), who collects all five.

**Tested against:** `47c32de` — all four parts are in: live video (Stephen), filters (Calli),
snap (Georgia).

---

## 1. Environment

Run these and paste the output:

```bash
sw_vers                              # macOS version + build
uname -m                             # arm64 or x86_64
swift --version                      # toolchain
xcodebuild -version                  # Xcode
system_profiler SPCameraDataType     # the camera itself
```

| Field | Value |
|---|---|
| Name (member #) | Sarah Rae (Member 1) |
| macOS | 15.8.1 (build 24H32) |
| Architecture | arm64 (Apple M2) |
| Swift | Apple Swift 6.2.1 (swiftlang-6.2.1.4.8); project builds in Swift 5 mode |
| Xcode | 26.1.1 (build 17B100) |
| Camera model (from `SPCameraDataType`) | FaceTime HD Camera; also "iPhone (8) Camera" (iPhone18,1, Continuity) |
| Built-in or USB | Built-in, plus an iPhone over Continuity (wireless, not USB) |
| Date tested | 2026-10-27 |

**Note:** mine is the **oldest macOS on the team** (15.8.1 against everyone else's 26.x), which
is why the project's deployment target is 15.8 — the oldest Mac sets the floor.

## 2. Permission

| Step | Result |
|---|---|
| Prompt appeared on first camera use | **yes** |
| Exact wording shown in the prompt | **"BoothCam" would like to access the camera.** / *BoothCam shows your webcam so you can take and filter photos.* |
| Listed under System Settings → Privacy & Security → Camera | **yes** |

If no prompt appeared, say what you saw instead — that is a finding, not a failure.

**Worth noting:** the second line is **verbatim** the string we set in
`INFOPLIST_KEY_NSCameraUsageDescription`. macOS writes the first line; the sentence explaining
*why* is ours. That is the whole reason the key exists, and why an app without it is killed
rather than warned — without our sentence the system has nothing to show the user.

## 3. The five feature checks

Tick only what you saw with your own eyes on your own Mac.

| # | Check | Pass | Notes |
|---|---|---|---|
| 1 | **Live feed** — LIVE ORIGINAL shows moving video | ☑ | Moving video straight away. Confirmed independently from the process side: `appleh13camerad` ran at 4.4% while frames flowed, 0.0% with the app closed |
| 2 | **Live filter** — LIVE FILTERED differs from the original, and tracks it | ☑ | Grey, and tracks movement with no visible lag |
| 3 | **Snap** — pressing Space captures a still | ☑ | Space captured a still and it appeared in both CAPTURED panels — the original and the filtered copy |
| 4 | **Filtered still** — CAPTURED FILTERED matches the filter applied to the still, and the captured panel does **not** change when you move | ☑ | Snapped, then waved: motion appeared **only** in the two LIVE panels. Both CAPTURED panels stayed frozen on the snapped frame — the still owns its own pixels, not a reference into the live buffer pool |
| 5 | **Normal quit** — ⌘Q closes the app and the camera indicator light goes **off** | ☑ | ⌘Q closed the app and the camera indicator light went off. The device is released, not left held |

Check 4 is the one that catches the copy-vs-reference bug: wave at the camera after snapping.
If the captured panel moves, the still is holding the live buffer instead of its own copy.

Check 5 is the one people forget. Watch the light, not the window.

## 4. Error cases

At least one, more if you hit them. Record what you did and what the app did.

| Case | How you caused it | What the app did | Crashed? |
|---|---|---|---|
| Permission denied | `tccutil reset Camera edu.samford.c335.BoothCam`, relaunch, click **Don't Allow** | Stayed open. Orange status line: *"camera permission denied — enable it in System Settings → Privacy & Security → Camera"* — it names the problem **and** where to fix it. Panels read "waiting for the first frame" | **No** |
| Snap before any frame | pressed Space while permission was denied, so no frame had ever arrived | Red message: *"No frame yet — wait for the live feed, then snap."* The capture was refused rather than attempted | **No** |
| No camera available | not tested | | |

Screenshot: [`screenshots/sarah-permission-denied.png`](../screenshots/sarah-permission-denied.png)

**One thing worth improving.** With permission denied, the snap message says *"wait for the live
feed, then snap"* — but the live feed is never going to arrive, because the camera was refused.
The advice is wrong for this particular state. Both messages are individually correct; shown
together they slightly contradict each other. A small fix would be for snap to defer to the
permission error when there is one.

A clear message is a pass. A crash is a fail, even if the feature works otherwise.

## 5. Troubleshooting log

Four problems hit while setting the project up. All four are also in
[`reflections/ai-use-log.md`](../reflections/ai-use-log.md), since AI was involved in each.

### Problem 1 — `@Published` would not compile

- **Symptom:** build failed with *"static subscript
  'subscript(_enclosingInstance:wrapped:storage:)' is not available due to missing import of
  defining module 'Combine'"*. The error never mentions `@Published`, which is what made it hard
  to read.
- **Category:** install / build
- **What I checked:** the imports in `CameraManager.swift` — `AVFoundation`, `CoreImage` and
  `SwiftUI` were all there. Assumed SwiftUI re-exported Combine. It does not, here.
- **What fixed it:** adding `import Combine`.
- **How I confirmed it:** rebuilt — succeeded, and has every build since.
- **Who helped:** found with Claude Code, which had written the file without the import.

### Problem 2 — there is no `Info.plist` to put the camera key in

- **Symptom:** the task sheet says to add `NSCameraUsageDescription` to `Info.plist`. No such
  file exists in the project.
- **Category:** permissions
- **What I checked:** looked through the project folder and the Xcode navigator. Also looked for
  a `.entitlements` file to tick the sandbox Camera box in — that does not exist either.
- **What fixed it:** both are **build settings** in Xcode 26, not files:
  `INFOPLIST_KEY_NSCameraUsageDescription` and `ENABLE_RESOURCE_ACCESS_CAMERA`. Xcode generates
  the `Info.plist` and synthesizes the entitlement at signing.
- **How I confirmed it:** `codesign -d --entitlements - --xml BoothCam.app` on the built app
  reported `com.apple.security.device.camera`, and the permission prompt later showed our usage
  string word for word.
- **Who helped:** Claude Code suggested editing the files; checking showed the files were not
  there, which is how we found the build-settings route.

### Problem 3 — `.gitignore` did not stop files being committed

- **Symptom:** `.DS_Store`, two submission zips and `xcuserdata/` showed as **staged** in
  `git status`, even after adding them to `.gitignore`.
- **Category:** install / repo setup
- **What I checked:** `git status` before and after editing `.gitignore`. No change.
- **What fixed it:** `git rm --cached` on each. `.gitignore` only applies to files git is not
  already tracking, and Xcode had staged them without being asked.
- **How I confirmed it:** `git check-ignore -v` on the paths, plus a clean `git status`.
- **Who helped:** Claude Code suggested the `.gitignore` entries; the staging was spotted by
  reading `git status` rather than trusting them.

### Problem 4 — measuring with a tool that hid the thing being measured

- **Symptom:** measuring the camera daemons' CPU with `ps` showed 0.0% → 0.1% when the camera
  started, which looked like nothing happening.
- **Category:** frame acquisition / investigation method
- **What I checked:** whether frames really were flowing. They were — the app showed live video.
- **What fixed it:** `ps` reports a **decaying lifetime average**, and these daemons have been
  running since boot, so a few seconds of real work averages away to nothing. `top -l 2` takes
  an instantaneous sample.
- **How I confirmed it:** `top` showed `appleh13camerad` at **4.5%** live and **29.8%** during
  teardown, against 0.0% idle — a signal large enough to be obvious.
- **Who helped:** Claude Code suggested `ps` first; the numbers looking wrong is what prompted
  the change of tool.

### No further problems

The app itself ran first time on this Mac: no issues with device selection, frame acquisition,
or image format. Every problem above was setup or tooling, not the program.

## 6. Screenshots

Four per person, labelled, with your name in the filename:
`docs/screenshots/<yourname>-live-original.png`, `-live-filtered`, `-captured-original`,
`-captured-filtered`. One window shot with all four panels visible also works — say which you
did.

One window shot covering all four panels:
[`screenshots/sarah-window-all-four-panels.png`](../screenshots/sarah-window-all-four-panels.png)

| Screenshot | Committed | Filename |
|---|---|---|
| Live original | ☑ | `sarah-window-all-four-panels.png` (top left) |
| Live filtered | ☑ | same shot (top right) |
| Captured original | ☑ | same shot (bottom left) |
| Captured filtered | ☑ | same shot (bottom right) |

**This one image also evidences check 4.** The LIVE panels show a neutral expression and the
CAPTURED panels show a smile — two different moments in the same frame. The still stayed frozen
on the snapped frame while the live feed carried on, which is what "the capture owns its own
pixels" looks like from the outside. Also visible: status `live`, `Filter: on`,
`Mode: grayscale`, and the filtered column genuinely grey rather than a dimmed copy.

## 7. Limitations you noticed on this Mac

**Which camera we got, and how we know (observed).** `AVCaptureDevice.default(for: .video)`
selected the **built-in FaceTime HD camera**, not the iPhone this Mac also offers over
Continuity. Determined without looking at the picture: while the app ran,
`appleh13camerad` sat at 4.4% CPU while `avconferenced` (Continuity) and `UVCAssistant` (USB)
both stayed at 0.0%. Which daemon wakes up identifies which camera is in use.

**Capture sometimes stops when the app is not in front (observed, mechanism not established).**
Once, with Messages frontmost, both BoothCam and `appleh13camerad` dropped to **0.0%** CPU —
frames stopped arriving, not just drawing. Measured twice seconds apart, so not a transient.

**But it does not always happen.** Later, with the terminal frontmost and BoothCam behind it,
capture carried on normally — BoothCam at 61.6% and `appleh13camerad` at 4.2%. So simply not
being the active app is **not** the trigger.

The difference we noticed between the two runs is whether the window was **fully covered** or
still partly visible, which fits macOS throttling occluded windows rather than backgrounded
ones (**inferred — we did not test it deliberately**). Worth re-running on purpose before the
demo: fully cover the window, then leave it visible but unfocused, and see which one stops it.

**The app costs far more than the camera does (observed).** BoothCam ran at **~41%** CPU
against the camera driver's 4.4% — roughly ten times. That is not capture cost: `ContentView`
renders four separate `CGImage`s per frame through `CIContext`. Drawing the `CIImage` directly,
or only rendering the panels that are visible, would be the obvious fix.

Anything that worked but not well: frame rate with the filter on, lag on snap, a camera that
takes seconds to warm up, resolution differences. Say whether it is **observed** (you saw it) or
**documented** (you read it).

## 8. Can you explain the whole app?

> **Not filled in yet — deliberately.** These are honest self-assessments, and the team teaching
> meeting has not happened. Ticking them now would defeat the point of the readiness tracker.
> To be completed after the meeting; see
> [`learning-reflection-plan.md`](../learning-reflection-plan.md).


The ground rule is that anyone can be asked about any part. Tick honestly — an untick here is
information for the rehearsal, not a mark against you.

| | Confident | Explain it to me first |
|---|---|---|
| Which call opens the camera, and what its result tells you | ☐ | ☐ |
| How a frame gets from the device to the screen | ☐ | ☐ |
| Why the captured still does not change with the live feed | ☐ | ☐ |
| What grayscale does to the pixel data | ☐ | ☐ |
| Where camera resources are released, and why it matters | ☐ | ☐ |
