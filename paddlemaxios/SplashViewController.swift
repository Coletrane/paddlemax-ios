import Foundation
import UIKit
import FBSDKCoreKit
import FBSDKLoginKit

class SplashViewController: UIViewController {

    @IBOutlet var logo: UILabel!
    @IBOutlet var fbLoginButton: FBSDKLoginButton!

    convenience init() {
        self.init(
                nibName: "SplashViewController",
                bundle: Bundle.main)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        logo.isHidden = true

        fbLoginButton.readPermissions = [
            "public_profile",
            "email",
            // These require review, might get rid of them
            "user_birthday",
            "user_location",
        ]

        if (FBSDKAccessToken.current() == nil) {

        } else {
            UserDefaults.standard.set(
                    "FB_\(FBSDKAccessToken.current().userID)",
                    forKey: USER_ID)


        }
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


}
