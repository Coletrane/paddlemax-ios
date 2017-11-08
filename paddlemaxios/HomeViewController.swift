import Foundation
import UIKit
import CoreBluetooth

protocol HomeViewControllerDelegate: AnyObject {
    func createDeviceListViewController()
}

class HomeViewController: UIViewController {

    var deviceListViewController: DeviceListViewController!

    @IBOutlet var connectedLabel: UILabel!
    @IBOutlet var connectButton: UIButton!
    @IBOutlet var pageControl: UIPageControl!

    var delegate: HomeViewControllerDelegate?

    override init(nibName nib: String?, bundle nibBundle: Bundle?) {
        super.init(nibName: "HomeViewController", bundle: Bundle.main)
    }

    convenience init(aDelegate:HomeViewControllerDelegate) {
        self.init(nibName: "HomeViewController", bundle: Bundle.main)
        self.delegate = aDelegate
        connectedLabel = UILabel()
        connectButton = UIButton()
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        pageControl.currentPage = 1

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

//    func didBecomeActive() {
//        refreshConnectionViews()
//    }

    @IBAction func connectButtonPressed(sender: AnyObject) {
        delegate?.createDeviceListViewController()
    }
}
