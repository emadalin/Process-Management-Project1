# Study Guide — Project 4

**Read this before the demo: about 10 minutes.** The professor picks who presents each section at
random, so anyone can be asked about any program. This answers the 10 practice questions from the
task file. For each one: the answer, the line to **point at**, and the command that **shows** it.

Line numbers are as committed. Calli's JSON programs are quoted from her `calli-json` branch;
they stay the same once it's merged into main. *Drafted by Claude Code for Sarah, from the code and
from test runs on Sarah's Mac on 12 November.*

---

## The whole project in 30 seconds

- **Six programs, one shared library.** `RecordKit` (Georgia) makes the people and prints the
  table. CSV: create → append → read (Ella). JSON: create → add → read (Calli).
- **CSV can grow at the end; JSON can't.** CSV appends 50 lines to the same file. JSON has to read
  the whole array, add to it, and write the whole thing back.
- **Records 1–100 are on `Maple St`, records 101–150 on `Oak Ave`.** So row 100 → row 101 shows
  the join between the batches at a glance.

## The 10 questions

### 1. Which open modes does the CSV workflow use, and what if append opened the file for replacement?

Three, one per program:

| Program | Opens with | Point at |
|---|---|---|
| `CSVCreate` | `createFile` (replaces any old file) → `FileHandle(forWritingTo:)` | `CSVCreate/main.swift:13`, `:21` |
| `CSVAppend` | `FileHandle(forWritingTo:)` on the **existing** file → `seekToEnd()` | `CSVAppend/main.swift:21`, `:28` |
| `CSVRead` | `FileHandle(forReadingFrom:)`: read only, so it can never change the file | `CSVRead/main.swift:20` |

**If append replaced the file**, the 100 originals would be erased, leaving only the 50 new ones.

**Follow-up worth knowing:** opening for writing does *not* erase the file, but it starts at byte
0. If `CSVAppend` forgot `seekToEnd()`, it would **overwrite the first records**. We saw it happen:
`a,b` turned into `XXb` (`docs/file-system-layers.md` §3).

### 2. Why does `JSONAdd` parse the existing data before writing?

A JSON file is **one array**: `[ {…}, {…} ]`. Anything written after the closing `]` is not
valid JSON. So `JSONAdd` reads the file, decodes it into `[Person]`, adds 50, and writes the
whole array back.

Parsing first also **protects a broken file**. If decoding fails, the program stops *before*
writing anything, so the broken file is left exactly as it was.

- **Point at:** `JSONAdd/main.swift:3–5` (the reason, in the header comment), `:27` (decode), `:29`
  ("file left unchanged"), `:35` (add after the originals), `:43` (write)
- **Show it:** delete the last `]` from `output/people.json`, run `swift run JSONAdd`. It reports
  "not valid JSON, file left unchanged" and `shasum output/people.json` is the same before and
  after.

### 3. How did we verify the original records were preserved?

Four ways:

1. **Counts:** 100 after create, 150 after append or add.
2. **The boundary:** row 100 is `100 Maple St`, row 101 is `101 Oak Ave`, in both tables.
3. **Fingerprint (CSV):** `head -100 output/people.csv | shasum` is identical before and after
   `CSVAppend`.
4. **Same file (CSV):** `stat -f '%i %z' output/people.csv` shows the same inode (`60190972`) and a
   bigger size (6,512 → 9,767 bytes).

Evidence is in `docs/file-system-layers.md` §7 and Stephen's `docs/test-record.md`.

### 4. Which parts does the OS handle, and which does our code or Foundation handle?

| Layer | Does | Example |
|---|---|---|
| **Our code** | knows what a record *is*: 8 fields, which one is the ZIP | `fromCSVLine` checks for exactly 8 fields (`RecordKit/Person.swift:56`) |
| **Foundation** | bytes, handles, JSON, errors | `FileHandle`, `JSONEncoder`, `CocoaError` |
| **macOS** | file descriptors, the file position, permission checks | `open` / `read` / `write` / `close` system calls |
| **APFS** | where the bytes live, crash protection | inode numbers, copy-on-write metadata |

**The line to remember:** to everything below our code, `people.csv` is just bytes. Only our code
knows that a line is a person. Full detail: `docs/file-system-layers.md` §1–2.

### 5. How does the program tell a missing file apart from invalid JSON?

They are **two different steps**, and each step has its own `catch`, which catches a different
error type:

| What went wrong | Error type | Point at |
|---|---|---|
| File missing | `CocoaError.fileReadNoSuchFile` (code 260), thrown while **reading** | `JSONAdd/main.swift:14`, `JSONRead/main.swift:12` |
| File there but broken | `DecodingError`, thrown while **decoding** | `JSONAdd/main.swift:28`, `JSONRead/main.swift:25` |

- **Show it:** `./reset.sh` then `swift run JSONRead` → "file does not exist". Then delete a `]`
  and run it again → "is not valid JSON".
- **Watch out:** opening a missing file for **writing** gives a different code, `.fileNoSuchFile`
  (4). `CSVAppend` avoids the question by checking `fileExists` first (`CSVAppend/main.swift:13`).

### 6. Why are phone and ZIP stored as text?

As a number, `02134` becomes `2134`, because numbers drop leading zeros. A phone number is also
not something you do arithmetic on, and `205-555-0101` contains dashes.

- **Point at:** `RecordKit/Person.swift:5–6` (the comment) and `:20` (`zip: String`)
- **Show it:** `grep -c ',02134$' output/people.csv` → `15`. The first record of each batch is in
  Boston (`02134`) on purpose, to check this.

### 7. Does opening a file load the whole file into memory?

**No.** Opening gives a **handle**: a file descriptor from macOS plus a position in the file.
Nothing is read until we ask for bytes. Our check got descriptor `3` at position `0`.

**But be precise about our programs:** after opening, `CSVRead` *does* read the whole file in one
go (`readToEnd()`, `CSVRead/main.swift:27`), and the JSON programs read the whole file with
`Data(contentsOf:)`. That's a choice we made because the files are small. JSON has to be decoded
as one piece anyway.

- **Point at:** `CSVCreate/main.swift:19–21` (the comment says it)
- **Show it:** `swift docs/file-api-check.swift`, experiment 3

### 8. Why do we count JSON objects instead of lines?

Pretty-printed JSON spreads each person over about ten lines: `{`, eight fields, `}`. So 150
records is about 1,500 lines. The count has to be `people.count`, the number of objects decoded.

- **Point at:** `JSONRead/main.swift:33–35`
- **Contrast:** CSV is exactly one line per record, so `wc -l` on the CSV file *does* equal the
  record count (150).

### 9. What file system is our output folder on, and how did we check?

**APFS.**

```sh
diskutil info / | grep "File System"
diskutil info "$(df output | tail -1 | cut -d' ' -f1)" | grep "File System"   # the output folder's own volume
```

`/` is macOS's read-only system volume. The repo is actually on the separate **Data** volume,
which is why the second command checks the right place. Both say APFS.

**Why not assume FAT:** FAT has no per-file owner or permissions (macOS fakes one set for the whole
disk), and no crash protection. Our claims about permissions and safe writes depend on APFS.
Detail: `docs/file-system-layers.md` §5.

### 10. Where is each file closed, including when an error happens?

| Program | Closed by | Point at |
|---|---|---|
| `CSVCreate`, `CSVAppend` | `defer { try? handle.close() }` | line 24 in each |
| `CSVRead` | `defer { try? handle.close() }` | line 23 |
| `JSONCreate` | `defer { try? handle.close() }` | line 35 |
| `JSONAdd`, `JSONRead` | no handle of our own: `Data(contentsOf:)` and `Data.write` open and close the file inside Foundation | `JSONAdd/main.swift:9` comment |

**Why `defer`:** it runs when the `do` block ends, *however* it ends: a normal finish or a thrown
error. Every `exit(1)` in our programs comes in a `catch` *after* that block, so the file is
already closed by then.

**And if a program crashed anyway:** macOS frees every descriptor a process had open when the
process exits (`man 2 close`).

---

## Numbers worth remembering

| | |
|---|---|
| Records | 100 → 150 (50 added), both formats |
| CSV file size | 6,512 → 9,767 bytes; same inode |
| JSON after `JSONAdd` | a **new** inode, because `.atomic` swaps in a new file |
| Missing-file error codes | 260 when reading · 4 when opening to write |
| ZIP check | `02134` on records 1 and 101, 15 times per format |

## Who built what (ask them first)

| Part | Who | Files |
|---|---|---|
| Setup, layers, README | Sarah | `Package.swift`, `RecordKit/Paths.swift`, `reset.sh`, `docs/file-system-layers.md` |
| Records and table | Georgia | `RecordKit/Person.swift`, `Records.swift`, `Table.swift` |
| CSV programs | Ella | `CSVCreate`, `CSVAppend`, `CSVRead` |
| JSON programs | Calli | `JSONCreate`, `JSONAdd`, `JSONRead` |
| Testing and errors | Stephen | `docs/test-record.md`, `docs/test-output/` |
