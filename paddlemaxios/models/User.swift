import Foundation

class User: NSObject, NSCoding{
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

    required convenience init(coder aDecoder: NSCoder) {
        self.init(
                aDecoder.decodeInt64(forKey: "id"),
                aDecoder.decodeObject(forKey: "firstName") as! String,
                aDecoder.decodeObject(forKey: "lastName") as! String,
                aDecoder.decodeObject(forKey: "email") as! String,
                aDecoder.decodeObject(forKey: "password") as! String,
                aDecoder.decodeObject(forKey: "birthday") as! Date,
                aDecoder.decodeInteger(forKey: "weightLbs"),
                aDecoder.decodeObject(forKey: "location") as! String)
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(id, forKey: "id")
        aCoder.encode(firstName, forKey: "firstName")
        aCoder.encode(lastName, forKey: "lastName")
        aCoder.encode(email, forKey: "email")
        aCoder.encode(password, forKey: "password")
        aCoder.encode(birthday, forKey: "birthday")
        aCoder.encode(weightLbs, forKey: "weightLbs")
        aCoder.encode(location, forKey: "location")
    }
}
