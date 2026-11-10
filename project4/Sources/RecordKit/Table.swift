// Prints people as a table with lined-up columns. CSVRead and JSONRead both
// call this, so the two formats show the same labels in the same order.
import Foundation

/// The column labels, in the team's agreed order. "#" is the row number.
let columnLabels = ["#", "First Name", "Last Name", "Date of Birth", "Phone",
                    "Street Address", "City", "State", "ZIP"]

/// Prints a header, a dividing line, and one row per person.
public func printTable(_ people: [Person]) {
    // 1. Turn every person into a row of text, starting with its row number.
    var rows: [[String]] = []
    for (position, person) in people.enumerated() {
        let rowNumber = String(position + 1)
        rows.append([rowNumber, person.firstName, person.lastName, person.dateOfBirth,
                     person.phone, person.street, person.city, person.state, person.zip])
    }

    // 2. Each column is as wide as its longest value, or its label if that is longer.
    var widths: [Int] = []
    for column in 0..<columnLabels.count {
        var width = columnLabels[column].count
        for row in rows {
            width = max(width, row[column].count)
        }
        widths.append(width)
    }

    // 3. Print the header, the line under it, then every row.
    print(formatRow(columnLabels, widths: widths))

    var dividers: [String] = []
    for width in widths {
        dividers.append(String(repeating: "-", count: width))
    }
    print(formatRow(dividers, widths: widths))

    for row in rows {
        print(formatRow(row, widths: widths))
    }
}

/// Pads each value with spaces to its column's width and puts two spaces
/// between columns, so every column starts in the same place.
func formatRow(_ values: [String], widths: [Int]) -> String {
    var paddedValues: [String] = []
    for column in 0..<values.count {
        let padded = values[column].padding(toLength: widths[column], withPad: " ", startingAt: 0)
        paddedValues.append(padded)
    }
    return paddedValues.joined(separator: "  ")
}
