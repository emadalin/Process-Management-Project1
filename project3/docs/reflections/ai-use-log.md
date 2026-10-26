# AI Use Log

Shared file. The point is to show AI helped us **learn** rather than replaced the learning, so
each entry needs the part where we checked it and the part where we were wrong.

Log significant uses, not every small question. Also mention your own uses in your personal log.

> **Everyone should be able to tell at least two of these stories**, since anyone could be drawn
> for section 4 (research & troubleshooting).

**Entry template:**
```
## [Date] — [Who] — [Topic]
- What we asked:
- What AI suggested:
- What we checked (docs, testing, running it, a teammate):
- What was wrong, missing, or changed:
- What we learned:
```

---

> **The five entries below are drafts.** The facts are filled in from what actually happened
> during setup — Sarah was present for all of them. **The "what we learned" line is blank on
> purpose: that part is yours to write, in your own words.** Confirm or correct the facts too.

---

## 2026-10-22 — Sarah + Claude Code — The `import Combine` error

- **What we asked:** write a `CameraManager` stub that publishes the latest frame to SwiftUI.
- **What AI suggested:** an `ObservableObject` with `@Published` properties, importing
  `AVFoundation`, `CoreImage` and `SwiftUI`.
- **What we checked:** built it. The build failed with *"static subscript
  'subscript(_enclosingInstance:wrapped:storage:)' is not available due to missing import of
  defining module 'Combine'"* — an error that never mentions `@Published`.
- **What was wrong:** `@Published` comes from Combine, and SwiftUI did not re-export it here.
  Adding `import Combine` fixed it.
- **What we learned:**

## 2026-10-22 — Sarah + Claude Code — "Add the key to Info.plist"

- **What we asked:** how to declare camera permission.
- **What AI suggested:** add `NSCameraUsageDescription` to `Info.plist`, and tick App Sandbox →
  Camera to get a `.entitlements` file.
- **What we checked:** looked for both files. **Neither exists.**
- **What was wrong:** Xcode 26 has no `Info.plist` file and no `.entitlements` file for this.
  Both are build settings — `INFOPLIST_KEY_NSCameraUsageDescription` and
  `ENABLE_RESOURCE_ACCESS_CAMERA` — and Xcode synthesizes the entitlement at signing. We
  confirmed it reached the built app with
  `codesign -d --entitlements - --xml BoothCam.app`, which reported
  `com.apple.security.device.camera`.
- **What we learned:**

## 2026-10-22 — Sarah + Claude Code — Xcode staged files we never asked for

- **What we asked:** nothing. This one we noticed in `git status`.
- **What AI suggested:** add `.DS_Store`, `*.zip` and `xcuserdata/` to `.gitignore`.
- **What we checked:** `git status` after editing `.gitignore`. The files were **still staged**.
- **What was wrong:** Xcode had already staged them, and `.gitignore` does nothing for a file
  that is already in the index — it had to be removed with `git rm --cached`. Without that we
  would have committed a 7.5 MB zip and Sarah's window positions to a five-person repo.
- **What we learned:**

## 2026-10-22 — Sarah + Claude Code — A device-stack prediction that was wrong

- **What we asked:** what does the camera stack look like under AVFoundation, and can we observe it?
- **What AI suggested:** the camera daemons would **appear** when the camera opened, so running
  `ps` before and after would show the stack coming to life.
- **What we checked:** ran `ps` with the app closed, running, and after quitting.
- **What was wrong:** the daemons never appear — PIDs 697–699 had been alive since boot, camera
  or no camera. What changes is their **CPU**: `appleh13camerad` went 0.0% → 4.5% while frames
  flowed, spiked to **29.8%** while releasing the device, then settled back. `UVCAssistant`
  stayed at 0.0% the whole time, because no USB webcam was attached — an accidental controlled
  comparison showing the two driver paths really are separate.
- **What we learned:**

## 2026-10-22 — Sarah + Claude Code — Measuring with the wrong tool

- **What we asked:** measure the daemons' CPU while the camera runs.
- **What AI suggested:** `ps -axo pcpu`.
- **What we checked:** the numbers only moved 0.0% → 0.1%, which looked like nothing was
  happening.
- **What was wrong:** `ps` reports a **decaying lifetime average**, and these processes had been
  running since boot, so real activity was averaged away to almost nothing. `top -l 2` gives an
  instantaneous sample and showed 4.5% and 29.8% instead.
- **What we learned:**

---

## Further entries

<!-- Copy the template above. -->
