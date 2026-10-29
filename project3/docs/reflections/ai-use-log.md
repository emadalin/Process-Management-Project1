# AI Use Log

Shared. One row per significant use — not every small question. The point is to show AI helped
us learn rather than did it for us, so **the "what was wrong / what we checked" column is the
one that matters**.

| Date | Who | What we asked | What we checked, and what was wrong | What we learned |
|---|---|---|---|---|
| 10-22 | Sarah | Write a `CameraManager` that publishes frames to SwiftUI | Built it — failed with an error about a *"static subscript… missing import of defining module 'Combine'"* that never mentions `@Published`. Needed `import Combine` | Claude Code wrote the camera code without importing Combine, a library that contains @Published. @Published is the label that tells the screen to redraw when the value changes. The error did not include @Published, but this was fixed by import Combine. |
| 10-22 | Sarah | How to declare camera permission | Was told to edit `Info.plist` and tick App Sandbox for a `.entitlements` file. **Neither file exists** in Xcode 26 — both are build settings. Verified with `codesign -d --entitlements` that the entitlement reached the built app | Claude Code wanted to edit the Info.plist, a file that holds the sentence in the permission popup and a "camera is allowed" switch for the app's sandbox. In Xcode the Info.plist did not exist; instead both settings are build settings. We checked the finished app with codesign to make sure the camera permission worked. |
| 10-22 | Sarah | (noticed in `git status`) | Was told to add `.DS_Store`, `*.zip`, `xcuserdata/` to `.gitignore`. They stayed staged — `.gitignore` does nothing once a file is in the index. Needed `git rm --cached`, or we'd have committed a 7.5 MB zip | Xcode had staged some junk files, so they were added to the list for the next commit. .gitignore didn't stop them because they were already staged. In order to fix this we removed them with git rm --cached. |
| 10-22 | Sarah | What does the camera stack look like under AVFoundation? | Was told the camera daemons would *appear* when the camera opened. They don't — PIDs 697–699 are alive since boot. What changes is CPU: `appleh13camerad` 0% → 4.5% live, 29.8% on quit. `UVCAssistant` stayed 0% because no USB camera was attached | When the Mac was turned on, the macOS camera service turned on. The camera didn't wait to be needed; it is always ready. The IDs were there the whole time and the same each time. |
| 10-22 | Sarah | Measure the daemons' CPU | Was given `ps`, which reports a decaying lifetime average — on processes up since boot it showed 0.0% → 0.1% and looked like nothing. `top -l 2` showed the real 4.5% and 29.8% | ps is the average of CPU usage throughout the whole program's life. This begins at the opening of the Mac, so if we only work for a few seconds, this would not be an effective way to measure CPU since the average would disappear. top is how we fixed it. top shows current changes; it showed the driver jumping from 0% to 4.5% while running the program. |
| 10-27 | Ella | Claude Code: pull changes, gather my Mac's environment info, fill in my test record from what I reported | Ran every feature check myself and watched the camera light go off on quit. Claude had ticked the quit check before I'd confirmed the light. I mistook the app's "permission denied" message for the system prompt; Claude caught it, and I reset permission and confirmed the real prompt wording from a screenshot | From this, I learned that the permission prompt comes directly from MacOS, while the "permission denied" message comes from the BoothCam reacting to what the MacOS allows. |
| | | | | |

> Sarah's five rows and Ella's row are complete — the facts are what happened during setup and
> the last column is in each person's own words.

Everyone should be able to tell **two of these stories**, since anyone could be drawn for
section 4.
