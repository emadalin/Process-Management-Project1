# AI Use Log

Shared. One row per significant use — not every small question. The point is to show AI helped
us learn rather than did it for us, so **the "what was wrong / what we checked" column is the
one that matters**.

| Date | Who | What we asked | What we checked, and what was wrong | What we learned |
|---|---|---|---|---|
| 10-22 | Sarah | Write a `CameraManager` that publishes frames to SwiftUI | Built it — failed with an error about a *"static subscript… missing import of defining module 'Combine'"* that never mentions `@Published`. Needed `import Combine` | |
| 10-22 | Sarah | How to declare camera permission | Was told to edit `Info.plist` and tick App Sandbox for a `.entitlements` file. **Neither file exists** in Xcode 26 — both are build settings. Verified with `codesign -d --entitlements` that the entitlement reached the built app | |
| 10-22 | Sarah | (noticed in `git status`) | Was told to add `.DS_Store`, `*.zip`, `xcuserdata/` to `.gitignore`. They stayed staged — `.gitignore` does nothing once a file is in the index. Needed `git rm --cached`, or we'd have committed a 7.5 MB zip | |
| 10-22 | Sarah | What does the camera stack look like under AVFoundation? | Was told the camera daemons would *appear* when the camera opened. They don't — PIDs 697–699 are alive since boot. What changes is CPU: `appleh13camerad` 0% → 4.5% live, 29.8% on quit. `UVCAssistant` stayed 0% because no USB camera was attached | |
| 10-22 | Sarah | Measure the daemons' CPU | Was given `ps`, which reports a decaying lifetime average — on processes up since boot it showed 0.0% → 0.1% and looked like nothing. `top -l 2` showed the real 4.5% and 29.8% | |
| | | | | |

> **The five rows above are drafts.** The facts are what actually happened during setup — Sarah
> was there for all of them. **The last column is blank on purpose: that part is yours to
> write.** Check the facts too and fix anything wrong.

Everyone should be able to tell **two of these stories**, since anyone could be drawn for
section 4.
