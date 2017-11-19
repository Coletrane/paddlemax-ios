import Foundation
import UIKit

class TabBarController: UITabBarController, UITabBarControllerDelegate {

    // View controllers
    var profileViewController: UIViewController!
    var homeViewController: HomeViewController!
    var settingsViewController: UIViewController!

    // MARK: constructors
    convenience init() {
        self.init(
                nibName: "TabBarController",
                bundle: Bundle.main)

        delegate = self

        setViewControllers(viewControllers, animated: true)
    }

    override init(nibName nib: String?, bundle nibBundle: Bundle?) {
        super.init(nibName: nib, bundle: nibBundle)
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }
    
    // MARK: view lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        profileViewController = UIViewController()
        profileViewController.tabBarItem = UITabBarItem(
                title: "Profile",
                image: .none,
                selectedImage: .none
        )

        homeViewController = HomeViewController()
        homeViewController.tabBarItem = UITabBarItem(
                title: "Home",
                image: .none,
                selectedImage: .none)

        settingsViewController = UIViewController()
        settingsViewController.tabBarItem = UITabBarItem(
                title: "Settings",
                image: .none,
                selectedImage: .none
        )

        viewControllers = [
            profileViewController,
            homeViewController,
            settingsViewController
        ]
    }

    // MARK: view manipulation
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }

}
