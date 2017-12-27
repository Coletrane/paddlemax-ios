import Foundation

class User {
    let id: Int64?
    let firstName: String
    let lastName: String
    let email: String
    let password: String
    let birthday: Date?
    let weightLbs: Int?
    let location: String?

    init(_ id: Int64?,
         _ firstName: String,
         _ lastName: String,
         _ email: String,
         _ password: String,
         _ birthday: Date?,
         _ weightLbs: Int?,
         _ location: String?) {

        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.password = password
        self.birthday = birthday
        self.weightLbs = weightLbs
        self.location = location
    }
}
