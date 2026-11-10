// CSVCreate — program 1 of the CSV workflow (Member 3, Ella).
//
// Creates output/people.csv, replacing any old copy, and writes records 1–100,
// one per line, with no header row. Run it first, from inside project4/.
import Foundation
import RecordKit

// The 100 fictional people for the first batch: "1 Maple St" … "100 Maple St".
let people = makeRecords(from: 1, count: 100)

// Create an empty file. If one is already there, it is replaced, so every run
// starts from nothing. Returns false if the file can't be made (e.g. no output/ folder).
guard FileManager.default.createFile(atPath: csvPath, contents: nil) else {
    print("CSVCreate: could not create \(csvPath) (is the output folder there? run from inside project4/)")
    exit(1)
}

do {
    // Open the new, empty file for writing. This gives us a handle (a file
    // descriptor from macOS), not the whole file in memory.
    let handle = try FileHandle(forWritingTo: csvURL)

    // Close the file when this block ends, even if a write below fails.
    defer { try? handle.close() }

    for person in people {
        // One record per line. Every line ends in "\n", so the next line
        // (including record 101 from CSVAppend) always starts on a new line.
        let line = person.toCSVLine() + "\n"

        // The file stores bytes, so turn the text into UTF-8 bytes and write them.
        try handle.write(contentsOf: Data(line.utf8))
    }
} catch {
    // Opening or writing failed: say which program, which operation and which file.
    print("CSVCreate: could not write to \(csvPath) (\(error.localizedDescription))")
    exit(1)
}

print("Wrote \(people.count) records to \(csvPath)")
