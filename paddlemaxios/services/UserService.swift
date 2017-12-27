import Foundation

class UserService {

    // Singleton
    static let sharedInstance = UserService()

    // Variables
    var currentUser: User?

    required init() {
        currentUser = getUserFromPrefs()
        if currentUser != nil {
            currentUser = getUser()
        }
    }

    func getUser() -> User? {

        let authStr = String(
                format: "%@:%@",
                (currentUser?.email)!,
                (currentUser?.password)!)
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
                    self.saveUserInPrefs(user)
                }
            }
        } catch {
            printLog(self,
                    funcName: #function,
                    logString: "Error deserializing \(user) to json")
        }
    }

    func saveUserInPrefs(_ user: User) {
        let encoded: Data = NSKeyedArchiver.archivedData(withRootObject: user)
        UserDefaults.standard.set(encoded, forKey: USER)
        UserDefaults.standard.synchronize()
    }

    func getUserFromPrefs() -> User {
        let decoded = UserDefaults.standard.object(forKey: USER) as! Data
        return NSKeyedUnarchiver.unarchiveObject(with: decoded) as! User
    }
}
