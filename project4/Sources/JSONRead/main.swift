// JSONRead — program 6 of 6. Member 4 (Calli).
//
// Reads output/people.json, prints every record in the same table as CSVRead,
// and prints how many records (JSON objects, not lines) it found.
import Foundation
import RecordKit

// Read the whole file. Data(contentsOf:) opens, reads and closes it for us.
let data: Data
do {
    data = try Data(contentsOf: jsonURL)
} catch CocoaError.fileReadNoSuchFile {
    print("JSONRead: could not open \(jsonPath) for reading (file does not exist)")
    exit(1)
} catch {
    print("JSONRead: could not open \(jsonPath) for reading (\(error.localizedDescription))")
    exit(1)
}

// Decode the bytes into [Person]. A file that exists but isn't a valid array
// of people is a parse error, reported separately from a missing file.
let people: [Person]
do {
    people = try JSONDecoder().decode([Person].self, from: data)
} catch {
    print("JSONRead: \(jsonPath) is not valid JSON (\(error))")
    exit(1)
}

// Same table and column labels as CSVRead, from RecordKit.
printTable(people)

// Count the objects in the array. Counting lines would be wrong: pretty-printed
// JSON spreads each record over about ten lines.
print("Read \(people.count) records from \(jsonPath)")
