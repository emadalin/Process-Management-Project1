// CSVAppend — program 2 of the CSV workflow (Member 3, Ella).
//
// Opens the existing output/people.csv and adds records 101–150 after the
// 100 already there. Run CSVCreate first, from inside project4/.
import Foundation
import RecordKit

// The 50 new fictional people: "101 Oak Ave" … "150 Oak Ave".
let people = makeRecords(from: 101, count: 50)

// Only add to a file that already exists. Creating a new one here would hide
// the mistake and leave a file with just 50 records, so stop with an error instead.
guard FileManager.default.fileExists(atPath: csvPath) else {
    print("CSVAppend: could not open \(csvPath) for appending (file does not exist; run CSVCreate first)")
    exit(1)
}

do {
    // Open the existing file for writing. This does NOT erase it: the 100
    // records stay, and the handle starts at byte 0 (the start of the file).
    let handle = try FileHandle(forWritingTo: csvURL)

    // Close the file when this block ends, even if a write below fails.
    defer { try? handle.close() }

    // Move to the end of the file, so the writes below go after the last
    // record instead of writing over record 1.
    try handle.seekToEnd()

    for person in people {
        // One record per line, ending in "\n" like the lines CSVCreate wrote.
        let line = person.toCSVLine() + "\n"

        // The file stores bytes, so turn the text into UTF-8 bytes and write them.
        try handle.write(contentsOf: Data(line.utf8))
    }
} catch {
    // Opening, moving to the end or writing failed: name the program, operation and file.
    print("CSVAppend: could not append to \(csvPath) (\(error.localizedDescription))")
    exit(1)
}

print("Appended \(people.count) records to \(csvPath)")
