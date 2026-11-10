# Documentation Sources Used

Owner: Member 1 (Sarah). Canvas deliverable: *resources list, including adapted examples and AI
use*.

**Seeded from what the layers doc already cites.** Everyone: **add anything you used that isn't
here** (an Apple page, a tutorial, an example you adapted), and put your name in *Used by*. If AI
helped, say what you asked and how you checked the answer, in the AI table at the bottom.

Every Apple URL below was fetched and confirmed to load on 2026-11-10.

## Files — Foundation

| Source | Used for | Used by |
|---|---|---|
| [FileHandle](https://developer.apple.com/documentation/foundation/filehandle) | a handle is a wrapper for a file descriptor | Sarah |
| [init(forWritingTo:)](https://developer.apple.com/documentation/foundation/filehandle/init(forwritingto:)) | opening the existing CSV for appending; the file pointer starts at the beginning | Sarah, Ella (`CSVCreate`, `CSVAppend`) |
| [init(forReadingFrom:)](https://developer.apple.com/documentation/foundation/filehandle/init(forreadingfrom:)) | opening a file for reading | Ella (`CSVRead`) |
| [seekToEnd()](https://developer.apple.com/documentation/foundation/filehandle/seektoend()) | moving to the end before appending | Sarah, Ella (`CSVAppend`) |
| [write(contentsOf:)](https://developer.apple.com/documentation/foundation/filehandle/write(contentsof:)) | writing bytes through a handle | Sarah, Ella (`CSVCreate`, `CSVAppend`) |
| [readToEnd()](https://developer.apple.com/documentation/foundation/filehandle/readtoend()) | reading a whole file through a handle | Ella (`CSVRead`) |
| [close()](https://developer.apple.com/documentation/foundation/filehandle/close()) | closing every handle we open | Sarah, Ella (all three CSV programs) |
| [FileManager](https://developer.apple.com/documentation/foundation/filemanager) · [createFile(atPath:contents:attributes:)](https://developer.apple.com/documentation/foundation/filemanager/createfile(atpath:contents:attributes:)) | creating the file, checking whether it exists | Ella (`createFile` in `CSVCreate`; `fileExists(atPath:)` in `CSVAppend` and `CSVRead`) |
| [Data(contentsOf:options:)](https://developer.apple.com/documentation/foundation/data/init(contentsof:options:)) | reading the whole JSON file into memory | Sarah |
| [Data.write(to:options:)](https://developer.apple.com/documentation/foundation/data/write(to:options:)) · [atomic](https://developer.apple.com/documentation/foundation/nsdata/writingoptions/atomic) | writing the JSON with a temp file swapped in | Sarah |

## JSON

| Source | Used for | Used by |
|---|---|---|
| [JSONEncoder](https://developer.apple.com/documentation/foundation/jsonencoder) · [prettyPrinted](https://developer.apple.com/documentation/foundation/jsonencoder/outputformatting-swift.struct/prettyprinted) | `[Person]` → JSON, readable layout | |
| [JSONDecoder](https://developer.apple.com/documentation/foundation/jsondecoder) | JSON → `[Person]` | |
| [Codable](https://developer.apple.com/documentation/swift/codable) | letting `Person` convert to and from JSON | |

## Errors

| Source | Used for | Used by |
|---|---|---|
| [CocoaError](https://developer.apple.com/documentation/foundation/cocoaerror) · [fileNoSuchFile](https://developer.apple.com/documentation/foundation/cocoaerror/filenosuchfile) · [fileReadNoSuchFile](https://developer.apple.com/documentation/foundation/cocoaerror/filereadnosuchfile) | telling a missing file apart from other errors (code 4 when opening to write, 260 when reading) | Sarah |
| [DecodingError](https://developer.apple.com/documentation/swift/decodingerror) | telling broken JSON apart from a missing file | Sarah |

## OS and file system

| Source | Used for | Used by |
|---|---|---|
| [APFS Guide: Introduction](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/APFS_Guide/Introduction/Introduction.html) · [Features](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/APFS_Guide/Features/Features.html) | APFS is the default; copy-on-write metadata (archived guide) | Sarah |
| [File system formats available in Disk Utility](https://support.apple.com/guide/disk-utility/file-system-formats-dsku19ed921c/mac) | FAT and ExFAT are the Windows-compatible formats | Sarah |
| `man 2 open`, `read`, `write`, `close` | file descriptors and the system calls under Foundation | Sarah |
| `man 4 fd` · `man stat` · `man mount_msdos` · `man diskutil` | standard descriptors 0–2; inode numbers; how macOS fakes permissions on FAT; checking the file system | Sarah |

## Adapted examples

| What we adapted | From | What we changed |
|---|---|---|
| | | |

## AI use

| Who | What AI helped with | How we checked it |
|---|---|---|
| Sarah | Claude Code set up the package skeleton and `reset.sh`, drafted the README and this list, and wrote the layers doc and `docs/file-api-check.swift` | Ran `swift build` and all six stubs; tested `reset.sh` with a third file in `output/`; ran `file-api-check.swift` and copied its real output into the doc; fetched every Apple link and checked each quote against the page or man page |
| Ella | Claude Code wrote `CSVCreate`, `CSVAppend` and `CSVRead` with their comments | Claude Code ran these checks on Ella's Mac: a fresh run gives 100 lines, then 150; row 100 is `100 Maple St` and row 101 is `101 Oak Ave`; ZIP `02134` keeps its 0; the first 6,512 bytes match a fresh create (`shasum`); missing-file runs of `CSVAppend` and `CSVRead` print a clear error and exit 1; a 7-field line makes `CSVRead` name line 57. *Ella: add what you checked yourself, e.g. reading each line against the Apple docs above* |
