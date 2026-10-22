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
| Name (member #) | |
| macOS | |
| Architecture | |
| Swift | |
| Xcode | |
| Camera model (from `SPCameraDataType`) | |
| Built-in or USB | |
| Date tested | |

## 2. Permission

| Step | Result |
|---|---|
| Prompt appeared on first camera use | yes / no |
| Exact wording shown in the prompt | |
| Listed under System Settings → Privacy & Security → Camera | yes / no |

If no prompt appeared, say what you saw instead — that is a finding, not a failure.

## 3. The five feature checks

Tick only what you saw with your own eyes on your own Mac.

| # | Check | Pass | Notes |
|---|---|---|---|
| 1 | **Live feed** — LIVE ORIGINAL shows moving video | ☐ | |
| 2 | **Live filter** — LIVE FILTERED differs from the original, and tracks it | ☐ | |
| 3 | **Snap** — pressing Space captures a still | ☐ | |
| 4 | **Filtered still** — CAPTURED FILTERED matches the filter applied to the still, and the captured panel does **not** change when you move | ☐ | |
| 5 | **Normal quit** — ⌘Q closes the app and the camera indicator light goes **off** | ☐ | |

Check 4 is the one that catches the copy-vs-reference bug: wave at the camera after snapping.
If the captured panel moves, the still is holding the live buffer instead of its own copy.

Check 5 is the one people forget. Watch the light, not the window.

## 4. Error cases

At least one, more if you hit them. Record what you did and what the app did.

| Case | How you caused it | What the app did | Crashed? |
|---|---|---|---|
| Permission denied | `tccutil reset Camera edu.samford.c335.BoothCam`, then click **Don't Allow** | | |
| No camera available | e.g. unplug the USB cam, or Screen Sharing holding it | | |
| Snap before any frame | press Space immediately on launch | | |
| | | | |

A clear message is a pass. A crash is a fail, even if the feature works otherwise.

## 5. Troubleshooting log

One entry per problem, however small. "No special fixes needed" is a valid whole section, but
say so explicitly rather than leaving it blank.

### Problem 1
- **Symptom:** what you saw, verbatim if there was an error message
- **Category:** install / permissions / device selection / frame acquisition / display or image format
- **What you checked:** including the things that turned out not to be it
- **What fixed it:**
- **How you confirmed the fix:**
- **Who helped:**

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
