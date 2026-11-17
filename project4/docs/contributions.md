# Team Contribution Statement — Project 4

Canvas deliverable: *team contribution statement*. Each person writes their own section, in their
own words, and lists what they built. Where AI helped, point to your file in [`ai-use/`](ai-use/).

## Member 1: Sarah Rae — setup, file-system layers, README

I set up the Swift package, the file paths in RecordKit, starter files for all six programs, and
the reset script. I researched the file system layers, including the roles of our code, Swift,
macOS, and APFS, with sources and documented vs. observed labels, and collected and checked the
team's sources list. I recorded evidence on my own Mac that the CSV append kept the same file and
the original 100 records, and that the JSON add wrote a new file without changing the originals. I
wrote the README and the study guide so everyone could explain all six programs. I used Claude
Code to draft much of this, and checked its work by running the programs and comparing it to the
Apple documentation; details are in [`ai-use/sarah.md`](ai-use/sarah.md).

## Member 2: Georgia Hipp — shared records and table (`RecordKit`)

I built `RecordKit`, the shared code all six programs use. It has the `Person` struct with eight
`String` fields, marked `Codable` so the JSON programs can encode and decode it. It also has
`makeRecords`, which makes the same fictional people every run, with records 1–100 on Maple St,
101–150 on Oak Ave, and a ZIP starting with 0 in each batch. The CSV line conversion throws an
error if a line doesn't have exactly eight fields, and `printTable` gives both read programs the
same labelled columns. I tested it with three records before handing it to Ella and Calli. On 16
November I ran the full workflow on my own Mac and added my results to the test record. I used
Claude Code to write much of this, and checked it by running the programs and comparing their
output to our format table; details are in [`ai-use/georgia.md`](ai-use/georgia.md).

## Member 3: Ella Madalinski — CSV programs

I built the three CSV programs. `CSVCreate` creates `people.csv`, replacing any old copy, and
writes records 1–100, one per line with no header. `CSVAppend` opens the existing file without
erasing it, moves to the end with `seekToEnd()`, and writes records 101–150; if the file is
missing it stops with an error instead of making a new one. `CSVRead` reads the file, turns each
line into a `Person`, prints the table and the count, and names the line number if a line doesn't
have eight fields. Every program closes its file with `defer`, even when a write fails. I checked
that the first 6,512 bytes of the file are the same before and after the append (`shasum`), and on
17 November I ran the full workflow on my own Mac. I used Claude Code to write and test the
programs and to draft my write-ups; details are in [`ai-use/ella.md`](ai-use/ella.md).

## Member 4: Calli Nash — JSON programs

I built the three JSON programs. `JSONCreate` writes records 1–100 as one pretty-printed JSON
array. `JSONAdd` reads and decodes that array, adds records 101–150 after the originals, and writes
the whole array back with an atomic write; if the file is missing or the JSON is broken, it reports
which one and stops without touching the file. `JSONRead` decodes the array and prints the same
table as the CSV side, counting records rather than lines. I matched my error messages to the
wording Stephen drafted, retested the programs against Georgia's `RecordKit`, and ran the full
workflow on my own Mac. I used Claude Code to write and test the programs and to draft my
write-ups; details are in [`ai-use/calli.md`](ai-use/calli.md).

## Member 5: Stephen Heath — testing, error handling, test record

_To be written by Stephen._
