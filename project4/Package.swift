// swift-tools-version: 6.0
//
// Project 4 — file management: create, append and read CSV and JSON files.
//
// One shared library (RecordKit) and six small programs. Each program is its
// own executable target, so each one runs on its own:
//
//   swift run CSVCreate     (run from inside project4/, see README run order)
import PackageDescription

// The six programs, in run order. Each one lives in Sources/<name>/main.swift.
let programs = ["CSVCreate", "CSVAppend", "CSVRead", "JSONCreate", "JSONAdd", "JSONRead"]

let package = Package(
    name: "PeopleFiles",
    platforms: [.macOS(.v13)],
    targets: [
        // Shared code: the Person struct, the record generator, the table
        // printer and the file paths. Every program depends on it.
        .target(name: "RecordKit")
    ] + programs.map { name in
        .executableTarget(name: name, dependencies: ["RecordKit"])
    }
)
