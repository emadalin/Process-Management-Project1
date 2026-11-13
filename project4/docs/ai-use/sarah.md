# Sarah — AI use (Project 4)

**Member 1:** setup, file-system layers, README

One row per time AI helped. The last two columns matter most: what you **checked yourself**, and
anything it got **wrong** or you **changed**. If you didn't use AI, write "No AI used".

| What AI helped with | How I checked it | What was wrong, or what I changed |
|---|---|---|
| Claude Code set up the package skeleton and `reset.sh`, drafted the README and this list, and wrote the layers doc and `docs/file-api-check.swift` | Ran `swift build` and all six stubs; tested `reset.sh` with a third file in `output/`; ran `file-api-check.swift` and copied its real output into the doc; fetched every Apple link and checked each quote against the page or man page | |
| Claude Code drafted `docs/study-guide.md` from the committed code and test runs, and recorded the CSV append evidence | Every line number checked against the source; the JSON line count (1,501) and ZIP counts (15 per format) re-measured; the `stat` and `shasum` evidence comes from a real run on my Mac | It first gave the wrong line number for `zip` in `Person.swift` (19, not 20), caught when checking |

## My lesson for demo section 3

_One or two sentences: a design decision or troubleshooting lesson, in your own words._
