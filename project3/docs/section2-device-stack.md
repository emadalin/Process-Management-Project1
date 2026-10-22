# Demo Section 2: Device Stack & Library Selection (5 min)

Owner: Member 1 (Sarah Rae). Presented by Stephen — nobody presents their own section.

**One-sentence version:** BoothCam never speaks to the webcam. It asks AVFoundation, which asks
the CoreMediaIO camera service, which is the thing that actually talks to a driver — and the
layer that decides whether we are allowed at all sits off to the side, outside all of them.

Every claim below is marked **documented** (from Apple's documentation) or **observed** (we saw
it on this machine, with the command shown). Observations are from Sarah's M2, macOS 15.8.1.

---

## 1. The stack

```
  ┌─────────────────────────────────────────────────┐
  │  BoothCam                                       │   our code
  │  AVCaptureSession · AVCaptureDeviceInput        │
  │  AVCaptureVideoDataOutput → CIImage             │
  └───────────────────────┬─────────────────────────┘
                          │  Objective-C / Swift API calls
  ┌───────────────────────▼─────────────────────────┐
  │  AVFoundation                                   │   Apple framework
  │  enumerates devices, owns the capture graph,    │   (in our process)
  │  delivers CMSampleBuffers to our delegate       │
  └───────────────────────┬─────────────────────────┘
                          │  XPC — a process boundary
  ┌───────────────────────▼─────────────────────────┐
  │  CoreMediaIO + the camera service               │   separate processes
  │  cameracaptured · the DAL plug-in host          │   (NOT ours)
  └──────────┬───────────────────────────┬──────────┘
             │                           │
  ┌──────────▼──────────┐    ┌───────────▼─────────────────┐
  │  appleh13camerad    │    │  UVCAssistant               │   drivers
  │  built-in camera    │    │  .systemextension, for USB  │   (user space)
  └──────────┬──────────┘    └───────────┬─────────────────┘
             │                           │
  ┌──────────▼──────────┐    ┌───────────▼─────────────────┐
  │  FaceTime HD Camera │    │  USB UVC webcam             │   hardware
  │  on the Apple ISP   │    │  on the USB bus             │
  └─────────────────────┘    └─────────────────────────────┘

        ┌──────────────────────────────────────────┐
        │  TCC — the privacy layer                 │   beside, not below
        │  checks the entitlement + the user's      │
        │  answer before any frame is delivered     │
        └──────────────────────────────────────────┘
```

**The thing worth saying out loud:** the stack is not a single chain. There are *two* driver
paths depending on which camera you pick, and the permission check is not a layer the frames
pass through — it is a gate beside the whole thing that decides whether the pipeline runs.

## 2. Layer by layer, with the evidence

### BoothCam → AVFoundation — **documented**

We create an `AVCaptureSession`, add an `AVCaptureDeviceInput` for a device, and attach an
`AVCaptureVideoDataOutput` with a delegate. Frames arrive as `CMSampleBuffer`. That is the whole
of our side of the boundary; see `CameraManager.swift`.

### AVFoundation → the camera service — **observed**

This is the step that surprised us: the capture work is **not** in our process. The system runs
separate daemons for it, and they are running right now:

```bash
$ ps -axo comm | grep -iE "camerad|UVCAssistant|cameracapture"
/System/Library/Frameworks/CoreMediaIO.framework/Versions/A/Resources/UVCAssistant.systemextension/Contents/MacOS/UVCAssistant
/usr/libexec/cameracaptured
/usr/sbin/appleh13camerad
```

So "AVFoundation opens the camera" is shorthand. AVFoundation is a client; `cameracaptured` and
the driver processes are where the device is actually held. That is also why the camera stays
busy if a process does not release it — the holder is not necessarily the app you quit.

### Two driver paths — **observed names, inferred roles**

`UVCAssistant` lives inside `CoreMediaIO.framework` as a **`.systemextension`** bundle
(**observed** — the path above). UVC is the USB Video Class standard, so this is the user-space
driver for standard USB webcams — macOS needs no vendor driver for them (**documented**).

`appleh13camerad` is **observed** running. Its role — the daemon for the built-in camera on the
Apple ISP — is **inferred from the name and from there being no other candidate**, not read in
documentation. Say it that way if asked.

Note what this means: on this M2 the built-in camera is **not** a USB device. `ioreg -p IOUSB`
shows only the XHCI controller itself, no camera (**observed**), which is why the USB path in
the diagram is empty on this machine and would light up with a USB webcam attached.

### Third-party extension point — **observed**

CoreMediaIO's DAL plug-in directory exists and is empty of plug-ins:

```bash
$ cat /Library/CoreMediaIO/Plug-Ins/DAL/plugins-info.txt
Third party CoreMediaIO DAL Plug-Ins
```

This is how virtual cameras (OBS, Zoom backgrounds, Continuity) insert themselves — they appear
to AVFoundation as real devices. We have none installed, so every device we see is a real one.

### TCC — **observed, and the only layer that can stop us**

Two build settings make access possible at all, and both are verifiable on the built app rather
than taken on trust:

```bash
$ codesign -d --entitlements - --xml BoothCam.app | plutil -convert xml1 -o - -
  com.apple.security.app-sandbox      true
  com.apple.security.device.camera    true
```

`INFOPLIST_KEY_NSCameraUsageDescription` supplies the sentence in the prompt. Missing it does
not produce an error — **the app is killed** the moment it touches the camera (**documented**).

Reset the decision to see the prompt again:

```bash
tccutil reset Camera edu.samford.c335.BoothCam
```

## 3. Which camera do we even get?

`AVCaptureDevice.default(for: .video)` sounds unambiguous. It isn't — this Mac has two
(**observed**):

```bash
$ system_profiler SPCameraDataType
Camera:
    FaceTime HD Camera:
      Model ID: FaceTime HD Camera
      Unique ID: FDF90FEB-59E5-4FCF-AABD-DA03C4E19BFB
    iPhone (8) Camera:
      Model ID: iPhone18,1
      Unique ID: FD58F515-0F67-4A04-8CD9-BF0D00000001
```

The second is a **Continuity Camera** — an iPhone, offered as a local capture device over the
network, through the same API as the built-in one. `avconferenced` is running, which is the
process that makes it available (**observed name, inferred role**).

**Consequence for the team:** every test record must say *which* camera it used. A teammate with
an iPhone nearby may get a different device than the one they are looking at, and "the feed is
not my webcam" will look like a bug. This is the strongest argument for listing devices
explicitly rather than taking `.default`.

## 4. Why these libraries

### Why AVFoundation

- **It is the supported interface.** QuickTime Capture and QTKit are gone; AVFoundation is the
  current one (**documented**).
- **It spans the whole job** — enumeration, permission, the capture graph, and frame delivery —
  so we do not assemble a pipeline from parts.
- **It gives us raw frames.** `AVCaptureVideoDataOutput` hands us every frame as a
  `CMSampleBuffer`, which is what makes a *live* filter possible. A higher-level view that just
  renders a preview would not let us touch pixels on the way past.
- **The alternative is far lower.** Talking to CoreMediaIO or IOKit directly would mean writing
  what `cameracaptured` already does, for no gain in a 6-hour project.

### Why Core Image

- **A `CIImage` is a recipe, not pixels.** Applying a filter computes nothing; work happens when
  something renders it (**documented**). That is exactly right for a live feed — we can build
  `grayscale(frame)` 30 times a second cheaply.
- **It is already in the pipeline.** A `CVPixelBuffer` from capture becomes a `CIImage` directly,
  with no conversion of our own.
- **One call does the job** — `CIPhotoEffectMono`, `CIColorInvert` — and Core Image decides
  whether to run on the GPU.

## 5. What the library hides, and what we can still find out

**Hidden from us:**
- the exposure, white balance and ISP processing applied before we see a frame
- the negotiation that picks a resolution and pixel format for a session preset
- the XPC protocol between AVFoundation and `cameracaptured`
- whether a given frame came from the ISP or was copied through shared memory

**Determinable anyway, and how:**

| Question | How we answered it |
|---|---|
| Is the capture work in our process? | No — `ps` shows `cameracaptured` and the driver daemons |
| Which driver serves which camera? | Two separate daemons; `UVCAssistant` for USB, `appleh13camerad` for built-in |
| Is the built-in camera a USB device? | No — `ioreg -p IOUSB` shows no camera |
| Can something fake a camera? | Yes — the DAL plug-in directory is the documented way in |
| Did our entitlement actually ship? | `codesign -d --entitlements` on the built app |
| What format are frames in? | Read `CVPixelBufferGetPixelFormatType` in the delegate — _TODO once Stephen's code runs_ |

**The honest limit:** we can see the *processes* and the *interfaces*, and we can verify our own
entitlement. We cannot see inside the driver or the ISP, and nothing we ran proves what the
daemons do internally — only that they exist, run, and are positioned where the documentation
says they are.

---

## Still to do

- [ ] Re-run the process observation **while the camera is live** (after Stephen's section
      lands) and record what changes — this is the strongest single observation available, and
      right now the camera is never opened
- [ ] Record the pixel format of a real frame

## Sources

Every URL below was fetched and confirmed to resolve on 2026-10-22 — none is from memory.

### Behind the **documented** claims

| Claim | Source |
|---|---|
| AVFoundation owns the capture graph; session coordinates inputs and outputs | [AVCaptureSession](https://developer.apple.com/documentation/avfoundation/avcapturesession) |
| We get every frame as a `CMSampleBuffer`, which is what makes a live filter possible | [AVCaptureVideoDataOutput](https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput) |
| Devices are enumerated and selected through one class | [AVCaptureDevice](https://developer.apple.com/documentation/avfoundation/avcapturedevice) |
| Permission must be checked and requested before capture | [requestAccess(for:completionHandler:)](https://developer.apple.com/documentation/avfoundation/avcapturedevice/1624584-requestaccess) · [Requesting authorization to capture and save media](https://developer.apple.com/documentation/avfoundation/requesting-authorization-to-capture-and-save-media) |
| A missing `NSCameraUsageDescription` is fatal, not an error to handle | [NSCameraUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nscamerausagedescription) |
| A `CIImage` is an immutable recipe; nothing is computed until something renders it | [CIImage](https://developer.apple.com/documentation/coreimage/ciimage) |
| CoreMediaIO is the layer below AVFoundation, and the DAL is its plug-in point | [Core Media I/O](https://developer.apple.com/documentation/coremediaio) |

### Behind the **observed** claims

These are commands, not documents — anyone can re-run them:

| Observation | Command |
|---|---|
| Two cameras, including an iPhone over Continuity | `system_profiler SPCameraDataType` |
| Capture runs in separate processes | `ps -axo comm \| grep -iE "camerad\|UVCAssistant\|cameracapture"` |
| The built-in camera is not on the USB bus | `ioreg -p IOUSB -l -w 0` |
| `UVCAssistant` ships as a system extension inside CoreMediaIO | `ls /System/Library/Frameworks/CoreMediaIO.framework/Versions/A/Resources/` |
| The third-party DAL plug-in directory exists and is empty | `cat /Library/CoreMediaIO/Plug-Ins/DAL/plugins-info.txt` |
| Our camera entitlement reached the built app | `codesign -d --entitlements - --xml BoothCam.app` |
| Resetting the permission decision | `tccutil reset Camera edu.samford.c335.BoothCam` (`man tccutil`) |

### Not sourced on purpose

`appleh13camerad` and `avconferenced` have **no documentation link**, because Apple does not
document them. We observed the processes running and inferred their roles from their names and
from what else was running. Section 2 says so rather than dressing an inference as a citation —
if asked where that came from, the honest answer is "`ps`, plus reasoning."
