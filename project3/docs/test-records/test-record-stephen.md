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
| Name (member #) | Stephen (Member 2) |
| macOS | 26.5.2 (25F84) |
| Architecture | arm64 |
| Swift | Apple Swift 6.3.2 (swiftlang-6.3.2.1.108) |
| Xcode | 26.5 (17F42) |
| Camera model (from `SPCameraDataType`) | MacBook Pro Camera (also lists an iPhone 14 Camera over Continuity — see §7) |
| Built-in or USB | Built-in |
| Date tested | 2026-10-27 |

## 2. Permission

| Step | Result |
|---|---|
| Prompt appeared on first camera use | yes, originally — but see the finding below |
| Exact wording shown in the prompt | not recorded verbatim |
| Listed under System Settings → Privacy & Security → Camera | yes |

**Finding, not a failure:** `tccutil reset Camera edu.samford.c335.BoothCam` reported success
twice (`Successfully reset Camera approval status...`), but relaunching the app both times went
straight to `live` with **no dialog at all** — permission stayed effectively granted. Checking
System Settings → Privacy & Security → Camera directly confirmed BoothCam was still listed and
**on**, despite the reset. Manually toggling it **off** in System Settings is what actually
revoked access — confirmed by the app no longer reaching the camera afterward. Logged as
Problem 1 below.

## 3. The five feature checks

Tick only what you saw with your own eyes on your own Mac.

| # | Check | Pass | Notes |
|---|---|---|---|
| 1 | **Live feed** — LIVE ORIGINAL shows moving video | ☑ | own face/room visible, live |
| 2 | **Live filter** — LIVE FILTERED differs from the original, and tracks it | ☑ | grayscale panel visibly tracked the color original |
| 3 | **Snap** — pressing Space captures a still | ☑ | confirmed on a clean run — CAPTURED ORIGINAL shows a still after pressing Space (`docs/screenshots/stephen-captured-original.png`) |
| 4 | **Filtered still** — CAPTURED FILTERED matches the filter applied to the still, and the captured panel does **not** change when you move | ☑ | confirmed — CAPTURED FILTERED shows the grayscale filter correctly applied (`stephen-captured-filtered.png`). Captured panel is visibly a different moment than the live panel at the same point in time (mouth open in LIVE ORIGINAL vs. closed in CAPTURED ORIGINAL) — the still is a frozen copy, not a reference into the live buffer |
| 5 | **Normal quit** — ⌘Q closes the app and the camera indicator light goes **off** | ☐ | attempted, but the session got tangled with a debugger-attached process (see Problem 2) — needs a clean redo |

Check 4 is the one that catches the copy-vs-reference bug: wave at the camera after snapping.
If the captured panel moves, the still is holding the live buffer instead of its own copy.

Check 5 is the one people forget. Watch the light, not the window.

## 4. Error cases

At least one, more if you hit them. Record what you did and what the app did.

| Case | How you caused it | What the app did | Crashed? |
|---|---|---|---|
| Permission denied | `tccutil reset Camera edu.samford.c335.BoothCam` did **not** force a fresh prompt (see §2 finding); toggling the permission **off** directly in System Settings did revoke it | Confirmed the app no longer reached the camera. The exact on-screen status text and a clean no-crash confirmation were **not** captured before the test session got derailed by an unrelated debugger-attachment issue (Problem 2) | not confirmed either way — needs a clean redo |
| No camera available | not tested | | |
| Snap before any frame | not tested on this Mac — Georgia's test record confirms it shows "No frame yet", no crash | | |
| | | | |

A clear message is a pass. A crash is a fail, even if the feature works otherwise.

## 5. Troubleshooting log

One entry per problem, however small. "No special fixes needed" is a valid whole section, but
say so explicitly rather than leaving it blank.

### Problem 1
- **Symptom:** `tccutil reset Camera edu.samford.c335.BoothCam` reported success, but relaunching
  BoothCam afterward never showed a fresh permission prompt — it went straight to `live`, as if
  still authorized.
- **Category:** permissions
- **What you checked:** ran the reset twice, relaunched both via `open` and via a direct binary
  exec, confirmed via process CPU usage that the app really was reaching the camera (not just
  appearing to). Checked System Settings → Privacy & Security → Camera directly rather than
  trusting the app or the reset command.
- **What fixed it:** manually toggling BoothCam's camera permission **off** in System Settings.
  `tccutil reset` alone was not sufficient on this Mac/build to force a genuine re-prompt.
- **How you confirmed the fix:** after toggling off, the app no longer accessed the camera.
- **Who helped:** an AI assistant (Claude Code) for the diagnostic steps (process state checks,
  `ps`/log inspection).

### Problem 2
- **Symptom:** after toggling permission off and relaunching to test the denied-permission path,
  the app became unresponsive to an AppleEvent (`activate`) — timed out after ~30s — and
  afterward resisted `kill -9` from the shell entirely.
- **Category:** install / debugging environment, not an app bug as far as confirmed
- **What you checked:** process state showed `SX` (consistent with being attached to a debugger)
  and the launch had picked up `-NSDocumentRevisionsDebugMode YES`, a flag Xcode attaches to
  debugged processes — suggesting Xcode's debugger (lldb/debugserver) had the process under
  ptrace, which blocks a plain `SIGKILL` from outside.
- **What fixed it:** stopping the process from inside Xcode (the Stop button / ⌘.) instead of
  trying to quit or kill it any other way.
- **How you confirmed the fix:** process no longer appeared in `ps`.
- **Who helped:** an AI assistant (Claude Code), reasoning from the process state rather than
  guessing.
- **Open question:** whether this was purely an artifact of how the app kept getting relaunched
  during testing, or something that could recur during the real demo. Worth a clean, single
  launch-and-quit test before demo day rather than the repeated relaunch cycle this session did.

## 6. Screenshots

Four per person, labelled, with your name in the filename:
`docs/screenshots/<yourname>-live-original.png`, `-live-filtered`, `-captured-original`,
`-captured-filtered`. One window shot with all four panels visible also works — say which you
did.

| Screenshot | Committed | Filename |
|---|---|---|
| Live original | ☑ | `stephen-live-original.png` |
| Live filtered | ☑ | `stephen-live-filtered.png` |
| Captured original | ☑ | `stephen-captured-original.png` |
| Captured filtered | ☑ | `stephen-captured-filtered.png` |

## 7. Limitations you noticed on this Mac

- **Two cameras are visible to the system** — the built-in MacBook Pro Camera and an iPhone 14
  Camera offered over Continuity. `AVCaptureDevice.default(for: .video)` doesn't let you choose
  between them explicitly; whichever one the system treats as default is what BoothCam opens.
  **Observed**, same finding as Sarah Rae's device-stack doc for a different Mac.
- **`tccutil reset` did not reliably force a fresh permission prompt** on this machine/build —
  **observed**, see §2 and Problem 1. Not something documented behavior guarantees against; worth
  the team knowing before relying on `tccutil reset` live during the demo.

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
