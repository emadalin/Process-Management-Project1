# Test Record — BoothCam

Owner of the collected records: Member 5 (Ella). One filled-in copy per Mac, five in total.

**How to use this:** copy this file to `docs/test-record-<yourname>.md`, fill it in on your own
machine, commit it. Do not edit this template — it is the blank.

Fill it in **as you go**, not afterwards. The troubleshooting section is worth more than the
checkmarks, and nobody remembers the fix two days later.

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
| Name (member #) | Calli Nash (Member 4) |
| macOS | 26.6.2 (build 25G83) |
| Architecture | arm64 |
| Swift | Apple Swift 6.2.3 (swiftlang-6.2.3.3.21), project builds in Swift 5 mode |
| Xcode | 26.2 (build 17C52) |
| Camera model (from `SPCameraDataType`) | FaceTime HD Camera; also "Calli Camera" (iPhone17,3, Continuity Camera) |
| Built-in or USB | Built-in, plus an iPhone over Continuity Camera (wireless, not USB) |
| Date tested | 2026-10-22 |

Raw output:

```
$ sw_vers
ProductName:		macOS
ProductVersion:		26.6.2
BuildVersion:		25G83

$ uname -m
arm64

$ swift --version
swift-driver version: 1.127.14.1 Apple Swift version 6.2.3 (swiftlang-6.2.3.3.21 clang-1700.6.3.2)
Target: arm64-apple-macosx26.0

$ xcodebuild -version
Xcode 26.2
Build version 17C52

$ system_profiler SPCameraDataType
Camera:

    FaceTime HD Camera:

      Model ID: FaceTime HD Camera
      Unique ID: 1FD4B3A2-236E-492B-8CE5-255DD288CE50

    Calli Camera:

      Model ID: iPhone17,3
      Unique ID: E66642D4-138E-4E9B-91AE-8B2E00000001
```

Two cameras are visible, so `AVCaptureDevice.default(for: .video)` could pick either one. Note
which one the LIVE ORIGINAL panel actually shows when testing (see README, Device selection).

Build: `xcodebuild -project BoothCam.xcodeproj -scheme BoothCam -configuration Debug build`
gave **BUILD SUCCEEDED** with no errors, on the scaffold at commit `3011dda`.

## 2. Permission

| Step | Result |
|---|---|
| Prompt appeared on first camera use | yes |
| Exact wording shown in the prompt | Title: "“BoothCam” would like to access the Camera." Body: "BoothCam shows your webcam so you can take and filter photos." (the body is our `INFOPLIST_KEY_NSCameraUsageDescription` string) |
| Listed under System Settings → Privacy & Security → Camera | yes |

If no prompt appeared, say what you saw instead — that is a finding, not a failure.

## 3. The five feature checks

Tick only what you saw with your own eyes on your own Mac.

| # | Check | Pass | Notes |
|---|---|---|---|
| 1 | **Live feed** — LIVE ORIGINAL shows moving video | ☑ | FaceTime HD Camera (built-in), picked over the iPhone Continuity Camera that macOS also lists |
| 2 | **Live filter** — LIVE FILTERED differs from the original, and tracks it | ☑ | |
| 3 | **Snap** — pressing Space captures a still | ☑ | |
| 4 | **Filtered still** — CAPTURED FILTERED matches the filter applied to the still, and the captured panel does **not** change when you move | ☑ | |
| 5 | **Normal quit** — ⌘Q closes the app and the camera indicator light goes **off** | ☑ | |

Check 4 is the one that catches the copy-vs-reference bug: wave at the camera after snapping.
If the captured panel moves, the still is holding the live buffer instead of its own copy.

Check 5 is the one people forget. Watch the light, not the window.

## 4. Error cases

At least one, more if you hit them. Record what you did and what the app did.

| Case | How you caused it | What the app did | Crashed? |
|---|---|---|---|
| Permission denied | `tccutil reset Camera edu.samford.c335.BoothCam`, then click **Don't Allow** | | |
| No camera available | e.g. unplug the USB cam, or Screen Sharing holding it | | |
| Snap before any frame | press Space immediately on launch, before the live feed appears | showed "No frame yet - wait for the live feed, then snap." | no |
| | | | |

A clear message is a pass. A crash is a fail, even if the feature works otherwise.

## 5. Troubleshooting log

One entry per problem, however small. "No special fixes needed" is a valid whole section, but
say so explicitly rather than leaving it blank.

No special fixes needed. The project built and ran first time on this Mac, with no install,
permission, device or display problems.

## 6. Screenshots

Four per person, labelled, with your name in the filename:
`docs/screenshots/<yourname>-live-original.png`, `-live-filtered`, `-captured-original`,
`-captured-filtered`. One window shot with all four panels visible also works — say which you
did.

One window shot with all four panels visible, grayscale mode, filter on.

| Screenshot | Committed | Filename |
|---|---|---|
| Live original | ☑ | `../screenshots/calli-all-panels.png` (top left) |
| Live filtered | ☑ | `../screenshots/calli-all-panels.png` (top right) |
| Captured original | ☑ | `../screenshots/calli-all-panels.png` (bottom left) |
| Captured filtered | ☑ | `../screenshots/calli-all-panels.png` (bottom right) |

## 7. Limitations you noticed on this Mac

Anything that worked but not well: frame rate with the filter on, lag on snap, a camera that
takes seconds to warm up, resolution differences. Say whether it is **observed** (you saw it) or
**documented** (you read it).

**Filter cost: BoothCam's CPU use** (observed, Activity Monitor % CPU, FaceTime HD Camera,
live feed running)

| Setting | % CPU |
|---|---|
| Filter on, grayscale | 77–82% |
| Filter off (**F**) | 45–50% |
| Filter on, invert (**I**) | 77–84% |

- Turning the filter on adds about **30 percentage points** of CPU. Grayscale and invert cost about
  the same.
- That difference is not only the filter maths. **F** hides the two filtered panels completely, so
  "off" also skips rendering those two panels (`createCGImage`) and drawing them on screen. The
  30 points is the cost of the whole filtered column, not of `CIPhotoEffectMono` alone.
- Even with the filter off, BoothCam uses about 45–50% CPU just to show the live feed and the
  captured still.

**Responsiveness and quality** (observed, by eye)

- With the filter on, LIVE FILTERED moved smoothly with no visible stutter or lag behind LIVE
  ORIGINAL. The extra CPU did not show up as a slower picture.
- The grayscale looked like a normal black-and-white photo. Nothing looked wrong with contrast or
  dark areas.

## 8. Can you explain the whole app?

The ground rule is that anyone can be asked about any part. Tick honestly — an untick here is
information for the rehearsal, not a mark against you.

| | Confident | Explain it to me first |
|---|---|---|
| Which call opens the camera, and what its result tells you | ☐ | ☐ |
| How a frame gets from the device to the screen | ☐ | ☐ |
| Why the captured still does not change with the live feed | ☐ | ☐ |
| What grayscale does to the pixel data | ☐ | ☐ |
| Where camera resources are released, and why it matters | ☐ | ☐ |
