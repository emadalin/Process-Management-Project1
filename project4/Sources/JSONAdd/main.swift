// JSONAdd — program 5 of 6. Member 4 (Calli).
//
// Adds records 101–150 to output/people.json. We can't just append bytes:
// the file is one array, and anything written after its closing ] is invalid
// JSON. So we read the whole array, add to it, and write the whole array back.
import Foundation
import RecordKit

// Step 1: read the file. Data(contentsOf:) opens, reads and closes it for us.
// If this fails it is a FILE error: the file is missing or unreadable.
let data: Data
do {
    data = try Data(contentsOf: jsonURL)
} catch CocoaError.fileReadNoSuchFile {
    print("JSONAdd: could not open \(jsonPath) for reading (file does not exist; run JSONCreate first)")
    exit(1)
} catch {
    print("JSONAdd: could not open \(jsonPath) for reading (\(error.localizedDescription))")
    exit(1)
}

// Step 2: decode the bytes into [Person]. If this fails it is a PARSE error:
// the file exists but is not a valid array of people. We stop here, before
// any write, so a broken file is left exactly as it was.
var people: [Person]
do {
    people = try JSONDecoder().decode([Person].self, from: data)
} catch {
    print("JSONAdd: could not parse \(jsonPath) (\(error) — file left unchanged)")
    exit(1)
}
let before = people.count

// Step 3: add records 101–150 (the Oak Ave batch) AFTER the originals.
people.append(contentsOf: makeRecords(from: 101, count: 50))

// Step 4: encode the whole array and write it with .atomic. macOS writes a
// temporary file first, then swaps it in, so a crash can't leave half a file.
let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted
do {
    let newData = try encoder.encode(people)
    try newData.write(to: jsonURL, options: .atomic)
} catch {
    print("JSONAdd: could not write to \(jsonPath) (\(error.localizedDescription))")
    exit(1)
}

print("Added \(people.count - before) records to \(jsonPath): \(before) → \(people.count)")
