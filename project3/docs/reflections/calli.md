# Calli — Project 3 Learning Log

**I built:** the grayscale filter (section 3c)
**I may be asked to present:** any of the five sections.

> Your own words, short. Two sentences per answer is fine. AI can explain a concept to you; it
> does not write this. If it helped, say so at the bottom.

---

## My part

**What I built, and the OS concept behind it** — not what the code does, but what it shows about
how the operating system works: I built a greyscale filter in BoothCam that takes the camera's color video frames and creates a new grayscale copy using my code. The grayscale effect happens in my code after the camera sends the video, not in the camera settings. I know this because live original stays in color while live filtered shows the same video in grayscale. When the filter was turned on, BoothCam's CPU usage went up by about 30  points, from 45–50% to 77–82%. This shows that the operating system tracks the processing work under the program that requested it, rather than the camera driver.

**One thing I got wrong at first, and how I found out:**
I initially assumed the 30-point CPU increase was caused entirely by the grayscale filter processing the video frames. I pressed F to turn off the filter and noticed that it also removes the extra display panels. This helped me realize that the CPU usage was not just from the grayscale calculations. The 30-point CPU increase comes from drawing and updating the tw oextra video panels, not just applying the grayscale filter. 

---

## Everyone else's parts

Two sentences each, written during or right after the team meeting. Aim for the **concept**, not
a description of the code.

- **Device stack** — I/O layers, abstraction *(Sarah)*: Between BoothCam and the camera are several layers, including AVFoundation, the camera driver, and the operating system, which help communicate with the camera hardware. Abstraction means BoothCam does not need to know how the camera hardware works internally or how each layer communicates with it; the lower layers handle those details and provide BoothCam with video frames to use.

- **Camera & cleanup** — permissions, resource release, background queues *(Stephen)*: MacOS decides whether BoothCam can use the camera by asking the user for permission. If BoothCam doesn't release the camera when it's done, the camera may stay active, the camera light may remain on, and other apps like FaceTime may not be able to use it. Slow tasks like starting the camera happen on a background thread so the main thread stays responsive and the app's interface doesn't freeze while the camera starts.

- **Snap** — copying vs. holding a reference to a reused buffer *(Georgia)*: If the photo held onto a live frame's memory slot, that slot couldn't be reused by the camera, leaving fewer slots available until the camera runs short and starts dropping frames. snap creates a separate copy of the current frame (like taking a screenshot) instead of keeping a live link, so later camera updates cannot change the saved photo.

- **Filter** — how pixels are stored, where the work runs *(Calli)*: The camera sends brightness and colour separately (YUV), Core Image converts that to RGB, and grayscale combines RGB into one brightness value The filter runs in our app's code through Core Image, using either the CPU or GPU, whichever Core Image chooses, and the processing increases BoothCam's CPU usage because the operating system counts the work against the app that requested it.

- **Testing** — how OS version, permissions and hardware change behaviour *(Ella)*: The same code can behave differently on different Macs because they may have different macOS versions, camera permissions, or attached cameras and hardware. Testing on all five Macs showed that most problems came from differences in setup and tools rather than bugs in the app's code.

**The section that took me longest to get, and what made it click:**
The section that took me the longest to understand was Snap (Georgia). I originally thought that if the photo pointed to the live frame, the photo itself would change when the camera reused that memory slot. What made it click was realizing that the camera can't reuse a slot I'm still holding, so the real problem is that it runs out of available slots and starts dropping frames.

---

## AI use

**What I asked, what I checked, and what was wrong or missing:**
I used AI mainly to help me understand my BoothCam project so I could explain it during my demo and to help me document my tests. I checked its answers by running the tests myself and comparing its claims with my code and test results. One mistake it made was saying SwiftUI handled the rendering, but I checked the code and found that our render() function calls createCGImage instead. This taught me that AI can be helpful for learning and explaining code, but I should always verify its answers with my own code and measurements.

(Also add a row to [`ai-use-log.md`](ai-use-log.md).)

---

## Looking back

**The OS concept I understand much better now:**
The OS idea I understand much better now is that the app never talks to the hardware directly; it asks the operating system, and the OS manages the resources.

**How this connects to threads (Project 1) and memory (Project 2):**
This connects to project 1 because BoothCam uses a background thread (sessionQueue) for slow camera work so the main thread doesn’t freeze. Frames arrive on one thread and get handed over to the main thread to update the screen. This connects to project 2 because snap is a memory question: who owns the memory, and what happens if you hold onto memory that something else needs to reuse.