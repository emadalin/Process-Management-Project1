// JSONCreate — program 4 of 6. Member 4 (Calli).
//
// Writes records 1–100 to output/people.json as ONE JSON array, replacing any
// old file. Run order: JSONCreate → JSONAdd → JSONRead.
import Foundation
import RecordKit

// Make records 1–100 (the Maple St batch) with RecordKit's generator.
let people = makeRecords(from: 1, count: 100)

// Turn the whole array into JSON text in memory. prettyPrinted puts each field
// on its own line so the file is readable when we open it.
let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted
let data: Data
do {
    data = try encoder.encode(people)
} catch {
    print("JSONCreate: could not encode the records as JSON (\(error))")
    exit(1)
}

// Create an empty file, replacing any old one. createFile returns false if
// macOS refused (e.g. the output folder is missing).
guard FileManager.default.createFile(atPath: jsonPath, contents: nil) else {
    print("JSONCreate: could not create \(jsonPath)")
    exit(1)
}

do {
    // Open the file for writing. This gives us a handle (a file descriptor),
    // not the file's contents.
    let handle = try FileHandle(forWritingTo: jsonURL)
    // Close the file when we leave this block, even if the write throws.
    defer { try? handle.close() }
    // Write the whole array in one go.
    try handle.write(contentsOf: data)
} catch {
    print("JSONCreate: could not write \(jsonPath) (\(error.localizedDescription))")
    exit(1)
}

print("Wrote \(people.count) records to \(jsonPath)")
