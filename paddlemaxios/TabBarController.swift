import Foundation
import UIKit

class TabBarController: UITabBarController, UITabBarControllerDelegate {

    // View controllers
    var profileViewController: UIViewController!
    var homeViewController: HomeViewController!
    var settingsViewController: UIViewController!
    
    // MARK: view lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        profileViewController = UIViewController()
        profileViewController.tabBarItem = UITabBarItem(
                title: "Profile",
                image: UIImage(named: "circle-user-7.png"),
                selectedImage: nil
        )

        homeViewController = HomeViewController()
        homeViewController.tabBarItem = UITabBarItem(
                title: "Paddle",
                image: UIImage(named: "earth-america-7.png"),
                selectedImage: nil)

        settingsViewController = UIViewController()
        settingsViewController.tabBarItem = UITabBarItem(
                title: "Settings",
                image: UIImage(named: "gear-7.png"),
                selectedImage: nil
        )

        viewControllers = [
            profileViewController,
            homeViewController,
            settingsViewController
        ]

        selectedViewController = viewControllers![1]
    }

    // MARK: view manipulation
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }

}
