// Makes the fictional people that the create and add programs write.
//
// No random numbers: every value is worked out from the record number, so
// every run produces exactly the same records and we can check them.
//
//   makeRecords(from: 1, count: 100)    records 1–100,   "1 Maple St" … "100 Maple St"
//   makeRecords(from: 101, count: 50)   records 101–150, "101 Oak Ave" … "150 Oak Ave"
import Foundation

/// Ten first names and ten last names. Record N takes a first name and a
/// last name by position, so records 1–100 are all different people.
let firstNames = ["Avery", "Blake", "Casey", "Drew", "Emerson",
                  "Finley", "Gray", "Harper", "Jordan", "Kai"]
let lastNames = ["Nguyen", "Patel", "Garcia", "Kim", "Okafor",
                 "Rossi", "Silva", "Novak", "Haddad", "Larsen"]

/// Ten fictional addresses' city, state and ZIP. Boston is first on purpose:
/// record 1 and record 101 both land on it, so each batch has a ZIP that
/// starts with 0 (02134), which checks that leading zeros survive.
let places = [
    (city: "Boston", state: "MA", zip: "02134"),
    (city: "Birmingham", state: "AL", zip: "35203"),
    (city: "Austin", state: "TX", zip: "78701"),
    (city: "Denver", state: "CO", zip: "80202"),
    (city: "Portland", state: "OR", zip: "97201"),
    (city: "Atlanta", state: "GA", zip: "30303"),
    (city: "Chicago", state: "IL", zip: "60601"),
    (city: "Newark", state: "NJ", zip: "07102"),
    (city: "Seattle", state: "WA", zip: "98101"),
    (city: "Miami", state: "FL", zip: "33130"),
]

/// Makes `count` people, numbered from `start`.
///
/// Records up to 100 live on Maple St and later ones on Oak Ave, and the
/// street number is the record number, so you can tell which batch any row
/// came from (row 100 is "100 Maple St", row 101 is "101 Oak Ave").
public func makeRecords(from start: Int, count: Int) -> [Person] {
    var people: [Person] = []

    for number in start..<(start + count) {
        // Position in the lists, counting from 0 for record 1.
        let index = number - 1

        // First name cycles every record; last name changes every ten.
        let firstName = firstNames[index % 10]
        let lastName = lastNames[(index / 10) % 10]
        let place = places[index % 10]

        // A made-up date between 1970 and 1999, always a valid day.
        let year = 1970 + (number % 30)
        let month = 1 + (number % 12)
        let day = 1 + (number % 28)
        let dateOfBirth = String(format: "%04d-%02d-%02d", year, month, day)

        // 555 numbers are reserved for fiction; the last four digits are the record number.
        let phone = String(format: "205-555-%04d", number)

        let streetName = number <= 100 ? "Maple St" : "Oak Ave"
        let street = "\(number) \(streetName)"

        let person = Person(firstName: firstName,
                            lastName: lastName,
                            dateOfBirth: dateOfBirth,
                            phone: phone,
                            street: street,
                            city: place.city,
                            state: place.state,
                            zip: place.zip)
        people.append(person)
    }

    return people
}
