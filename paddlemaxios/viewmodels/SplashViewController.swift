import Foundation
import UIKit
import FBSDKCoreKit
import FBSDKLoginKit

class SplashViewController: UIViewController, FBSDKLoginButtonDelegate {

    // Services
    let userService = UserService.sharedInstance

    // Outlets
    @IBOutlet var logo: UILabel!
    @IBOutlet var fbLoginButton: FBSDKLoginButton!

    // Status bar
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return .lightContent
    }

    convenience init() {
        self.init(
                nibName: "SplashViewController",
                bundle: Bundle.main)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        logo.isHidden = true

        fbLoginButton = FBSDKLoginButton()
        fbLoginButton.delegate = self
        fbLoginButton.readPermissions = [
            "public_profile",
            "email",
            // These require review, might get rid of them
            "user_birthday",
            "user_location",
        ]
        fbLoginButton.center = self.view.center
        self.view.addSubview(fbLoginButton)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        logo.isHidden = false
//        var timer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(self.timerAction), userInfo: nil, repeats: true)


        logo.fadeTransition(0.5)
    }

    @objc func timerAction() {
        // do nothing
    }

    func loginButton(
            _ loginButton: FBSDKLoginButton!,
            didCompleteWith result: FBSDKLoginManagerLoginResult!,
            error: Error!) {

        if (error != nil) {
            printLog(
                    self,
                    funcName: #function,
                    logString: error.localizedDescription)
        } else {
            let bday = result.grantedPermissions.contains("user_birthday")
            let loc = result.grantedPermissions.contains("user_location")

            print(result.grantedPermissions)
            userService.getUserFb(birthday: bday, location: loc)
        }
    }

    func loginButtonDidLogOut(_ loginButton: FBSDKLoginButton!) {
        //
    }
}
