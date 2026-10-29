# Project 3: Webcam Photo Booth — Team Task Split

**App:** BoothCam, a Photo Booth–style webcam app
**Environment:** Swift on macOS (same as Projects 1 and 2)
**Stack:** AVFoundation (camera), Core Image (filters), SwiftUI (window/UI)
**Filters:** Grayscale (main) + Color Invert (optional second toggle)
**Demo:** 30 min, in class · **Due: Thursday 5 November** · **Estimated effort:** ~6 hours

**Learning session + random drill: Thursday 29 October, 9:35–10:55 in class** — a week before
the demo, which is the point: the drill has to leave time to fix whatever it exposes.

---

## Ground rules (everyone)
- The app must run on **all five Macs**, set up on each person's own machine. No copying a working build over, help each other install and fix it
- Everyone must be able to explain the **whole app**, not just their part
- **Write it so someone else can present it.** Any of us may be asked about any part, and we
  each present a section we did not write — so the simplest version that works beats the clever
  one. In practice: plain `if`/`for` over chained one-liners, a named variable over a nested
  expression, one obvious way over a shortcut, and a comment on anything that would make a
  teammate stop and reread. If explaining your code takes longer than the code saved you,
  simplify it
- Log every setup problem as it happens: symptom → what you checked → what fixed it → how you confirmed it
- Label every device-stack claim as **documented** (from Apple docs) or **observed** (we saw it ourselves)
- Note any source or AI suggestion you used, and what you checked or changed
- Commit your own files only; talk before editing someone else's
- Each person writes 3–5 sentences for the contribution statement

## Everyone, on your own Mac
- [ ] Clone the repo, open the `project3/` Xcode project, build and run
- [ ] Grant camera permission (System Settings → Privacy & Security → Camera)
- [ ] Record: `sw_vers`, `uname -m`, `swift --version`, Xcode version, camera name (`system_profiler SPCameraDataType`)
- [ ] Screenshots: live original vs filtered, captured original vs filtered (labeled, your name on them)
- [ ] Confirm: live feed ✓ live filter ✓ snap ✓ filtered still ✓ normal quit ✓
- [ ] Add your problems/fixes (or "no special fixes needed") to the troubleshooting record
- [ ] Practice launching, operating, explaining, and closing the app on your own

---

## Member 1: Setup, Device Stack & README · `Sarah Rae`
Owns demo section **2 (device stack & library selection)**.

- [x] Create the Xcode macOS App project in `project3/` (SwiftUI), add `.gitignore` — `BoothCam/BoothCam.xcodeproj`, builds clean
- [x] Add `NSCameraUsageDescription` to Info.plist; if App Sandbox is on, enable **Camera** (`com.apple.security.device.camera`) — both are build settings in Xcode 26, not a `.entitlements` file; verified with `codesign -d --entitlements`
- [x] Stub files so everyone can work in parallel: `CameraManager.swift`, `FrameFilter.swift`, `ContentView.swift` — each carries its owner's checklist
- [x] Research why AVFoundation (vs. older/other options) and why Core Image; save the doc links — `docs/section2-device-stack.md` §4, links in its Sources table (all fetched and confirmed to resolve)
- [x] Build the **device-stack diagram** — `docs/section2-device-stack.md` §1; two driver paths, not one chain: BoothCam → AVFoundation (`AVCaptureSession`) → CoreMediaIO / macOS camera service (+ TCC permission check) → camera driver (built-in camera driver, or Apple's UVC driver/`UVCAssistant` for USB webcams) → physical webcam (internal or USB)
- [x] Mark each layer documented vs observed — every claim labelled; re-run with the camera live once Stephen's code lands. Observation ideas: `system_profiler SPCameraDataType`, `ioreg -p IOUSB` (USB cams), `UVCAssistant` in Activity Monitor while the camera is on
- [x] Explain what's hidden by the library and what we could still determine about it — `docs/section2-device-stack.md` §5
- [x] Own the README: setup/run instructions, dependencies + versions, permissions, device selection, controls — `README.md`; the device-selection detail fills in once Stephen's code picks a device
- [ ] Collect sources and contribution statements from everyone; schedule the rehearsal — **rehearsal booked: Thursday 29 Oct, 9:35–10:55 in class** ✔. Both documents are written and seeded (`docs/sources.md`, README contribution table); what is left is four people confirming their own rows

## Member 2: Camera Connection & Live Video · `Stephen`
Owns demo section **3a (opening the camera, frames, display, cleanup)**. File: `CameraManager.swift`

- [x] Check/request permission with `AVCaptureDevice.authorizationStatus(for: .video)` / `requestAccess`
- [x] Pick the device (`AVCaptureDevice.default(for: .video)`), create `AVCaptureDeviceInput`, add to `AVCaptureSession`
- [x] Add `AVCaptureVideoDataOutput` with a delegate on a background `DispatchQueue`; set `alwaysDiscardsLateVideoFrames = true`
- [x] In `captureOutput(_:didOutput:from:)`: sample buffer → `CVPixelBuffer` → `CIImage` → publish latest frame to the UI on the main thread
- [x] Start/stop the session off the main thread
- [x] **Errors:** no camera found, permission denied, `canAddInput` fails, `AVCaptureSession.runtimeError` notification, dropped frames → show a clear message, no crash
- [ ] Test failure: deny permission (`tccutil reset Camera <bundle id>` then click Don't Allow), and one more case. Write down how you tested — **needs a human click on the system dialog, can't be scripted**
- [x] **Cleanup:** `stopRunning()`, remove inputs/outputs on quit and window close; explain why it matters (camera light stays on, device stays locked)
- [ ] Explain the important parameters (session preset, queue, discard late frames)

## Member 3: Still Capture · `Georgia`
Owns demo section **3b (snap)**. Works in `CameraManager.swift` + `ContentView.swift`

- [x] "Snap" button + **Space** key shortcut — `ContentView.swift`: `Button("Snap")` with `.keyboardShortcut(.space)`
- [x] On snap, **render the current frame into a new `CGImage`** with `CIContext` (a real copy, not a reference to the live pixel buffer) — `Self.ciContext.createCGImage(frame, from: frame.extent)`
- [x] Display it in a separate **CAPTURED** panel that stays put while the live feed changes — proved by waving after a snap; `docs/screenshots/sarah-window-all-four-panels.png` shows LIVE neutral and CAPTURED smiling in one frame
- [x] Explain copy vs reference: the live pixel buffers come from a pool that gets reused, so holding a reference could change or hold up frames; rendering to a `CGImage` gives the capture its own memory — written up in the `snap()` doc comment
- [x] Handle "snap before any frame arrived" (message, no crash) — `guard let frame` sets *"No frame yet"*; seen in `docs/screenshots/sarah-permission-denied.png`
- [ ] Optional: save to file (`NSSavePanel` + PNG) — not implemented; it was optional

## Member 4: Filters & Comparison · `Calli`
Owns demo section **3c (filter)**. File: `FrameFilter.swift`

- [x] `func grayscale(_ image: CIImage) -> CIImage` using `CIPhotoEffectMono` or `CIColorControls` (saturation 0) — `CIPhotoEffectMono`; builds clean
- [x] Optional `func invert(_:)` using `CIColorInvert`
- [x] Apply the same function to the live frame **and** the captured still — both columns go through `ContentView.filter(_:)`; the still side shows once Georgia's snap lands
- [x] Layout: **LIVE ORIGINAL | LIVE FILTERED** on top, **CAPTURED ORIGINAL | CAPTURED FILTERED** below (or a toggle with **F**) — grid from Sarah Rae's `ContentView` skeleton, **F** toggles the filter, **I** switches to invert
- [x] Keep the originals untouched; filtering always creates a new image — checked on a solid red test image: original still (255, 0, 0) after filtering
- [x] Explain what changes in the data: RGB → one brightness value (≈ 0.3R + 0.59G + 0.11B); invert = 1 − each channel (255 − value in 8-bit) — in the `FrameFilter` doc comments, **with a measured correction**: pure red comes out 132, not 77, because Core Image works in linear light and PhotoEffectMono adds a contrast curve
- [x] Explain where it runs: in Core Image (library, usually on the GPU), called from our code, not a camera setting — "Where it runs" in the `FrameFilter.swift` header: the pixels are computed when `createCGImage` renders the recipe, not when the filter is applied
- [x] Note any effect on responsiveness or quality (check frame rate with filter on/off) — observed: CPU 45–50% off → 77–82% grayscale / 77–84% invert, video still smooth, grayscale looks normal (`docs/test-records/test-record-calli.md` §7)

## Member 5: Testing, Troubleshooting & Research Record · `Ella`
Owns demo section **4 (research & problem solving)**.

- [x] Make the **test record template** (environment, camera, 5 feature checks, limitations, screenshots) and get everyone's filled in — template is `docs/test-records/test-record-template.md` (built by Member 1 because it blocked everyone); all five records exist, four pass every check, Stephen needs a clean redo of the quit check
- [x] Run the app on every Mac with that person as early as possible, help diagnose problems together — BoothCam has run on all five Macs
- [x] Sort each problem by type: install, permissions, device selection, frame acquisition, display/image format — README, *Problems by category*
- [x] Write the **research & troubleshooting record**: sources, what we adapted, problems + fixes, AI use and how we checked it (or "no AI used") — README, *Research & troubleshooting record*
- [x] Collect and label all screenshots: LIVE / CAPTURED / ORIGINAL / FILTERED + member name — all five in: Sarah (2), Stephen (4), Georgia (1), Calli (1), Ella (4)
- [x] Write the strengths, limitations, and one improvement with more time (demo section 5) — README, *Strengths, limitations, and one improvement*

---

## Work order

Steps 1–4 are done: the app is feature-complete and four of five Macs pass every check.

1. ~~**Member 1** creates the project with Info.plist permission and stubs~~ — done
2. ~~**Everyone** pulls and gets a blank build running on their own Mac~~ — done, all five
3. ~~**Member 2** gets live video working~~ — done
4. ~~**Members 3 and 4** build snap and filters on top~~ — done
5. **Member 5** collects the remaining test records and screenshots — all screenshots are in and
   four of five records are complete; **Stephen needs a clean redo of check 5 (quit)**
6. Everyone adds their explanations and sources to the README / records — the write-ups are now
   the whole of what is left
7. **Member 1** finishes the README, diagram, sources, and contribution statement
8. **The learning rounds** — one 60-minute teaching meeting and one random drill at the
   rehearsal. See [`docs/learning-reflection-plan.md`](docs/learning-reflection-plan.md). This
   can start now: the app works, so there is nothing left to wait for

## Suggested demo timing (30 min)
| Section | Presenter | Time |
|---|---|---|
| 1. Working app on each Mac (~2 min each) | Everyone | 10 min |
| 2. Device stack & library selection | Sarah Rae | 5 min |
| 3. Code walkthrough (camera, snap, filter, errors, cleanup) | Stephen (3a camera) · Georgia (3b snap) · Calli (3c filter) | 7 min |
| 4. Research & troubleshooting | Ella | 4 min |
| 5. Collaboration, tradeoffs, limitations | Ella | 2 min |
| Questions | Everyone | 2 min |

Presenters above are the section owners. Work-order step 8 also has each person explain a
section they did **not** write — those pairings get assigned at the rehearsal, and if we run the
demo that way instead (project 2 did), this table gets updated to match.

## Practice questions (everyone should be able to answer)
- Which call opens the camera, and what does its result tell you?
- What does AVFoundation provide, and which macOS interface does it use underneath?
- What is the device driver's role in our app?
- How does the program get and display the next frame?
- What keeps the captured image from changing with the live feed?
- What does grayscale do to the image data?
- What happens if the camera can't be opened or a frame can't be read?
- Where are camera resources released, and why does that matter?
- What problem happened on your Mac, and how did you help solve it?
- Which source or AI suggestion did we adapt, test, or correct?

## Submission checklist (Canvas) — due Thursday 5 November

- [x] **Source code + Xcode project and assets** — `BoothCam/`, builds clean from a fresh clone
- [x] **Setup & run instructions** (versions, permissions, device selection, controls) — `README.md`
- [ ] **Test record for each of the 5 Macs, with labeled screenshots** — all screenshots
      are in and four of five records are complete. **Stephen** needs a clean redo of check 5
      (quit)
- [x] **Device-stack diagram with references** — `docs/section2-device-stack.md`, every claim
      marked documented or observed, with the command or the Apple link behind it
- [x] **Research & troubleshooting record (incl. AI use)** — written by Ella in the README,
      with problems by category, error cases and AI use. Sarah's five rows in
      `docs/reflections/ai-use-log.md` and Ella's row all carry their "what we learned" lines
- [ ] **Team contribution statement** — all five rows seeded from what is committed in the
      README. **2 of 5 confirmed in their own words: Sarah and Ella.** Stephen, Georgia and
      Calli still to confirm or rewrite theirs

### Not on the Canvas list, but the professor said it matters

- [ ] Everyone's learning log — **Sarah and Ella have written theirs**; Stephen, Georgia and
      Calli still have blank templates. Thursday's session is designed so they get written in
      the room
- [ ] Readiness tracker — 1 tick of 20; filled in at Thursday's session
- [ ] Team reflection — written together after testing

## Controls
| Key | Action |
|---|---|
| Space | Snap still |
| F | Toggle filter / comparison view |
| I | Toggle invert (optional) |
| Esc or ⌘Q | Quit (releases camera) |
