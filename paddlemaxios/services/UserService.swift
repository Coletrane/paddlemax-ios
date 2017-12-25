import Foundation

struct User {
    let id: Int64?
    let firstName: String
    let lastName: String
    let email: String
    let password: String
    let birthday: Date?
    let weightLbs: Int?
    let location: String?

    // TODO: might need inheritance?
//    init(id uId: Int64?,
//         firstName fname: String!,
//         lastName lname: String!,
//         email eml: String!,
//         password pass: String!,
//         birthday bday: Date?,
//         weightLbs weight: String?,
//         location loc: String?) {
//
//        id = uId
//        firstName = fname
//        lastName = lname
//        email = eml
//        password = pass
//        birthday = bday
//
//    }
}

class UserService {

    func getuser() -> User? {

        let authStr = String(
                format: "%@:%@",
                self.user().email,
                self.user().password)
        let authData = authStr.data(using: String.Encoding.utf8)!
        let authBase64 = authData.base64EncodedString()

        var req = URLRequest(url: URL(string: "\(API_ROOT)/user/me")!)
        req.httpMethod = "GET"
        req.setValue("Basic \(authBase64)", forHTTPHeaderField: "Authorization")

        var user: User?

        URLSession.shared.dataTask(with: req) {
            (data, res, err) in

            if (err != nil) {
                printLog(self,
                        funcName: #function,
                        logString: err.debugDescription)
            }

            if (data != nil) {
                do {
                    user = try JSONSerialization.jsonObject(
                            with: data!) as? User
                } catch {
                    printLog(self,
                            funcName: #function,
                            logString: "Error deserializing user JSON. Data: \(data)")
                }
            }
        }

        return user
    }

    func register(user: User) {

        var req = URLRequest(url: URL(string: "\(API_ROOT)/user/register")!)
        req.httpMethod = "POST"
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: user)

            URLSession.shared.dataTask(with: req) {
                (data, res, err) in

                if (err != nil) {
                    printLog(self,
                            funcName: #function,
                            logString: err.debugDescription)
                }

                if ((res as! HTTPURLResponse).statusCode == 201) {
                    printLog(self,
                            funcName: #function,
                            logString: "User registration was successful with user: \(user)")
                    self.save(user)
                }
            }
        } catch {
            printLog(self,
                    funcName: #function,
                    logString: "Error deserializing \(user) to json")
        }
    }

    func save(_: User) {
        let encoded: Data = NSKeyedArchiver.archivedData(withRootObject: user)
        UserDefaults.standard.set(encoded, forKey: USER)
        UserDefaults.standard.synchronize()
    }

    func user() -> User {
        let decoded = UserDefaults.standard.object(forKey: USER) as! Data
        return NSKeyedUnarchiver.unarchiveObject(with: decoded) as! User
    }
}
