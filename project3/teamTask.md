# Project 3: Webcam Photo Booth — Team Task Split

**App:** BoothCam, a Photo Booth–style webcam app
**Environment:** Swift on macOS (same as Projects 1 and 2)
**Stack:** AVFoundation (camera), Core Image (filters), SwiftUI (window/UI)
**Filters:** Grayscale (main) + Color Invert (optional second toggle)
**Demo:** 30 min · **Estimated effort:** ~6 hours

---

## Ground rules (everyone)
- The app must run on **all five Macs**, set up on each person's own machine. No copying a working build over, help each other install and fix it
- Everyone must be able to explain the **whole app**, not just their part
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

## Member 1: Setup, Device Stack & README · `________`
Owns demo section **2 (device stack & library selection)**.

- [ ] Create the Xcode macOS App project in `project3/` (SwiftUI), add `.gitignore`
- [ ] Add `NSCameraUsageDescription` to Info.plist; if App Sandbox is on, enable **Camera** (`com.apple.security.device.camera`)
- [ ] Stub files so everyone can work in parallel: `CameraManager.swift`, `FrameFilter.swift`, `ContentView.swift`
- [ ] Research why AVFoundation (vs. older/other options) and why Core Image; save the doc links
- [ ] Build the **device-stack diagram**: BoothCam → AVFoundation (`AVCaptureSession`) → CoreMediaIO / macOS camera service (+ TCC permission check) → camera driver (built-in camera driver, or Apple's UVC driver/`UVCAssistant` for USB webcams) → physical webcam (internal or USB)
- [ ] Mark each layer documented vs observed. Observation ideas: `system_profiler SPCameraDataType`, `ioreg -p IOUSB` (USB cams), `UVCAssistant` in Activity Monitor while the camera is on
- [ ] Explain what's hidden by the library and what we could still determine about it
- [ ] Own the README: setup/run instructions, dependencies + versions, permissions, device selection, controls
- [ ] Collect sources and contribution statements from everyone; schedule the rehearsal

## Member 2: Camera Connection & Live Video · `________`
Owns demo section **3a (opening the camera, frames, display, cleanup)**. File: `CameraManager.swift`

- [ ] Check/request permission with `AVCaptureDevice.authorizationStatus(for: .video)` / `requestAccess`
- [ ] Pick the device (`AVCaptureDevice.default(for: .video)`), create `AVCaptureDeviceInput`, add to `AVCaptureSession`
- [ ] Add `AVCaptureVideoDataOutput` with a delegate on a background `DispatchQueue`; set `alwaysDiscardsLateVideoFrames = true`
- [ ] In `captureOutput(_:didOutput:from:)`: sample buffer → `CVPixelBuffer` → `CIImage` → publish latest frame to the UI on the main thread
- [ ] Start/stop the session off the main thread
- [ ] **Errors:** no camera found, permission denied, `canAddInput` fails, `AVCaptureSession.runtimeError` notification, dropped frames → show a clear message, no crash
- [ ] Test failure: deny permission (`tccutil reset Camera <bundle id>` then click Don't Allow), and one more case. Write down how you tested
- [ ] **Cleanup:** `stopRunning()`, remove inputs/outputs on quit and window close; explain why it matters (camera light stays on, device stays locked)
- [ ] Explain the important parameters (session preset, queue, discard late frames)

## Member 3: Still Capture · `________`
Owns demo section **3b (snap)**. Works in `CameraManager.swift` + `ContentView.swift`

- [ ] "Snap" button + **Space** key shortcut
- [ ] On snap, **render the current frame into a new `CGImage`** with `CIContext` (a real copy, not a reference to the live pixel buffer)
- [ ] Display it in a separate **CAPTURED** panel that stays put while the live feed changes
- [ ] Explain copy vs reference: the live pixel buffers come from a pool that gets reused, so holding a reference could change or hold up frames; rendering to a `CGImage` gives the capture its own memory
- [ ] Handle "snap before any frame arrived" (message, no crash)
- [ ] Optional: save to file (`NSSavePanel` + PNG)

## Member 4: Filters & Comparison · `________`
Owns demo section **3c (filter)**. File: `FrameFilter.swift`

- [ ] `func grayscale(_ image: CIImage) -> CIImage` using `CIPhotoEffectMono` or `CIColorControls` (saturation 0)
- [ ] Optional `func invert(_:)` using `CIColorInvert`
- [ ] Apply the same function to the live frame **and** the captured still
- [ ] Layout: **LIVE ORIGINAL | LIVE FILTERED** on top, **CAPTURED ORIGINAL | CAPTURED FILTERED** below (or a toggle with **F**)
- [ ] Keep the originals untouched; filtering always creates a new image
- [ ] Explain what changes in the data: RGB → one brightness value (≈ 0.3R + 0.59G + 0.11B); invert = 1 − each channel (255 − value in 8-bit)
- [ ] Explain where it runs: in Core Image (library, usually on the GPU), called from our code, not a camera setting
- [ ] Note any effect on responsiveness or quality (check frame rate with filter on/off)

## Member 5: Testing, Troubleshooting & Research Record · `________`
Owns demo section **4 (research & problem solving)**.

- [ ] Make the **test record template** (environment, camera, 5 feature checks, limitations, screenshots) and get everyone's filled in
- [ ] Run the app on every Mac with that person as early as possible, help diagnose problems together
- [ ] Sort each problem by type: install, permissions, device selection, frame acquisition, display/image format
- [ ] Write the **research & troubleshooting record**: sources, what we adapted, problems + fixes, AI use and how we checked it (or "no AI used")
- [ ] Collect and label all screenshots: LIVE / CAPTURED / ORIGINAL / FILTERED + member name
- [ ] Write the strengths, limitations, and one improvement with more time (demo section 5)

---

## Work order
1. **Member 1** creates the project with Info.plist permission and stubs, pushes it (day 1)
2. **Everyone** pulls and gets a blank build running on their own Mac (catch setup problems early)
3. **Member 2** gets live video working first; nothing else can be tested until this works
4. **Members 3 and 4** build snap and filters on top (Member 4 can start filter code with a test `CIImage` before then)
5. **Member 5** runs the full app on all five Macs with each person, collects test records and screenshots
6. Everyone adds their explanations and sources to the README / records
7. **Member 1** finishes the README, diagram, sources, and contribution statement
8. **Rehearsal:** each person explains a section they didn't write, then goes through the instructor questions below

## Suggested demo timing (30 min)
| Section | Presenter | Time |
|---|---|---|
| 1. Working app on each Mac (~2 min each) | Everyone | 10 min |
| 2. Device stack & library selection | ______ | 5 min |
| 3. Code walkthrough (camera, snap, filter, errors, cleanup) | ______ | 7 min |
| 4. Research & troubleshooting | ______ | 4 min |
| 5. Collaboration, tradeoffs, limitations | ______ | 2 min |
| Questions | Everyone | 2 min |

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

## Submission checklist (Canvas)
- [ ] Source code + Xcode project and assets
- [ ] Setup & run instructions (versions, permissions, device selection, controls)
- [ ] Test record for each of the 5 Macs, with labeled screenshots
- [ ] Device-stack diagram with references
- [ ] Research & troubleshooting record (incl. AI use)
- [ ] Team contribution statement

## Controls
| Key | Action |
|---|---|
| Space | Snap still |
| F | Toggle filter / comparison view |
| I | Toggle invert (optional) |
| Esc or ⌘Q | Quit (releases camera) |
