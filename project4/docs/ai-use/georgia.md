# Georgia — AI use (Project 4)

**Member 2:** RecordKit

One row per time AI helped. The last two columns matter most: what you **checked yourself**, and
anything it got **wrong** or you **changed**. If you didn't use AI, write "No AI used".

| What AI helped with | How I checked it | What was wrong, or what I changed |
|---|---|---|
| 10 Nov: Claude Code wrote `RecordKit` (`Person.swift`, `Records.swift`, `Table.swift`) with its comments | Built it and tested with 3 records before handing it to Ella and Calli; checked that record 1 and 101 both get ZIP `02134`, that row 100 is `100 Maple St` and row 101 is `101 Oak Ave`, and that a line with 7 fields makes `fromCSVLine` throw | Sarah later found the 555 comment in `Records.swift` was wrong: only 555-0100 to 0199 are reserved for fiction, and ours run 0001–0150. She fixed the comment on 15 Nov; the data stayed the same |
| 16 Nov: Claude Code ran the "on your own Mac" checklist and drafted my notes in `test-record.md` §7, this file, my `contributions.md` section and the Codable row in `sources.md` | The commands and their output are from a real run on my Mac: build, fresh run of all six programs (150 records each), row 100/101 boundary, ZIP `02134`, missing-file errors with exit code 1, versions and APFS. I read each draft against that output and changed it into my own words | |

## My lesson for demo section 3

Making ZIP and phone `String`s instead of numbers was a design decision that mattered: as an
`Int`, ZIP `02134` would turn into `2134` in both files. Putting Boston first in the city list
means record 1 and record 101 both get that ZIP, so every test run checks it automatically.
