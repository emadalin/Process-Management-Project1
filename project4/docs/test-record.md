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
**JSON workflow (Calli, Member 4): still stubs** — `JSONCreate`, `JSONAdd`, `JSONRead` each just
print `"<name>: not written yet (file: output/people.json)"` and exit 0. Confirmed by running all
three; see [`test-output/05-json-current-state-STUBS.txt`](test-output/05-json-current-state-STUBS.txt).
**None of the JSON tests in §3 can run for real yet** — rows are marked **BLOCKED**, not skipped,
so this isn't mistaken for "passed." This section gets filled in as soon as the real programs land.

## 3. Test results

| # | Test | CSV | JSON | Evidence |
|---|---|---|---|---|
| 1 | Fresh run: 100 after create | ✅ pass — `wc -l` confirms 100 | ⬜ BLOCKED | [`01-csv-fresh-run.txt`](test-output/01-csv-fresh-run.txt) |
| 2 | 150 after append/add | ✅ pass — `wc -l` confirms 150 | ⬜ BLOCKED | [`01-csv-fresh-run.txt`](test-output/01-csv-fresh-run.txt) |
| 3 | Records 1–100 unchanged and in order; 101–150 follow | ✅ pass — row 100 is `100 Maple St`, row 101 is `101 Oak Ave`, table in order 1→150 | ⬜ BLOCKED | [`02-csv-read-table.txt`](test-output/02-csv-read-table.txt) |
| 4 | Leading-zero ZIP survives | ✅ pass — row 1 and row 101 both show `02134` (Boston), full 5 digits, not truncated | ⬜ BLOCKED | [`02-csv-read-table.txt`](test-output/02-csv-read-table.txt) |
| 5 | Missing file: read program | ✅ pass — `CSVRead: could not open output/people.csv for reading (file does not exist)`, exit 1, no crash | ⬜ BLOCKED | [`03-csv-missing-file.txt`](test-output/03-csv-missing-file.txt) |
| 6 | Missing file: append/add program | ✅ pass — `CSVAppend: could not open output/people.csv for appending (file does not exist; run CSVCreate first)`, exit 1, no crash | ⬜ BLOCKED | [`03-csv-missing-file.txt`](test-output/03-csv-missing-file.txt) |
| 7 | Malformed line/record (wrong field count) | ✅ pass — line 101 cut to 7 fields; `CSVRead: could not read line 101 of output/people.csv (expected 8 fields, found 7)`, exit 1, no crash. File restored from a backup copy afterward, re-verified at 150 lines | n/a (JSON's equivalent is a missing `]`, not a field-count check — see §5) | [`04-csv-malformed-line.txt`](test-output/04-csv-malformed-line.txt) |
| 8 | Malformed JSON (delete a `]`) → file unchanged (`shasum` before/after) | n/a | ⬜ BLOCKED | — |

**Every CSV test that could run was run for real** — nothing in the ✅ column above is assumed or
copied from another teammate's record.

## 4. How we verified record preservation (CSV)

Three independent checks, not just "the count looks right":
1. **Row count**: `wc -l output/people.csv` → 100 after `CSVCreate`, 150 after `CSVAppend`.
2. **Boundary content**: the printed table (`CSVRead`) shows row 100 as `100 Maple St` and row 101
   as `101 Oak Ave` — the exact street-name switch the record generator is designed to produce, so
   a shifted or duplicated record would show up immediately.
3. **Malformed-line test doubles as a change-detection check**: corrupting line 101, confirming
   `CSVRead` catches it by line number, then restoring from a backup and re-confirming `wc -l`
   still reports 150 proves both that the error path works *and* that the restore was exact.

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
- **JSON will use a third kind**: once written, `JSONDecoder` failures surface as `DecodingError`
  — a different case from both of the above, which is exactly why `JSONAdd`'s spec (per
  `project4-team-tasks.md:100-104`) requires decoding to succeed *before* any write happens: a
  `DecodingError` has to stop the program with nothing touched, not a partial file.
- **Why this file needed `CSVLineError` instead of just a generic message:** `CSVRead` already
  knows the line number from iterating the file; the error type only needs to carry what it
  uniquely knows (the field count), and the two are combined at the print site
  (`CSVRead/main.swift:50`), not duplicated into the error type itself.

## 6. Error-message convention (coordinated with Member 3 / Member 4)

Every error message in the CSV programs already follows one shape —
`<Program>: <could not VERB> <file> (<reason>)` — confirmed by reading `CSVCreate`, `CSVAppend`
and `CSVRead`'s source directly, not just their output:

```
CSVCreate: could not create output/people.csv (is the output folder there? run from inside project4/)
CSVCreate: could not write to output/people.csv (<system reason>)
CSVAppend: could not open output/people.csv for appending (file does not exist; run CSVCreate first)
CSVAppend: could not append to output/people.csv (<system reason>)
CSVRead: could not open output/people.csv for reading (file does not exist)
CSVRead: could not read output/people.csv (<system reason>)
CSVRead: could not read line N of output/people.csv (expected 8 fields, found M)
```

**Recommended messages for the JSON programs**, to match this shape and the file-vs-parse
distinction `project4-team-tasks.md:100-104` requires (file error and parse error must be
reported — and look — differently, since a parse error must leave the file untouched):

```
JSONCreate: could not create output/people.json (is the output folder there? run from inside project4/)
JSONCreate: could not write to output/people.json (<system reason>)
JSONAdd: could not open output/people.json for reading (file does not exist; run JSONCreate first)
JSONAdd: could not parse output/people.json (<DecodingError description> — file left unchanged)
JSONAdd: could not write to output/people.json (<system reason>)
JSONRead: could not open output/people.json for reading (file does not exist)
JSONRead: could not parse output/people.json (<DecodingError description>)
```

The parenthetical on `JSONAdd`'s parse-error line is deliberate: it's the one place a reader needs
reassurance that the failure didn't corrupt anything, which matters more here than on any CSV
message since `.atomic` writes mean a successful write can't partially corrupt the file, but a
*rejected* write (caught before it happens) still needs to say so explicitly.

## 7. Problems encountered while testing

**No special fixes needed.** Every CSV test behaved exactly as `project4-team-tasks.md` and the
README describe on the first run — no setup issues, no surprising errors, no need to patch
anything in `RecordKit` or the CSV programs to get a test to pass. The one thing worth flagging
isn't a problem so much as a dependency: none of the JSON tests can be run for real yet (see §2),
which isn't a bug in anything, just the order the team is building in.

## 8. Open items (blocked, not forgotten)

- [ ] Re-run §3 rows 2, 4, 6, 8 for real once `JSONCreate`/`JSONAdd`/`JSONRead` are implemented
- [ ] `shasum` before/after test for the malformed-JSON case (test 8) — needs a real JSON file to corrupt
- [ ] Confirm the JSON error messages above with Calli once she writes the real programs — these are a
      starting proposal, not something she has to use verbatim
- [ ] Optional `verify.sh` — holding off until the JSON half exists, so it can check both workflows
      in one script instead of being rewritten
