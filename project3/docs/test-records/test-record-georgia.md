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
| Name (member #) | Georgia (Member 3) |
| macOS | 26.6.2 (25G83) |
| Architecture | arm64 |
| Swift | Apple Swift 6.4 (swiftlang-6.4.0.34.1) |
| Xcode | 27.1 (27A9275) |
| Camera model (from `SPCameraDataType`) | FaceTime HD Camera |
| Built-in or USB | Built-in |
| Date tested | 2026-10-22 (setup), 2026-10-27 (feature checks) |

## 2. Permission

| Step | Result |
|---|---|
| Prompt appeared on first camera use | yes — clicked Allow |
| Exact wording shown in the prompt | Standard macOS camera prompt; exact wording not recorded. The usage string the app sets is "BoothCam shows your webcam so you can take and filter photos." (`INFOPLIST_KEY_NSCameraUsageDescription`) |
| Listed under System Settings → Privacy & Security → Camera | yes |

If no prompt appeared, say what you saw instead — that is a finding, not a failure.

## 3. The five feature checks

Tick only what you saw with your own eyes on your own Mac.

| # | Check | Pass | Notes |
|---|---|---|---|
| 1 | **Live feed** — LIVE ORIGINAL shows moving video | ☑ | FaceTime HD Camera (the only camera on this Mac) |
| 2 | **Live filter** — LIVE FILTERED differs from the original, and tracks it | ☑ | shows grayscale |
| 3 | **Snap** — pressing Space captures a still | ☑ | |
| 4 | **Filtered still** — CAPTURED FILTERED matches the filter applied to the still, and the captured panel does **not** change when you move | ☑ | Wave test passed: CAPTURED ORIGINAL stayed still while LIVE ORIGINAL kept moving. CAPTURED FILTERED shows the snap in grayscale |
| 5 | **Normal quit** — ⌘Q closes the app and the camera indicator light goes **off** | ☑ | camera light went off |

Check 4 is the one that catches the copy-vs-reference bug: wave at the camera after snapping.
If the captured panel moves, the still is holding the live buffer instead of its own copy.

Check 5 is the one people forget. Watch the light, not the window.

## 4. Error cases

At least one, more if you hit them. Record what you did and what the app did.

| Case | How you caused it | What the app did | Crashed? |
|---|---|---|---|
| Permission denied | `tccutil reset Camera edu.samford.c335.BoothCam`, then click **Don't Allow** | | |
| No camera available | e.g. unplug the USB cam, or Screen Sharing holding it | | |
| Snap before any frame | press Space immediately on launch | showed "No frame yet" message | no |
| | | | |

A clear message is a pass. A crash is a fail, even if the feature works otherwise.

## 5. Troubleshooting log

One entry per problem, however small. "No special fixes needed" is a valid whole section, but
say so explicitly rather than leaving it blank.

### Problem 1
- **Symptom:** `xcodebuild` from Terminal failed: *"xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance"*
- **Category:** install
- **What you checked:** Xcode.app is installed in `/Applications`; `xcodebuild -version` reports 27.1 when pointed at it. Building inside the Xcode app was not affected
- **What fixed it:** ran the Terminal build with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (permanent fix: `sudo xcode-select -s /Applications/Xcode.app`)
- **How you confirmed the fix:** `xcodebuild ... build` → `** BUILD SUCCEEDED **`
- **Who helped:** an AI assistant (Claude Code)

### Problem 2
- **Symptom:**
- **Category:**
- **What you checked:**
- **What fixed it:**
- **How you confirmed the fix:**
- **Who helped:**

## 6. Screenshots

Four per person, labelled, with your name in the filename:
`docs/screenshots/<yourname>-live-original.png`, `-live-filtered`, `-captured-original`,
`-captured-filtered`. One window shot with all four panels visible also works — say which you
did.

| Screenshot | Committed | Filename |
|---|---|---|
| Live original | ☐ | |
| Live filtered | ☐ | |
| Captured original | ☐ | |
| Captured filtered | ☐ | |

## 7. Limitations you noticed on this Mac

Anything that worked but not well: frame rate with the filter on, lag on snap, a camera that
takes seconds to warm up, resolution differences. Say whether it is **observed** (you saw it) or
**documented** (you read it).

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
