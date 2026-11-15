# Sarah — AI use (Project 4)

**Member 1:** setup, file-system layers, README

One row per time AI helped. The last two columns matter most: what you **checked yourself**, and
anything it got **wrong** or you **changed**. If you didn't use AI, write "No AI used".

| What AI helped with | How I checked it | What was wrong, or what I changed |
|---|---|---|
| Claude Code set up the package skeleton and `reset.sh`, drafted the README and this list, and wrote the layers doc and `docs/file-api-check.swift` | Ran `swift build` and all six stubs; tested `reset.sh` with a third file in `output/`; ran `file-api-check.swift` and copied its real output into the doc; fetched every Apple link and checked each quote against the page or man page | |
| Claude Code drafted `docs/study-guide.md` from the committed code and test runs, and recorded the CSV append evidence | Every line number checked against the source; the JSON line count (1,501) and ZIP counts (15 per format) re-measured; the `stat` and `shasum` evidence comes from a real run on my Mac | It first gave the wrong line number for `zip` in `Person.swift` (19, not 20), caught when checking |
| 15 Nov: Claude Code recorded the JSON `stat` evidence in the layers doc §7, updated the README and study-guide status notes, and fixed the 555 comment in Georgia's `Records.swift` (with my OK) | The inode, size and fingerprint numbers come from a real run on my Mac; ran `JSONCreate` three times and got three different checksums, confirming the key order changes, which is why the fingerprint uses `JSONRead`'s table rows rather than the file; rebuilt after the comment change and did a clean run of all six programs | It first told me the phone numbers were all in the fiction range and only the comment was wrong. The real output showed they run 555-0001 to 0150, and only 0100–0199 is reserved. We kept the data and made the comment honest |
| 15 Nov: Claude Code checked my contribution statement against the git history and task file | Compared each sentence to the commits and ticked items | Flagged that it should say where AI helped, and that the sources list was missing |

## My lesson for demo section 3

_One or two sentences: a design decision or troubleshooting lesson, in your own words._
