# Test Record — Project 4 (People Files: CSV and JSON)

Owner: Member 5 (Stephen), demo section 3. Raw terminal output for every test below is saved in
[`docs/test-output/`](test-output/) — this file is the write-up, the folder is the evidence.

---

## 1. Environment

```
macOS 26.5.2 (25F84), arm64
swift-driver version: 1.148.6, Apple Swift version 6.3.2 (swiftlang-6.3.2.1.108 clang-2100.1.1.101)
Target: arm64-apple-macosx26.0
```

| Volume | File System |
|---|---|
| `/` (system, read-only) | APFS |
| `output/`'s own volume | APFS |

Full output: [`test-output/00-environment.txt`](test-output/00-environment.txt).

## 2. Status at time of testing

**CSV workflow (Ella, Member 3): done, fully tested below.**
**JSON workflow (Calli, Member 4): done, fully tested below.** The stubs from the first testing
pass (`JSONCreate`/`JSONAdd`/`JSONRead` each printing `"not written yet"`) were replaced with the
real programs on 14 Nov; see [`test-output/05-json-current-state-STUBS.txt`](test-output/05-json-current-state-STUBS.txt)
for what they looked like before, and the sections below for what they do now.

## 3. Test results

| # | Test | CSV | JSON | Evidence |
|---|---|---|---|---|
| 1 | Fresh run: 100 after create | ✅ pass — `wc -l` confirms 100 | ✅ pass — program prints `Wrote 100 records to output/people.json` | [`01-csv-fresh-run.txt`](test-output/01-csv-fresh-run.txt), [`06-json-fresh-run.txt`](test-output/06-json-fresh-run.txt) |
| 2 | 150 after append/add | ✅ pass — `wc -l` confirms 150 | ✅ pass — program prints `Added 50 records to output/people.json: 100 → 150` | [`01-csv-fresh-run.txt`](test-output/01-csv-fresh-run.txt), [`06-json-fresh-run.txt`](test-output/06-json-fresh-run.txt) |
| 3 | Records 1–100 unchanged and in order; 101–150 follow | ✅ pass — row 100 is `100 Maple St`, row 101 is `101 Oak Ave`, table in order 1→150 | ✅ pass — identical boundary: row 100 `100 Maple St`, row 101 `101 Oak Ave`, same generator as CSV | [`02-csv-read-table.txt`](test-output/02-csv-read-table.txt), [`07-json-read-table.txt`](test-output/07-json-read-table.txt) |
| 4 | Leading-zero ZIP survives | ✅ pass — row 1 and row 101 both show `02134` (Boston), full 5 digits, not truncated | ✅ pass — same: row 1 and row 101 both `02134` in the decoded `[Person]`, confirming `JSONDecoder` kept `zip` as `String`, not `Int` | [`02-csv-read-table.txt`](test-output/02-csv-read-table.txt), [`07-json-read-table.txt`](test-output/07-json-read-table.txt) |
| 5 | Missing file: read program | ✅ pass — `CSVRead: could not open output/people.csv for reading (file does not exist)`, exit 1, no crash | ✅ pass — `JSONRead: could not open output/people.json for reading (file does not exist)`, exit 1, no crash | [`03-csv-missing-file.txt`](test-output/03-csv-missing-file.txt), [`08-json-missing-file.txt`](test-output/08-json-missing-file.txt) |
| 6 | Missing file: append/add program | ✅ pass — `CSVAppend: could not open output/people.csv for appending (file does not exist; run CSVCreate first)`, exit 1, no crash | ✅ pass — `JSONAdd: could not open output/people.json for reading (file does not exist; run JSONCreate first)`, exit 1, no crash | [`03-csv-missing-file.txt`](test-output/03-csv-missing-file.txt), [`08-json-missing-file.txt`](test-output/08-json-missing-file.txt) |
| 7 | Malformed line/record (wrong field count) | ✅ pass — line 101 cut to 7 fields; `CSVRead: could not read line 101 of output/people.csv (expected 8 fields, found 7)`, exit 1, no crash. File restored from a backup copy afterward, re-verified at 150 lines | n/a (JSON's equivalent is a missing `]`, not a field-count check — see test 8) | [`04-csv-malformed-line.txt`](test-output/04-csv-malformed-line.txt) |
| 8 | Malformed JSON (delete a `]`) → file unchanged (`shasum` before/after) | n/a | ✅ pass — deleted the trailing `]`; `JSONAdd` reported `DecodingError.dataCorrupted` ("Unexpected end of file"), exit 1. `shasum -a 256` before and after the failed run are **identical** — the file was genuinely never touched, not just "probably fine" | [`09-json-malformed.txt`](test-output/09-json-malformed.txt) |

**Every test above was run for real, on both formats** — nothing in the ✅ columns is assumed or
copied from another teammate's record. The JSON file was restored from a backup copy after test 8,
then re-verified with `JSONRead` (still 150 records, same hash as before the corruption).

## 4. How we verified record preservation (CSV and JSON)

Three independent checks per format, not just "the count looks right":
1. **Count**: `wc -l output/people.csv` → 100 after `CSVCreate`, 150 after `CSVAppend`.
   `JSONCreate`/`JSONAdd` print their own before→after counts (`100 → 150`), cross-checked against
   `JSONRead`'s `Read 150 records`.
2. **Boundary content**: the printed table shows row 100 as `100 Maple St` and row 101 as
   `101 Oak Ave` in **both** formats — the exact street-name switch the record generator is
   designed to produce, so a shifted or duplicated record would show up immediately.
3. **Corruption test doubles as a change-detection check, in both formats**: for CSV, corrupting
   line 101 and confirming `CSVRead` catches it by line number, then restoring and re-confirming
   `wc -l` still reports 150. For JSON, deleting the closing `]` and comparing a SHA-256 hash of
   the file from immediately before running `JSONAdd` to immediately after the (failed) run —
   identical hashes prove the file was never touched, which is a stronger claim than "the count
   still looks right."

## 5. How Swift reports these errors (talking points for demo section 3)

- **Swift's model is thrown errors, caught with `do`/`catch`.** `FileHandle` and `FileManager`
  calls that can fail are marked `throws`; callers wrap them in a `do` block and catch what comes
  back, rather than returning a special "error" value that's easy to ignore.
- **File problems surface as `CocoaError`** (via `NSError`/`error.localizedDescription`) — e.g.
  opening a file that doesn't exist. `CSVCreate`, `CSVAppend` and `CSVRead` all catch this the same
  way and print `error.localizedDescription` inside their own message, so the underlying OS reason
  is never hidden, just prefixed with which program and which file.
- **A custom error type where Foundation has nothing to offer**: a CSV line with the wrong field
  count isn't a file-system error at all, so `Person.fromCSVLine(_:)` defines its own
  `CSVLineError: Error, CustomStringConvertible` (`Person.swift:73-79`) rather than forcing a bad
  shape onto `CocoaError`. `CSVRead` catches it and adds the line number, which the error itself
  doesn't know.
- **JSON uses a third kind**: `JSONDecoder` failures surface as `DecodingError` — a different case
  from both of the above. Confirmed directly in test 8: deleting the closing `]` produced
  `DecodingError.dataCorrupted` ("Unexpected end of file"), caught in `JSONAdd`'s own `catch`
  block (`JSONAdd/main.swift:26-31`) *before* step 3 (appending new records) or step 4 (writing)
  ever runs — exactly why the file came out byte-for-byte unchanged.
- **Why this file needed `CSVLineError` instead of just a generic message:** `CSVRead` already
  knows the line number from iterating the file; the error type only needs to carry what it
  uniquely knows (the field count), and the two are combined at the print site
  (`CSVRead/main.swift:50`), not duplicated into the error type itself.

## 6. Error-message convention (coordinated with Member 3 / Member 4)

Every error message in all six programs follows one shape —
`<Program>: <could not VERB> <file> (<reason>)` — confirmed by reading every program's source
directly, not just its output, and by actually triggering every path in §3:

```
CSVCreate: could not create output/people.csv (is the output folder there? run from inside project4/)
CSVCreate: could not write to output/people.csv (<system reason>)
CSVAppend: could not open output/people.csv for appending (file does not exist; run CSVCreate first)
CSVAppend: could not append to output/people.csv (<system reason>)
CSVRead: could not open output/people.csv for reading (file does not exist)
CSVRead: could not read output/people.csv (<system reason>)
CSVRead: could not read line N of output/people.csv (expected 8 fields, found M)

JSONCreate: could not create output/people.json (is the output folder there? run from inside project4/)
JSONCreate: could not encode the records as JSON (<error>)
JSONCreate: could not write to output/people.json (<system reason>)
JSONAdd: could not open output/people.json for reading (file does not exist; run JSONCreate first)
JSONAdd: could not parse output/people.json (<DecodingError> — file left unchanged)
JSONAdd: could not write to output/people.json (<system reason>)
JSONRead: could not open output/people.json for reading (file does not exist)
JSONRead: could not parse output/people.json (<DecodingError>)
```

The JSON lines above are what Calli actually shipped (`JSONAdd/main.swift:15-29`,
`JSONRead/main.swift:13-27`) — she matched the proposal from this record almost exactly, including
the "file left unchanged" parenthetical on `JSONAdd`'s parse-error line, which is the one message
that needs to actively reassure a reader rather than just report a fact: a `.atomic` write can't
partially corrupt the file on success, but a *rejected* write (caught before it happens) still
has to say so, since "parse failed" alone doesn't tell you whether anything was saved.

## 7. Problems encountered while testing

**No special fixes needed, either pass.** Every CSV and JSON test behaved exactly as
`project4-team-tasks.md` and the README describe, on the first run — no setup issues, no
surprising errors, no need to patch anything in `RecordKit` or either workflow's programs to get a
test to pass. One self-inflicted slip during testing, not a bug in the project: a backup-file
script used `$$` (the shell's own PID) to name a temp copy across two separate `Bash` calls, and
since each call is its own shell process, the PID differed and the first restore attempt couldn't
find the file. Fixed by listing `/tmp` for the actual filename and restoring from that; the real
JSON file was never at risk, since the corruption only ever touched `output/people.json`, not the
backup in `/tmp`.

## 8. Extra case: an empty (0-byte) file — a real asymmetry, not a guess

Neither format's spec calls this out explicitly, so it was worth checking directly rather than
assuming the two formats fail the same way. They don't:

| | Result | Exit code |
|---|---|---|
| `CSVRead` on an empty file | Prints an empty table (header + dashes only) and **`Read 0 records from output/people.csv`** — no error at all | 0 |
| `JSONRead` on an empty file | `JSONRead: could not parse output/people.json (DecodingError.dataCorrupted...)` — treated as a parse failure, same path as test 8 | 1 |

**Why they differ**: an empty CSV file is zero *valid* lines — there's nothing to fail to parse,
so `CSVRead`'s loop just never runs. An empty JSON file is zero bytes of a required structure (an
array needs at least `[]`), so `JSONDecoder` correctly calls it corrupted rather than "empty."
Worth mentioning if asked why the two formats don't behave identically on the same kind of
malformed input — it's not an inconsistency in our code, it's what the two formats' definitions
of "valid" actually require. Evidence: [`10-empty-file.txt`](test-output/10-empty-file.txt). Both
files were backed up before this test and restored afterward, re-verified at 150 records each.

## 9. Open items

- [ ] Optional `verify.sh` that runs the whole workflow end-to-end and checks both formats' counts
      with `wc -l` (CSV) and the read program's own printed count (JSON) — both workflows are done
      now, so this could be written at any point before the demo
