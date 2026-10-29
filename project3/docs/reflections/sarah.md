# Sarah Rae — Project 3 Learning Log

**I built:** the device stack diagram (section 2)
**I may be asked to present:** any of the five sections.

> Your own words, short. Two sentences per answer is fine. AI can explain a concept to you; it
> does not write this. If it helped, say so at the bottom.

---

## My part

**What I built, and the OS concept behind it** — not what the code does, but what it shows about
how the operating system works:
An app reaches hardware through a library and a request. We use AVFoundation, which sends the request to macOS camera services. Then this talks to a driver. The camera is held by the macOS camera service, not by BoothCam.

**One thing I got wrong at first, and how I found out:**
I expected the camera process would start when BoothCam opened the camera, but when the Mac was turned on, the macOS camera service turned on. The camera didn't wait to be needed; it is always ready. We found this out by having an ID number for each instance of the camera processes. The IDs were there the whole time and the same each time.

---

## Everyone else's parts

Two sentences each, written during or right after the team meeting. Aim for the **concept**, not
a description of the code.

- **Device stack** — I/O layers, abstraction *(Sarah)*: My section — see "My part" above.

- **Camera & cleanup** — permissions, resource release, background queues *(Stephen)*: AVCaptureDevice.default finds the camera; if nothing comes back, there is no camera. AVCaptureDeviceInput(device:) opens the camera, and if it fails it tells us why. Then each frame arrives on a background queue separate from the screen. The newest frame will go to the main thread to the screen, and @Published tells the screen to update. It is important to release the camera because other apps won't be able to use the camera while this app is running.

- **Snap** — copying vs. holding a reference to a reused buffer *(Georgia)*: We create the copies with createCGImage into new memory for only the photos. The camera uses buffers and keeps refilling them; one includes the live frame. The code fixes this by making copies, so the buffer goes back to the camera and the photo never changes. We proved the captured photo doesn't change by doing a wave test. The tester smiles and takes a photo and then waves afterwards, showing a live frame and a still frame.

- **Filter** — how pixels are stored, where the work runs *(Calli)*: Grayscale turns the red, green, blue (0–255) pixels into black and white by replacing the sequence with one brightness number. The invert flips each number to 255 minus it. The filter runs in Core Image, Apple's image library.

- **Testing** — how OS version, permissions and hardware change behaviour *(Ella)*: My computer is the oldest, so the code is set to handle the minimum. Every time a computer tested the app, macOS chose the built-in camera.

**The section that took me longest to get, and what made it click:**
Snap was the hardest to understand on the concept level; in testing it was the easiest. The hardest thing was how the buffer is used to store the camera's imagery. The buffers hold the live frame, and the snap is the photo being copied out of them. The thing that helped me understand was running through it with the testing.

---

## The drill

**Section I was drawn for, and how it went:**

---

## AI use

**What I asked, what I checked, and what was wrong or missing:**
See my five rows in ai-use-log.md.

(Also add a row to [`ai-use-log.md`](ai-use-log.md).)

---

## Looking back

**The OS concept I understand much better now:**
Opening the camera was the easiest to follow. I am used to a more logic-based tree statement, "if this, then this" kind of coding, where one decision has an effect on what happens next. The user decides to let the camera be in use, then macOS chooses which camera to use (the one on the computer). It also checks if there is a camera that can be used and if the app has permission to use that camera. The app isn't what controls the camera; it has to ask the OS.

**How this connects to threads (Project 1) and memory (Project 2):**
Like Project 1, we made separate jobs work at the same time. The frames arrive on a background thread, the screen runs on the main thread, and starting the camera is slow, so this is also on the background thread. If this all happened at once on the main thread, we would experience the app moving slowly, since one task would have to complete before the rest could. Like Project 2, we use buffers to bring in and store the movement/frames from the camera.
