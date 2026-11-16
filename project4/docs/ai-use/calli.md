# Calli — AI use (Project 4)

**Member 4:** the JSON programs

One row per time AI helped. The last two columns matter most: what you **checked yourself**, and
anything it got **wrong** or you **changed**. If you didn't use AI, write "No AI used".

| What AI helped with | How I checked it | What was wrong, or what I changed |
|---|---|---|
| 10 Nov: Claude Code wrote all three JSON programs (`JSONCreate`, `JSONAdd`, `JSONRead`) and their comments, before `RecordKit` existed, using the agreed names `Person`, `makeRecords(from:count:)` and `printTable(_:)` | Claude Code built them against a temporary `RecordKit` stand-in (deleted, never committed) and ran them on my Mac: 100 → 150, row 100 Maple / row 101 Oak, ZIP `02134` kept, missing file → error and exit 1, a deleted `]` → parse error with the same `shasum` before and after | Pushing to `main` would have broken `swift build` for everyone until `RecordKit` landed, so the programs went on a `calli-json` branch first |
| 13 Nov: Claude Code merged `calli-json` into `main` after Georgia's `RecordKit` landed | Re-ran every test above against the real `RecordKit` on my Mac; `main` built cleanly after the merge | Changed my error messages to match the wording Stephen drafted in `test-record.md` §6 (e.g. `could not parse` instead of `is not valid JSON`) |
| 16 Nov: Claude Code ran the "on your own Mac" checklist, wrote my §7 note in `test-record.md`, filled in my "Used by" rows in `sources.md`, and drafted this file and my contribution statement | The commands and their output are from a real run on my Mac: build, all six programs from a fresh reset (150 records each), row 100/101, ZIP `02134`, missing-file errors with exit 1, macOS 26.6.2, Swift 6.4, APFS. **My own check:** I then ran `reset.sh`, `JSONCreate`, `JSONAdd` and `JSONRead` myself in Terminal; the file it left has 150 records, record 100 is `100 Maple St`, record 101 is `101 Oak Ave`, and records 1 and 101 keep ZIP `02134` | Sarah's testing showed `JSONCreate` writes the keys in a different order each run, so the file's checksum changes even though the data doesn't. The programs weren't changed: the order doesn't affect decoding, and Sarah's fingerprint uses `JSONRead`'s table instead |

## My lesson for demo section 3

The JSON file can't be added to the way the CSV can: it is one array, so any bytes written after the closing `]` make the whole file invalid. `JSONAdd` has to read and decode the whole array first, and if decoding fails it stops before writing anything. That is why a broken file is left exactly as it was, and why the program reports a missing file and bad JSON as two different errors.
