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
| Name (member #) | Ella Madalinski (Member 5) |
| macOS | 26.5.1 (build 25F80) |
| Architecture | arm64 |
| Swift | Apple Swift 6.3.3 (swiftlang-6.3.3.1.3) |
| Xcode | 26.6 (build 17F113) |
| Camera model (from `SPCameraDataType`) | MacBook Pro Camera; also "iPhone Camera" (iPhone16,1, Continuity Camera) |
| Built-in or USB | Built-in, plus an iPhone over Continuity Camera (wireless, not USB) |
| Date tested | 2026-10-27 |

Raw output:

```
$ sw_vers
ProductName:		macOS
ProductVersion:		26.5.1
BuildVersion:		25F80

$ uname -m
arm64

$ swift --version
swift-driver version: 1.148.6 Apple Swift version 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101)
Target: arm64-apple-macosx26.0

$ xcodebuild -version
Xcode 26.6
Build version 17F113

$ system_profiler SPCameraDataType
Camera:

    MacBook Pro Camera:

      Model ID: MacBook Pro Camera
      Unique ID: 6C707041-05AC-0011-0008-000000000001

    iPhone Camera:

      Model ID: iPhone16,1
      Unique ID: 1E3DC830-506C-40C6-8F7D-616400000001
```

Two cameras are visible, so `AVCaptureDevice.default(for: .video)` could pick either one. Note
which one the LIVE ORIGINAL panel actually shows when testing (see README, Device selection).

Build: `xcodebuild -project BoothCam.xcodeproj -scheme BoothCam -configuration Debug build`
gave **BUILD SUCCEEDED** with no errors, at commit `ddb3beb`.

## 2. Permission

| Step | Result |
|---|---|
| Prompt appeared on first camera use | yes |
| Exact wording shown in the prompt | "“BoothCam” would like to access the Camera." / "BoothCam shows your webcam so you can take and filter photos." (buttons: Don't Allow, Allow) — the second line is our `NSCameraUsageDescription` |
| Listed under System Settings → Privacy & Security → Camera | yes |

If no prompt appeared, say what you saw instead — that is a finding, not a failure.

## 3. The five feature checks

Tick only what you saw with your own eyes on your own Mac.

| # | Check | Pass | Notes |
|---|---|---|---|
| 1 | **Live feed** — LIVE ORIGINAL shows moving video | ✅ | Showed the built-in MacBook Pro Camera, not the iPhone (Continuity Camera) |
| 2 | **Live filter** — LIVE FILTERED differs from the original, and tracks it | ✅ | |
| 3 | **Snap** — pressing Space captures a still | ✅ | Tested after Georgia's snap landed (`89fb6ed`) |
| 4 | **Filtered still** — CAPTURED FILTERED matches the filter applied to the still, and the captured panel does **not** change when you move | ✅ | Waved after snapping, captured panel stayed still; filtered still turned gray |
| 5 | **Normal quit** — ⌘Q closes the app and the camera indicator light goes **off** | ✅ | |

Check 4 is the one that catches the copy-vs-reference bug: wave at the camera after snapping.
If the captured panel moves, the still is holding the live buffer instead of its own copy.

Check 5 is the one people forget. Watch the light, not the window.

## 4. Error cases

At least one, more if you hit them. Record what you did and what the app did.

| Case | How you caused it | What the app did | Crashed? |
|---|---|---|---|
| Permission denied | `tccutil reset Camera edu.samford.c335.BoothCam`, then click **Don't Allow** | Camera stayed off; showed "camera permission denied — enable it in System Settings → Privacy & Security → Camera" | No, app stayed open (pass) |
| No camera available | e.g. unplug the USB cam, or Screen Sharing holding it | | |
| Snap before any frame | press Space immediately on launch | | |
| | | | |

A clear message is a pass. A crash is a fail, even if the feature works otherwise.

## 5. Troubleshooting log

One entry per problem, however small. "No special fixes needed" is a valid whole section, but
say so explicitly rather than leaving it blank.

No special fixes needed. The project built and ran first try at `ddb3beb`, and again after
pulling the snap at `bdfb875`.

## 6. Screenshots

Four per person, labelled, with your name in the filename:
`docs/screenshots/<yourname>-live-original.png`, `-live-filtered`, `-captured-original`,
`-captured-filtered`. One window shot with all four panels visible also works — say which you
did.

| Screenshot | Committed | Filename |
|---|---|---|
| Live original | ✅ | `screenshots/ella-window-1.png` … `-4.png` |
| Live filtered | ✅ | same window shots |
| Captured original | ✅ | same window shots |
| Captured filtered | ✅ | same window shots |

Did the **one window shot** option: each of the four shots shows all four labelled panels
(grayscale mode, filter on). In every shot the captured panels differ from the live ones,
which also shows check 4 — the still stayed put while we moved.

## 7. Limitations you noticed on this Mac

Anything that worked but not well: frame rate with the filter on, lag on snap, a camera that
takes seconds to warm up, resolution differences. Say whether it is **observed** (you saw it) or
**documented** (you read it).

None observed. Live feed, filter and snap all felt immediate on this Mac.

## 8. Can you explain the whole app?

The ground rule is that anyone can be asked about any part. Tick honestly — an untick here is
information for the rehearsal, not a mark against you.

| | Confident | Explain it to me first |
|---|---|---|
| Which call opens the camera, and what its result tells you | ☐ | ✅ |
| How a frame gets from the device to the screen | ☐ | ✅ |
| Why the captured still does not change with the live feed | ☐ | ✅ |
| What grayscale does to the pixel data | ☐ | ✅ |
| Where camera resources are released, and why it matters | ☐ | ✅ |
