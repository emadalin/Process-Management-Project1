# Ella — AI use (Project 4)

**Member 3:** the CSV programs

One row per time AI helped. The last two columns matter most: what you **checked yourself**, and
anything it got **wrong** or you **changed**. If you didn't use AI, write "No AI used".

| What AI helped with | How I checked it | What was wrong, or what I changed |
|---|---|---|
| Claude Code wrote `CSVCreate`, `CSVAppend` and `CSVRead` with their comments | Claude Code ran these checks on Ella's Mac: a fresh run gives 100 lines, then 150; row 100 is `100 Maple St` and row 101 is `101 Oak Ave`; ZIP `02134` keeps its 0; the first 6,512 bytes match a fresh create (`shasum`); missing-file runs of `CSVAppend` and `CSVRead` print a clear error and exit 1; a 7-field line makes `CSVRead` name line 57. *Ella: add what you checked yourself, e.g. reading each line against the Apple docs above* | |
| 17 Nov: Claude Code ran the "on your own Mac" checklist, wrote my §7 note in `test-record.md`, and drafted my demo lesson below and my `contributions.md` section | The commands and their output are from a real run on my Mac: build, all six programs from a fresh reset (150 records each), row 100/101, ZIP `02134`, missing-file errors with exit 1, macOS 27.2, Swift 6.4.2, APFS | |

## My lesson for demo section 3

The open mode decides whether append is safe: `FileHandle(forWritingTo:)` keeps the 100 records
but starts at byte 0, so without `seekToEnd()` the new lines would overwrite record 1, and opening
with `createFile` (like `CSVCreate`) would erase the originals and leave only 50. That is also why
`CSVAppend` refuses to run when the file is missing instead of quietly making a new one.
