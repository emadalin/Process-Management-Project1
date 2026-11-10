// File API check — the "observed" evidence behind docs/file-system-layers.md.
//
// Runs six small experiments with the same Foundation calls our programs use,
// in a scratch folder of its own, so it never touches output/.
//
//   swift docs/file-api-check.swift        (from inside project4/)
import Foundation

// A fresh scratch folder in the system temp directory.
let folder = FileManager.default.temporaryDirectory.appendingPathComponent("file-api-check")
try? FileManager.default.removeItem(at: folder)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

let missing = folder.appendingPathComponent("missing.csv")
let csv = folder.appendingPathComponent("people.csv")
let json = folder.appendingPathComponent("people.json")

// The file's inode number: APFS's ID for the file itself, separate from its name.
func inode(_ url: URL) throws -> Int {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    let number = attributes[.systemFileNumber] as! NSNumber
    return number.intValue
}

// The whole file as text, with \n shown, so we can see exactly what is in it.
func contents(_ url: URL) throws -> String {
    return try String(contentsOf: url, encoding: .utf8).debugDescription
}

// 1. Opening a file that doesn't exist, for writing (what CSVAppend does).
do {
    _ = try FileHandle(forWritingTo: missing)
    print("1. opened a missing file?")
} catch let error as CocoaError {
    print("1. open missing file for writing -> CocoaError code \(error.code.rawValue), .fileNoSuchFile: \(error.code == .fileNoSuchFile)")
}

// 2. Reading a file that doesn't exist (what CSVRead, JSONAdd, JSONRead do).
do {
    _ = try Data(contentsOf: missing)
    print("2. read a missing file?")
} catch let error as CocoaError {
    print("2. read missing file -> CocoaError code \(error.code.rawValue), .fileReadNoSuchFile: \(error.code == .fileReadNoSuchFile)")
}

// 3. Open an existing file: we get a descriptor and a position, not the file.
FileManager.default.createFile(atPath: csv.path, contents: Data("a,b\n".utf8))
let inodeBefore = try inode(csv)
let handle = try FileHandle(forWritingTo: csv)
print("3. descriptor \(handle.fileDescriptor), position after opening \(try handle.offset())")
let end = try handle.seekToEnd()
print("3. seekToEnd() -> position \(end) (the file is 4 bytes)")
try handle.write(contentsOf: Data("c,d\n".utf8))
try handle.close()
print("3. after appending: \(try contents(csv)), same inode: \(try inode(csv) == inodeBefore)")

// 4. Same, but forget seekToEnd(): the write starts at byte 0.
let noSeek = try FileHandle(forWritingTo: csv)
try noSeek.write(contentsOf: Data("XX".utf8))
try noSeek.close()
print("4. writing without seekToEnd(): \(try contents(csv))")

// 5. Data.write with .atomic vs a plain write: does the file get replaced?
try Data("[1]".utf8).write(to: json)
let jsonBefore = try inode(json)
try Data("[1,2]".utf8).write(to: json, options: .atomic)
let jsonAfterAtomic = try inode(json)
print("5. .atomic write: inode \(jsonBefore) -> \(jsonAfterAtomic), new file: \(jsonAfterAtomic != jsonBefore)")
try Data("[1,2,3]".utf8).write(to: json)
print("5. plain write: new file: \(try inode(json) != jsonAfterAtomic)")

// 6. Decoding JSON that is missing its closing ].
do {
    _ = try JSONDecoder().decode([Int].self, from: Data("[1,2".utf8))
    print("6. decoded broken JSON?")
} catch let error as DecodingError {
    print("6. broken JSON -> DecodingError: \(error)")
}

try FileManager.default.removeItem(at: folder)
