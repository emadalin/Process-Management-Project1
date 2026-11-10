# Project 4: File Management — Team Task Split

**Topic:** Create, append, and read CSV and JSON files (six small programs)
**Environment:** Swift on macOS (same as Projects 1–3)
**File system:** APFS (check with `diskutil info / | grep "File System"`, **not FAT**)
**APIs:** `FileManager` + `FileHandle` (files), `JSONEncoder` / `JSONDecoder` with `Codable` (JSON)
**Repo folder:** `project4/` in `emadalin/Process-Management-Project1`
**Demo:** 30 min · **Due: Tuesday 17 November** · **Estimated effort:** ~6 hours

---

## Keep the code simple
The professor picks **who presents each section at random during the demo**, so anyone could get called on any part. Everyone has to be able to run and explain **all six programs**, including code they didn't write.
- **Only build what the assignment requires.** No extra features, no fancy table library
- **One Swift package, six tiny programs plus one shared file:**
  - `RecordKit` (shared): the `Person` struct, the record generator, the table printer, the file paths
  - `CSVCreate`, `CSVAppend`, `CSVRead`, `JSONCreate`, `JSONAdd`, `JSONRead`
- **Each program should be about 20–40 lines** and read top to bottom: open → write/read → close → print result
- **Short functions with plain names:** `makeRecords(from:count:)`, `toCSVLine()`, `printTable(_:)`
- **A comment on every important line** saying what it does and why, in plain English
- **No clever tricks:** no custom protocols, generics, extensions, or async code you can't explain out loud
- **If you can't explain a line, rewrite it or ask the team.** This goes double for anything from AI or the internet
- Before merging, **someone who didn't write the code** reads it and explains it back

## Ground rules (everyone)
- Use **fictional generated data only**, with no real people or addresses
- CSV and JSON use **separate files**: `project4/output/people.csv` and `project4/output/people.json`
- All three programs of a format point at the **same file** (paths live in one place in `RecordKit`)
- **Close every file you open**, error paths included (use `defer { try? handle.close() }`)
- Label every OS/file-system claim as **documented** (from Apple docs) or **observed** (we saw it ourselves)
- Note any source or AI suggestion you used, and what you checked or changed
- Commit your own files only; talk before editing someone else's
- Each person writes 3–5 sentences for the contribution statement

## Record format (agree on this first)
Fields in this order for CSV columns **and** both tables:

| # | Column label | JSON key | Format | Example |
|---|---|---|---|---|
| 1 | First Name | `firstName` | text | `Avery` |
| 2 | Last Name | `lastName` | text | `Nguyen` |
| 3 | Date of Birth | `dateOfBirth` | text `YYYY-MM-DD` | `1999-04-07` |
| 4 | Phone | `phone` | text `###-###-####` | `205-555-0101` |
| 5 | Street Address | `street` | text | `1 Maple St` |
| 6 | City | `city` | text | `Boston` |
| 7 | State | `state` | 2-letter text | `MA` |
| 8 | ZIP | `zip` | **text** (5 digits) | `02134` |

- **Phone and ZIP are `String`, never `Int`**, so leading zeros survive (`02134` would become `2134` as a number)
- **No commas, quotes, or line breaks** in any generated value, so CSV needs no quoting
- **Batches are easy to tell apart:** record *N* gets street number *N*. Initial batch: `1–100 Maple St`. Added batch: `101–150 Oak Ave`
- **Generation is deterministic (no random numbers)**, so a fresh run always produces the same values and we can check them
- **Every batch includes at least one ZIP starting with 0** (e.g., record 1 and record 101) as the leading-zero check

## Everyone, on your own Mac
- [ ] Pull the repo, `cd project4`, run `swift build`
- [ ] Run the full workflow from a fresh reset (see README): CSV create → append → read, JSON create → add → read
- [ ] Confirm: 100 after create ✓ 150 after add ✓ row 100 is `Maple`, row 101 is `Oak` ✓ ZIP `02134` still has its 0 ✓ missing-file error ✓
- [ ] Record: `sw_vers`, `uname -m`, `swift --version`, file system of the output folder (`diskutil info / | grep "File System"`)
- [ ] Practice explaining one program you **didn't** write to a teammate
- [ ] Add your problems/fixes (or "no special fixes needed") to the troubleshooting record

---

## Member 1: Setup, OS & File-System Research, README · `Sarah`
Owns demo section **2c (roles of the app, runtime, OS, and file system)**.
- [x] Create `project4/` as a Swift package with the `RecordKit` library target and six executable targets (stub `main.swift` in each that prints its name), then push on day 1 — pushed 10 Nov, `swift build` passes
- [x] Add `project4/output/` with a `.gitkeep`, and put both file paths in `RecordKit/Paths.swift`
- [x] Add `reset.sh` that deletes **only** `output/people.csv` and `output/people.json` (nothing else) — tested: a third file in `output/` survives a reset
- [ ] Research and write `docs/file-system-layers.md` (documented vs observed): — **written 10 Nov**, every claim labelled, evidence re-runs with `swift docs/file-api-check.swift`. Left: the `ls -l` / `stat` before-and-after checks, once the real programs work
  - What each layer does: **our code** (builds and interprets records) → **Swift/Foundation** (`FileHandle`, `JSONEncoder`) → **macOS** (system calls like `open`, `write`, `read`, `close`, file descriptors, permissions) → **APFS** (metadata, where the bytes are stored)
  - Opening a file gives a **handle/file descriptor**, not the whole file in memory
  - Confirm our file system is APFS; explain why we don't assume FAT
  - Optional observed evidence: `ls -l` sizes before/after append, `stat output/people.csv`
- [ ] Write the README: OS + Swift version, dependencies (none beyond Foundation), output folder, **run order**, how to reset, the field-format table
- [ ] Collect the sources list (Apple docs for `FileHandle`, `FileManager`, `JSONEncoder`, `JSONDecoder`, `Data.write(options: .atomic)`, APFS guide) — **seeded in `docs/sources.md`**, all links checked 10 Nov; everyone adds what they used
- [ ] Assemble the final contribution statement and resources/AI-use list

## Member 2: Shared Records & Table Display (`RecordKit`) · `Georgia`
Owns demo section **1 (showing the tables and record counts)**.
- [x] `Person` struct with the eight `String` fields, marked `Codable`
- [x] `makeRecords(from: 1, count: 100)` and `makeRecords(from: 101, count: 50)`: deterministic values from small name/city lists, street number = record number, `Maple St` vs `Oak Ave`
- [x] Make sure at least one ZIP per batch starts with `0`
- [x] `toCSVLine()` → 8 fields joined by commas; `fromCSVLine(_:)` → splits on commas, **errors if there aren't exactly 8 fields**
- [x] `printTable(_:)` → labeled, lined-up columns using the exact labels above, with a row number column
- [x] Test with 3 records first, then hand off to Members 3 and 4

## Member 3: CSV Programs 1–3 · `Ella`
Owns demo section **2a (CSV code walkthrough and why append works)**.
- [ ] **`CSVCreate`**: create the file (replacing any old one), write 100 lines, **no header**, one record per line, each line ending in `\n`, close
- [ ] **`CSVAppend`**: open the **existing** file with `FileHandle(forWritingTo:)`, `seekToEnd()`, write 50 lines, close. Fail with a clear message if the file doesn't exist (don't silently create it)
- [ ] Make sure record 101 starts on a **new line** (every line ends in `\n`, so the boundary is clean)
- [ ] **`CSVRead`**: read the file, split into lines, parse each into a `Person`, store in an array, `printTable`, print `Read 150 records from output/people.csv`
- [ ] Be ready to answer: *which open modes do we use, and what happens if append opened the file for replacement?* (The 100 originals would be erased, leaving only 50)

## Member 4: JSON Programs 4–6 · `Calli`
Owns demo section **2b (JSON code walkthrough and why we parse before writing)**.
- [ ] **`JSONCreate`**: encode 100 `Person`s as **one JSON array** with `JSONEncoder` (`.prettyPrinted`), write it, close
- [ ] **`JSONAdd`**:
  1. Read the file → if that fails, report a **file error**
  2. Decode `[Person]` → if that fails, report a **parse error** and **stop without touching the file**
  3. Append 50 new records **after** the originals
  4. Encode and write with `.atomic` (writes a temp file, then swaps it in, so a crash can't leave half a file)
- [ ] **`JSONRead`**: decode the array, `printTable` with the **same labels** as CSV, print the count of **objects** (not lines)
- [ ] Be ready to answer: *why can't we just append bytes to the JSON file?* (Text after the closing `]` is invalid JSON)

## Member 5: Testing, Error Handling & Test Record · `Stephen`
Owns demo section **3 (missing-file error and what we learned from testing)**.
- [ ] Write the error messages with Member 3/4 so each names the **operation and the file**, e.g. `CSVRead: could not open output/people.csv for reading (file does not exist)`
- [ ] Explain how Swift reports errors: **thrown errors** caught with `do/catch`. File problems come back as `CocoaError` (e.g. `.fileReadNoSuchFile`), and bad JSON comes back as `DecodingError`
- [ ] Test and log:
  - [ ] Fresh run: 100 after create, 150 after add (both formats)
  - [ ] Records 1–100 unchanged and in order; 101–150 follow (check row 100 vs 101)
  - [ ] Leading-zero ZIP survives in both formats
  - [ ] Missing file: run each read program and both add programs after `reset.sh`
  - [ ] Malformed CSV line (7 fields) → clear parse error with the line number
  - [ ] Malformed JSON (delete a `]`) → `JSONAdd` reports a parse failure and **the file is unchanged** (compare before/after with `shasum`)
- [ ] Save terminal output to `docs/test-output/` and fill in `docs/test-record.md`
- [ ] Optional: `verify.sh` that runs the whole workflow and checks the counts with `wc -l` (CSV) and the read program output (JSON)

---

## Learning & reflection (needed for an A)
- [ ] Everyone keeps a short **learning log** in `docs/reflections/<name>.md`: what you learned, what confused you, how you learned a teammate's part
- [ ] **Teach-back:** each person explains one program they didn't write to someone else before demo day; note who taught whom
- [ ] **AI-use log:** what AI helped with, and how you checked it (ran it, compared it to the docs, changed it)
- [ ] Each person writes down one **design decision or troubleshooting lesson** for demo section 3

## Work order
1. **Everyone** agrees on the record format table above (day 1)
2. **Member 1** pushes the package skeleton, output folder, paths, and `reset.sh` (day 1)
3. **Everyone** pulls and gets `swift build` passing on their own Mac
4. **Member 2** finishes `RecordKit` (Members 3 and 4 can stub with 3 hand-written records until then)
5. **Members 3 and 4** build the CSV and JSON programs in parallel
6. **Member 5** runs every test above on at least two Macs and writes the test record
7. **Member 1** finishes the README, layers doc, sources, and contribution statement
8. **Rehearsal:** each person explains a program they didn't write, then goes through the instructor questions below

## Suggested demo timing (30 min)
| Section | Presenter | Time |
|---|---|---|
| 1. Run both workflows (counts 100 → 150, tables, row 100/101 boundary) | ______ | 8 min |
| 2a. CSV code: open modes, write, append, parse, close | ______ | 4 min |
| 2b. JSON code: encode, read–parse–add–rewrite, why not append | ______ | 4 min |
| 2c. Layers: app → Swift/Foundation → macOS → APFS | ______ | 4 min |
| 3. Missing-file + malformed JSON demo, what we learned | ______ | 4 min |
| 3. Each member: contribution + one lesson (~1 min each) | Everyone | 4 min |
| Questions | Everyone | 2 min |

## Practice questions (everyone should be able to answer)
- Which open modes does the CSV workflow use, and what would happen if the append program opened the file for replacement?
- Why does the JSON add program need to parse the existing data before writing the updated array?
- How did we verify that the original records were preserved?
- Which parts does the OS handle, and which parts does our code or Foundation handle?
- How does the program tell a missing file apart from invalid JSON?
- Why are phone and ZIP stored as text?
- Does opening a file load the whole file into memory? (No, it gives us a handle)
- Why do we count JSON objects instead of lines?
- What file system is our output folder on, and how did we check?
- Where is each file closed, including when an error happens?

## Submission checklist (Canvas) — due Tuesday 17 November
- [ ] Source code for all six programs + `RecordKit`
- [ ] Setup & run instructions (run order, dependencies, output folder, how to reset)
- [ ] `people.csv` and `people.json`, each with 150 fictional records
- [ ] Test record: counts for both workflows, proof the originals were preserved, missing-file result
- [ ] Team contribution statement
- [ ] Resources list, including adapted examples and AI use

## Run order (for the README)
```
cd project4
./reset.sh
swift run CSVCreate    # → 100 records
swift run CSVAppend    # → 150 records
swift run CSVRead      # table + "Read 150 records"
swift run JSONCreate   # → 100 records
swift run JSONAdd      # → 150 records
swift run JSONRead     # table + "Read 150 records"
```
