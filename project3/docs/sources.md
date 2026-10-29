# Documentation Sources Used

Owner: Member 1 (Sarah Rae). Canvas deliverable: *list of documentation sources used*.

**Seeded from what our code and write-ups actually reference**, so the job left for each person
is to **add anything you used that is not already here** — not to start from nothing. Correct
your own rows too; they were compiled from commits, not dictated by you.

Every Apple URL below was fetched and confirmed to resolve on 2026-10-28.

**This is the full list.** Ella's research and troubleshooting record in the README carries a
shorter table of the sources that bear on the problems she wrote up; the two agree, and this one
is the superset. If you add something, add it here.

## Capture — AVFoundation

| Source | Used for | Used by |
|---|---|---|
| [AVCaptureSession](https://developer.apple.com/documentation/avfoundation/avcapturesession) | the capture graph: inputs, outputs, start and stop | Stephen |
| [AVCaptureDevice](https://developer.apple.com/documentation/avfoundation/avcapturedevice) | finding the camera with `.default(for: .video)` | Stephen, Sarah |
| [requestAccess(for:completionHandler:)](https://developer.apple.com/documentation/avfoundation/avcapturedevice/1624584-requestaccess) · [Requesting authorization to capture and save media](https://developer.apple.com/documentation/avfoundation/requesting-authorization-to-capture-and-save-media) | checking and requesting camera permission | Stephen |
| [AVCaptureVideoDataOutput](https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput) | getting every frame rather than just a preview; `alwaysDiscardsLateVideoFrames` | Stephen |
| [AVCaptureVideoDataOutputSampleBufferDelegate](https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutputsamplebufferdelegate) | `captureOutput(_:didOutput:from:)` on a background queue | Stephen |
| [Core Media I/O](https://developer.apple.com/documentation/coremediaio) | the layer below AVFoundation, and the DAL plug-in point | Sarah |

## Images — Core Image and Core Video

| Source | Used for | Used by |
|---|---|---|
| [CIImage](https://developer.apple.com/documentation/coreimage/ciimage) | an image is a recipe, not pixels — nothing is computed until something renders it | Calli, Georgia |
| [CIContext](https://developer.apple.com/documentation/coreimage/cicontext) | `createCGImage` — where the snap copy actually happens | Georgia |
| [CVPixelBuffer](https://developer.apple.com/documentation/corevideo/cvpixelbuffer) | the buffer a frame arrives in, and that the session reuses | Georgia, Stephen |
| `CIFilter.photoEffectMono`, `CIFilter.colorInvert` | the two filters | Calli |

## Permissions and the sandbox

| Source | Used for | Used by |
|---|---|---|
| [NSCameraUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nscamerausagedescription) | the sentence shown in the permission prompt; a missing key kills the app | Sarah |
| `man tccutil` | resetting the permission decision to re-test the prompt | Sarah, Ella |

## Command-line tools, for the device-stack observations

| Tool | What it told us |
|---|---|
| `system_profiler SPCameraDataType` | which cameras macOS sees — every Mac on the team found two |
| `ps`, `top` | that the camera daemons run from boot, and which one wakes when the camera opens |
| `ioreg -p IOUSB` | that the built-in camera is not a USB device |
| `codesign -d --entitlements` | that our camera entitlement reached the built app |

## AI assistants

Commits where an assistant helped carry a `Co-Authored-By: Claude …` line in `git log`.

| Tool | Used for | Used by |
|---|---|---|
| Claude Code (Claude Sonnet 5) | `CameraManager.swift` — permission, session, the delegate and background queue, error handling and cleanup | Stephen |
| Claude Code (Claude Opus 5.5) | snap: rendering the live frame into its own `CGImage`, and the test record | Georgia |
| Claude Code (Claude Opus 5.5) | the grayscale and invert filters, and the test record | Calli |
| Claude Code (Claude Opus 5.5) | pulling changes, gathering machine details, and filling in the test record from what was reported | Ella |
| Claude (claude.ai and Claude Code) | the Xcode project and stubs, camera permission and entitlement, the device-stack investigation, the README, the test record template, and the learning plan | Sarah Rae |

**Everyone: add what you actually used.** The entries above come from commit history, which
catches the AI and the Apple pages our code references — it does not catch a Stack Overflow
answer, a YouTube walkthrough, or a classmate who explained something.

- [ ] **Stephen** — anything beyond the AVFoundation pages above
- [ ] **Georgia** — anything used for `CIContext` / copying frames
- [ ] **Calli** — anything used for Core Image filters or the grayscale maths
- [ ] **Ella** — anything used for testing, permissions or Continuity Camera
- [x] **Sarah** — the Apple pages and man pages above; AI as listed
