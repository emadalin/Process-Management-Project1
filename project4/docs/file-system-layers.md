# Demo Section 2c: App, Runtime, OS and File System (4 min)

Owner: Member 1 (Sarah).

**One-sentence version:** our code decides what a record *means*; Foundation turns that into
bytes and file handles; macOS owns the file descriptor and checks permissions; and APFS decides
where the bytes live and keeps the file system consistent if something crashes.

Every claim below is marked **documented** (from Apple's documentation or the macOS man pages),
**observed** (we saw it ourselves, with the command shown) or **inferred** (our reasoning, not
proven). Observations are from Sarah's M2, macOS 15.8.1, Swift 6.2.1.

---

## 1. The layers

```
  ┌───────────────────────────────────────────────┐
  │  Our code                                     │  what the bytes MEAN
  │  Person, makeRecords, toCSVLine, printTable   │  (RecordKit + six programs)
  └───────────────────────┬───────────────────────┘
                          │  Swift calls
  ┌───────────────────────▼───────────────────────┐
  │  Swift / Foundation                           │  bytes, handles, errors
  │  FileHandle · FileManager · Data              │  (in our process)
  │  JSONEncoder / JSONDecoder · CocoaError       │
  └───────────────────────┬───────────────────────┘
                          │  system calls: open · read · write · close
  ┌───────────────────────▼───────────────────────┐
  │  macOS kernel                                 │  descriptors, permissions,
  │  file descriptors · file position · access    │  the file position
  └───────────────────────┬───────────────────────┘
                          │
  ┌───────────────────────▼───────────────────────┐
  │  APFS                                         │  where the bytes are stored,
  │  inodes · metadata · copy-on-write            │  crash protection
  └───────────────────────────────────────────────┘
```

**The thing worth saying out loud:** CSV and JSON travel through the *same* three lower layers.
The difference between them is entirely in our code and Foundation: CSV is text we can add to
the end of, while JSON is one array that has to be read, changed and written back whole.

## 2. Layer by layer

### Our code — what a record means

Only our code knows that a line has eight fields, that field 8 is a ZIP code, or that 150 lines
means 150 people. To every layer below, `people.csv` is just a sequence of bytes. That is why
counting, parsing and the "exactly 8 fields" check all live in `RecordKit`, not in the system.
**(inferred** from the layers below having no concept of records)

### Swift / Foundation — bytes, handles and errors

- **`FileHandle` is "an object-oriented wrapper for a file descriptor."** — **documented**
  ([FileHandle](https://developer.apple.com/documentation/foundation/filehandle))
- **A handle we open owns its descriptor** and "is responsible for closing it." —
  **documented** ([init(forWritingTo:)](https://developer.apple.com/documentation/foundation/filehandle/init(forwritingto:)))
- **`JSONEncoder` / `JSONDecoder` turn our `Codable` structs into JSON and back, in memory.**
  The file is only touched when the resulting `Data` is written or read. — **documented**
  ([JSONEncoder](https://developer.apple.com/documentation/foundation/jsonencoder),
  [JSONDecoder](https://developer.apple.com/documentation/foundation/jsondecoder),
  [Codable](https://developer.apple.com/documentation/swift/codable))
- **File problems come back as thrown `CocoaError`s, and bad JSON as `DecodingError`** — the two
  are different types, which is how a program tells "missing file" apart from "broken file". —
  **observed**, experiments 1, 2 and 6 below

### macOS — descriptors, the file position, permissions

- **`open` returns a file descriptor**; `read` and `write` move bytes through it; `close`
  "deletes a descriptor from the per-process object reference table". — **documented**
  (`man 2 open`, `man 2 read`, `man 2 write`, `man 2 close`)
- **Foundation reaches the kernel through these calls.** — **inferred**: Foundation says a
  `FileHandle` wraps a descriptor, and the man pages say descriptors come from `open`, but we
  could not watch the calls happen. Tracing them (`dtruss`, `fs_usage`) needs root, and
  `dtruss` also needs System Integrity Protection turned off.
- **The descriptor our check got was `3`.** — **observed**. Descriptors 0, 1 and 2 are
  standard input, output and error (`man 4 fd`), so 3 is the first free number — **inferred**.
- **The kernel, not our code, checks permissions** when the file is opened. Each file carries an
  owner and permission bits that `ls -l` shows. — **documented** (`man 2 open`, *ERRORS*:
  `EACCES`)

### APFS — where the bytes live

- **APFS is the default file system** for macOS High Sierra and later. — **documented**
  ([APFS Guide](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/APFS_Guide/Introduction/Introduction.html))
- **APFS "uses a novel copy-on-write metadata scheme to ensure that updates to the file system
  are crash protected."** — **documented**
  ([APFS Guide: Features](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/APFS_Guide/Features/Features.html))
- **Each file has an inode number**, an ID for the file itself, separate from its name. —
  **documented** (`man stat`: `st_ino`) and **observed** in experiments 3 and 5

## 3. Opening a file does not load it

Opening a file gives us **a handle: a descriptor plus a position in the file**, not the file's
contents. Nothing is read until we ask for bytes.

**Observed** (experiment 3): opening a 4-byte file for writing gave descriptor `3` at position
`0`. `seekToEnd()` moved the position to `4` without reading anything, and the next write landed
there.

Apple documents the same starting point: for `init(forWritingTo:)`, "the file pointer is set to
the beginning of the file." — **documented**

This is the whole reason `CSVAppend` calls `seekToEnd()`. **Observed** (experiment 4): writing
`XX` to a handle we hadn't moved changed `a,b\n` into `XXb\n`. Forgetting the seek doesn't
erase the file; it **silently overwrites the first records**, which is arguably worse because
the record count still looks right.

`JSONAdd` and `JSONRead` *do* read the whole file into memory with `Data(contentsOf:)`, on
purpose: a JSON array has to be decoded as one piece. That's fine at 150 records; it wouldn't
be for a file too big to fit in memory. — **inferred**

## 4. Three ways to write, and what each does to the file

| Program | How it writes | What happens to the file |
|---|---|---|
| `CSVCreate` | create the file, replacing any old one | old contents gone |
| `CSVAppend` | `FileHandle(forWritingTo:)` → `seekToEnd()` → write | **same file, longer**; first 100 records untouched |
| `JSONAdd` | `Data.write(to:options: .atomic)` | **a new file swapped in** under the same name |

**Observed** (experiments 3 and 5):

- **Appending keeps the inode.** It's the same file, with bytes added at the end.
- **An `.atomic` write changes the inode** (`60102118` → `60102119` in our run), but a plain
  write keeps it. So `.atomic` really does write a separate file and rename it over the old one.

Apple documents that `.atomic` writes "to an auxiliary file first and then replace[s] the
original file with the auxiliary file when the write completes" — **documented**
([atomic](https://developer.apple.com/documentation/foundation/nsdata/writingoptions/atomic)).
If the program crashes halfway, the old `people.json` is still there and complete. — **inferred**

## 5. Why APFS, and why we don't assume FAT

**Observed:** both volumes report APFS.

```
$ diskutil info / | grep "File System"
   File System Personality:   APFS

$ diskutil info "$(df output | tail -1 | cut -d' ' -f1)" | grep "File System"     # from project4/
   File System Personality:   APFS
```

**Check the right volume.** `/` is macOS's read-only system volume. Our repo lives on the
separate **Data** volume (`/System/Volumes/Data`), so the second command is the one that checks
the output folder itself. On a normal Mac both are APFS, but on a USB stick or SD card the
output folder could be on anything. — **observed** (`df output`)

**Why not assume FAT:** Apple lists MS-DOS (FAT) and ExFAT only as "Windows-compatible"
formats — **documented**
([File system formats in Disk Utility](https://support.apple.com/guide/disk-utility/file-system-formats-dsku19ed921c/mac)).
FAT has no per-file owner or permissions. When macOS mounts a FAT disk, `mount_msdos` *invents*
them: one owner, one group and one permission mask for every file on the disk — **documented**
(`man mount_msdos`: `-u`, `-g`, `-m`). FAT also has no copy-on-write crash protection. So the
permission and crash-safety claims in this doc are true **because** the output folder is on
APFS, and might not hold on another file system.

## 6. Error types: missing file vs broken file

| Situation | What Swift throws | Code |
|---|---|---|
| `CSVAppend` opens a missing file for writing | `CocoaError` `.fileNoSuchFile` | 4 |
| `CSVRead` / `JSONAdd` / `JSONRead` read a missing file | `CocoaError` `.fileReadNoSuchFile` | 260 |
| `JSONAdd` / `JSONRead` decode broken JSON | `DecodingError.dataCorrupted` | — |

All three are **observed** (experiments 1, 2 and 6). The two codes are **documented** in
Foundation's own header: 4 is "Attempt to do a file system operation on a non-existent file",
260 is "Read error (no such file)".

**For Stephen and Ella:** the task file names only `.fileReadNoSuchFile`, but `CSVAppend` gets
`.fileNoSuchFile`. A `catch` that checks only for 260 would miss the append case. Note also that
Apple's page for `init(forWritingTo:)` says it returns `nil` if the file is missing; that is the
Objective-C behaviour, and in Swift it **throws** instead (experiment 1).

## 7. The evidence

Run from inside `project4/`:

```sh
swift docs/file-api-check.swift
```

[`file-api-check.swift`](file-api-check.swift) uses the same Foundation calls as our programs, in
a scratch folder of its own, so it never touches `output/`. Output on Sarah's Mac, 10 November
(the inode numbers change every run):

```
1. open missing file for writing -> CocoaError code 4, .fileNoSuchFile: true
2. read missing file -> CocoaError code 260, .fileReadNoSuchFile: true
3. descriptor 3, position after opening 0
3. seekToEnd() -> position 4 (the file is 4 bytes)
3. after appending: "a,b\nc,d\n", same inode: true
4. writing without seekToEnd(): "XXb\nc,d\n"
5. .atomic write: inode 60102118 -> 60102119, new file: true
5. plain write: new file: false
6. broken JSON -> DecodingError: dataCorrupted(... "The given data was not valid JSON." ...)
```

### Still to observe once the programs work

These need Ella's and Calli's real programs, not stubs:

- [ ] `ls -l output/people.csv` after `CSVCreate` and again after `CSVAppend`: the size should
      grow, and the first 100 lines should be byte-for-byte the same
- [ ] `stat -f '%i %z' output/people.csv` before and after `CSVAppend`: same inode, bigger size
- [ ] `stat -f '%i %z' output/people.json` before and after `JSONAdd`: **new** inode, because of
      `.atomic`

## Sources

Every Apple URL below was fetched and confirmed to load on 2026-11-10.

### Behind the **documented** claims

| Claim | Source |
|---|---|
| `FileHandle` wraps a file descriptor and owns it | [FileHandle](https://developer.apple.com/documentation/foundation/filehandle) · [fileDescriptor](https://developer.apple.com/documentation/foundation/filehandle/filedescriptor) |
| Opening for writing starts the file pointer at the beginning | [init(forWritingTo:)](https://developer.apple.com/documentation/foundation/filehandle/init(forwritingto:)) |
| `seekToEnd()` moves to the end and returns the new position | [seekToEnd()](https://developer.apple.com/documentation/foundation/filehandle/seektoend()) |
| Closing a handle ends access to the file | [close()](https://developer.apple.com/documentation/foundation/filehandle/close()) |
| Creating a file, and checking or deleting one | [FileManager](https://developer.apple.com/documentation/foundation/filemanager) · [createFile(atPath:contents:attributes:)](https://developer.apple.com/documentation/foundation/filemanager/createfile(atpath:contents:attributes:)) |
| `.atomic` writes a separate file, then replaces the original | [Data.write(to:options:)](https://developer.apple.com/documentation/foundation/data/write(to:options:)) · [atomic](https://developer.apple.com/documentation/foundation/nsdata/writingoptions/atomic) |
| JSON encoding and decoding of `Codable` types | [JSONEncoder](https://developer.apple.com/documentation/foundation/jsonencoder) · [JSONDecoder](https://developer.apple.com/documentation/foundation/jsondecoder) · [Codable](https://developer.apple.com/documentation/swift/codable) |
| The two "no such file" errors, and the decoding error | [CocoaError](https://developer.apple.com/documentation/foundation/cocoaerror) · [fileNoSuchFile](https://developer.apple.com/documentation/foundation/cocoaerror/filenosuchfile) · [fileReadNoSuchFile](https://developer.apple.com/documentation/foundation/cocoaerror/filereadnosuchfile) · [DecodingError](https://developer.apple.com/documentation/swift/decodingerror) |
| APFS is the default; copy-on-write metadata gives crash protection | [APFS Guide: Introduction](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/APFS_Guide/Introduction/Introduction.html) · [Features](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/APFS_Guide/Features/Features.html) (archived guide, 2018) |
| FAT and ExFAT are the Windows-compatible formats | [File system formats available in Disk Utility](https://support.apple.com/guide/disk-utility/file-system-formats-dsku19ed921c/mac) |
| Descriptors, system calls, inodes, FAT's invented permissions | `man 2 open` · `man 2 read` · `man 2 write` · `man 2 close` · `man 4 fd` · `man stat` · `man mount_msdos` |
| Error codes 4 and 260 | `FoundationErrors.h` in the macOS SDK: `NSFileNoSuchFileError = 4`, `NSFileReadNoSuchFileError = 260` |

### Behind the **observed** claims

| Observation | Command |
|---|---|
| Both volumes are APFS | `diskutil info / \| grep "File System"` · `diskutil info "$(df output \| tail -1 \| cut -d' ' -f1)" \| grep "File System"` |
| The repo is on the Data volume, not `/` | `df output` |
| Error types, descriptor, file position, inode on append vs `.atomic` | `swift docs/file-api-check.swift` |
