// CSVRead — program 3 of the CSV workflow (Member 3, Ella).
//
// Reads every line of output/people.csv, turns each line back into a Person,
// prints them as a table, then prints how many records it read.
// Run CSVCreate and CSVAppend first, from inside project4/.
import Foundation
import RecordKit

// Stop with a clear message if there is no file to read (e.g. right after reset.sh).
guard FileManager.default.fileExists(atPath: csvPath) else {
    print("CSVRead: could not open \(csvPath) for reading (file does not exist)")
    exit(1)
}

// The file's bytes, read in one go. Filled in by the block below.
let data: Data

do {
    // Open the file for reading only, so this program can never change it.
    let handle = try FileHandle(forReadingFrom: csvURL)

    // Close the file when this block ends, even if the read fails.
    defer { try? handle.close() }

    // Read from the current position (the start) to the end of the file.
    // readToEnd() returns nil for an empty file, so use empty Data then.
    data = try handle.readToEnd() ?? Data()
} catch {
    print("CSVRead: could not read \(csvPath) (\(error.localizedDescription))")
    exit(1)
}

// Turn the bytes back into text, then cut it into lines at every "\n".
let text = String(decoding: data, as: UTF8.self)
var lines = text.components(separatedBy: "\n")

// The last line ends in "\n" too, which leaves one empty piece after it. Drop it.
if lines.last == "" {
    lines.removeLast()
}

// Turn each line into a Person and keep them in order.
var people: [Person] = []
for (index, line) in lines.enumerated() {
    do {
        // Throws if the line doesn't have exactly 8 fields.
        people.append(try Person.fromCSVLine(line))
    } catch {
        // Lines are counted from 1, like a text editor, so the line is easy to find.
        print("CSVRead: could not read line \(index + 1) of \(csvPath) (\(error))")
        exit(1)
    }
}

printTable(people)
print("Read \(people.count) records from \(csvPath)")
