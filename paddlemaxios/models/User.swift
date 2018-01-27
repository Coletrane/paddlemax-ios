import Foundation

class User: NSObject{
    let id: Int64?
    var firstName: String
    var lastName: String
    var email: String
    var password: String
    var birthday: Date?
    var weightLbs: Int?
    var location: String?

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
