// One fictional person: one line in the CSV file, or one object in the JSON
// array. Every program uses this same struct, so both formats hold the same
// eight fields in the same order.
//
// Every field is a String, even phone and ZIP. As a number, ZIP 02134 would
// lose its leading zero and become 2134.
import Foundation

/// Codable lets JSONEncoder / JSONDecoder turn a Person into JSON and back
/// without us converting each field by hand. The property names become the
/// JSON keys, so they match the team's format table exactly.
public struct Person: Codable {
    public let firstName: String
    public let lastName: String
    public let dateOfBirth: String   // YYYY-MM-DD
    public let phone: String         // ###-###-####
    public let street: String
    public let city: String
    public let state: String         // 2 letters
    public let zip: String           // 5 digits, kept as text

    /// Swift does not make a struct's automatic initializer public, so the
    /// programs outside RecordKit need this one to create a Person.
    public init(firstName: String, lastName: String, dateOfBirth: String,
                phone: String, street: String, city: String,
                state: String, zip: String) {
        self.firstName = firstName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.phone = phone
        self.street = street
        self.city = city
        self.state = state
        self.zip = zip
    }

    // MARK: - CSV

    /// The eight fields in column order, joined by commas.
    ///
    /// No newline on the end: the CSV programs add "\n" when they write the
    /// line. No quoting is needed because the generated values never contain
    /// commas, quotes or line breaks.
    public func toCSVLine() -> String {
        let fields = [firstName, lastName, dateOfBirth, phone, street, city, state, zip]
        return fields.joined(separator: ",")
    }

    /// Turns one CSV line back into a Person.
    ///
    /// Throws if the line does not have exactly eight fields, so a damaged
    /// line is reported instead of being read into the wrong columns.
    public static func fromCSVLine(_ line: String) throws -> Person {
        let fields = line.components(separatedBy: ",")

        if fields.count != 8 {
            throw CSVLineError(fieldCount: fields.count)
        }

        return Person(firstName: fields[0],
                      lastName: fields[1],
                      dateOfBirth: fields[2],
                      phone: fields[3],
                      street: fields[4],
                      city: fields[5],
                      state: fields[6],
                      zip: fields[7])
    }
}

/// The error fromCSVLine throws when a line has the wrong number of fields.
/// CSVRead knows the line number, so it adds that to the message it prints.
public struct CSVLineError: Error, CustomStringConvertible {
    public let fieldCount: Int

    public var description: String {
        "expected 8 fields, found \(fieldCount)"
    }
}
