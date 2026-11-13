# Ella — AI use (Project 4)

**Member 3:** the CSV programs

One row per time AI helped. The last two columns matter most: what you **checked yourself**, and
anything it got **wrong** or you **changed**. If you didn't use AI, write "No AI used".

| What AI helped with | How I checked it | What was wrong, or what I changed |
|---|---|---|
| Claude Code wrote `CSVCreate`, `CSVAppend` and `CSVRead` with their comments | Claude Code ran these checks on Ella's Mac: a fresh run gives 100 lines, then 150; row 100 is `100 Maple St` and row 101 is `101 Oak Ave`; ZIP `02134` keeps its 0; the first 6,512 bytes match a fresh create (`shasum`); missing-file runs of `CSVAppend` and `CSVRead` print a clear error and exit 1; a 7-field line makes `CSVRead` name line 57. *Ella: add what you checked yourself, e.g. reading each line against the Apple docs above* | |

## My lesson for demo section 3

_One or two sentences: a design decision or troubleshooting lesson, in your own words._
