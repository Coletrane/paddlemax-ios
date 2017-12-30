import Foundation
import FBSDKCoreKit
import FBSDKLoginKit

class UserService {

    // Singleton
    static let sharedInstance = UserService()

    // Variables
    var currentUser: User?

    // Facebook auth token observer
    var fbToken = FBSDKAccessToken.current().tokenString {
        didSet {
            // Update user
        }
    }

    required init() {
        currentUser = getUserFromPrefs()
        if currentUser != nil {
            currentUser = getUser()
        }
    }

    // MARK: PaddleMax API calls

    func getUser() -> User? {

        guard currentUser != nil else {
            printLog(
                    self,
                    funcName: #function,
                    logString: "No Current User found, aborting API call")
            return nil
        }

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

    // MARK: Facebook API calls

    func getUserFb(birthday bday: Bool, location loc: Bool) {

        // Build reqest based on user acceping birthday and location perms
        var fields = "email, first_name, last_name"
        if (bday) {
            fields.append(",birthday ")
        }
        if (loc) {
            fields.append(",location ")
        }

        let req = FBSDKGraphRequest(
                graphPath: "me",
                parameters: ["fields": fields],
                tokenString: FBSDKAccessToken.current().tokenString,
                version: nil,
                httpMethod: "GET")
        req?.start(completionHandler: { (conn, res, err) -> Void in

            if (err != nil) {
                printLog(
                        self,
                        funcName: #function,
                        logString: "Error making graph request")
            } else {
                let data = res as! NSDictionary

                let formatter = DateFormatter()
                formatter.dateFormat = "MM/dd/yyyy"
                let birthday = formatter.date(from: data["birthday"] as! String)

                let locDict = data["location"] as! NSDictionary
                let location =  "id:  \(locDict["id"] as! String) name: \(locDict["name"] as! String)"

                self.currentUser = User(
                        nil,
                        data["first_name"] as! String,
                        data["last_name"] as! String,
                        data["email"] as! String,
                        FBSDKAccessToken.current().tokenString,   // Not sure best practices on this
                        birthday,
                        nil,
                        location)

                self.saveUserInPrefs(self.currentUser!)
            }
        })
    }

    func saveUserInPrefs(_ user: User) {
        let encoded: Data = NSKeyedArchiver.archivedData(withRootObject: user)
        UserDefaults.standard.set(encoded, forKey: USER)
        UserDefaults.standard.synchronize()
    }

    func getUserFromPrefs() -> User? {
        var user: User?

        if var raw = UserDefaults.standard.object(forKey: USER) {
            let decoded = raw as! Data
            user = NSKeyedUnarchiver.unarchiveObject(with: decoded) as! User
        }

        return user
    }
}
