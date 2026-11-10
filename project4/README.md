# People Files: CSV and JSON — Process Management Project 4

Six small Swift programs that create, append to, and read a file of fictional people: three for a
CSV file and three for a JSON file. Built to show what our code, Swift/Foundation, macOS and the
APFS file system each do when a program writes and reads a file.

> **Due: Tuesday 17 November.** Team roles and the full checklist are in
> [`project4-team-tasks.md`](project4-team-tasks.md).
>
> **Status:** the package skeleton builds and all six programs run, but each one is still a stub
> that prints its name. `RecordKit` (Georgia), the CSV programs (Ella) and the JSON programs
> (Calli) replace them.

---

## Requirements

| | Needed | Tested on (Sarah's Mac) |
|---|---|---|
| macOS | 13 or later (`platforms: [.macOS(.v13)]`) | macOS 15.8.1, Apple silicon (`arm64`) |
| Swift | 6.0 or later (`swift-tools-version: 6.0`) | Swift 6.2.1 |
| Xcode | 16 or later, or just its Command Line Tools | Xcode 26.1.1 |
| File system | APFS | APFS |

**Dependencies:** none beyond Foundation, which ships with macOS. No packages to download.

Record your own versions for the test record:

```sh
sw_vers
uname -m
swift --version
diskutil info / | grep "File System"
```

`/` is the read-only system volume. The repo actually lives on the **Data** volume, so to check
the output folder's own volume, run this from inside `project4/`:

```sh
diskutil info "$(df output | tail -1 | cut -d' ' -f1)" | grep "File System"
```

On Sarah's Mac both report `APFS`.

## Setup

```sh
git pull
cd project4
swift build
```

`swift build` should end with `Build complete!`. Every command below is run from inside
`project4/`, because the file paths are relative to it.

## Run order

```sh
cd project4
./reset.sh
swift run CSVCreate    # → 100 records
swift run CSVAppend    # → 150 records
swift run CSVRead      # table + "Read 150 records from output/people.csv"
swift run JSONCreate   # → 100 records
swift run JSONAdd      # → 150 records
swift run JSONRead     # table + "Read 150 records from output/people.json"
```

The two formats are independent: the CSV programs never touch the JSON file, and the JSON
programs never touch the CSV file.

| Program | What it does |
|---|---|
| `CSVCreate` | Creates `people.csv` (replacing any old one) and writes records 1–100, one per line |
| `CSVAppend` | Opens the **existing** file, moves to the end, writes records 101–150. Fails if the file is missing |
| `CSVRead` | Reads every line, turns each into a record, prints the table and the count |
| `JSONCreate` | Writes records 1–100 as one JSON array |
| `JSONAdd` | Reads and decodes the array, adds records 101–150, writes the whole array back |
| `JSONRead` | Decodes the array, prints the table and the count of records |

## Output files

| File | Written by | After a full run |
|---|---|---|
| `output/people.csv` | `CSVCreate`, `CSVAppend` | 150 lines, no header |
| `output/people.json` | `JSONCreate`, `JSONAdd` | one array of 150 objects |

Both paths are set once, in `Sources/RecordKit/Paths.swift`, so all three programs of a format
always use the same file.

## Reset

```sh
./reset.sh
```

Deletes `output/people.csv` and `output/people.json` and nothing else, so the workflow can start
fresh. It works from any folder. Run it before the missing-file tests too: after a reset, the
read and add programs should report a clear error rather than crash.

## Record format

Each record has eight fields, in this order for the CSV columns and both tables:

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

One CSV line looks like this, with no header row:

```
Avery,Nguyen,1999-04-07,205-555-0101,1 Maple St,Boston,MA,02134
```

- **All data is fictional and generated.** No real people or addresses.
- **Phone and ZIP are text, not numbers**, so leading zeros survive (`02134` as a number would
  become `2134`).
- **No commas, quotes or line breaks** in any value, so the CSV needs no quoting.
- **Batches are easy to tell apart:** record *N* has street number *N*. The first batch is
  `1–100 Maple St`, the added batch `101–150 Oak Ave`, so the boundary shows at row 100 / 101.
- **The same values every run** (no random numbers), so results can be checked exactly.
- **Each batch has at least one ZIP starting with 0**, as the leading-zero check.

## Project layout

```
project4/
  Package.swift                  the package: RecordKit + six programs
  Sources/
    RecordKit/                   shared code                          (Georgia)
      Paths.swift                the two output file paths            (Sarah)
    CSVCreate/ CSVAppend/ CSVRead/      main.swift each               (Ella)
    JSONCreate/ JSONAdd/ JSONRead/      main.swift each               (Calli)
  output/                        people.csv and people.json are written here
  reset.sh                       deletes the two output files only
  project4-team-tasks.md         roles, checklist, demo timing, practice questions
  README.md                      this file
```
