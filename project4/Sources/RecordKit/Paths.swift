// The two output files. Every program reads these names from here, so all
// three programs of a format always point at the same file.
//
// The paths are relative, so run the programs from inside project4/
// (that is what the README run order does).
import Foundation

/// The CSV file used by CSVCreate, CSVAppend and CSVRead.
public let csvPath = "output/people.csv"

/// The JSON file used by JSONCreate, JSONAdd and JSONRead.
public let jsonPath = "output/people.json"

/// The same two files as URLs, which is what FileHandle and Data(contentsOf:) take.
public let csvURL = URL(fileURLWithPath: csvPath)
public let jsonURL = URL(fileURLWithPath: jsonPath)
