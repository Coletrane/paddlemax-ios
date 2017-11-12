import Foundation
import UIKit
import CoreBluetooth

protocol HomeViewControllerDelegate: AnyObject {
    func createDeviceListViewController()
    func refreshHomeViewLabels()
}

class HomeViewController: UIViewController {

    var deviceListViewController: DeviceListViewController!

    @IBOutlet var connectedLabel: UILabel!
    @IBOutlet var connectButton: UIButton!
    @IBOutlet var pageControl: UIPageControl!

    var delegate: HomeViewControllerDelegate?

//    override init(nibName nib: String?, bundle nibBundle: Bundle?) {
//        super.init(nibName: "HomeViewController", bundle: Bundle.main)
//    }

    convenience init(aDelegate:HomeViewControllerDelegate) {
        self.init(nibName: "HomeViewController", bundle: Bundle.main)
        self.delegate = aDelegate
        connectedLabel = UILabel()
        connectButton = UIButton()
        connectButton.isHidden = false
    }

//    required init(coder aDecoder: NSCoder) {
//        super.init(coder: aDecoder)!
//    }

    override func viewDidLoad() {
        super.viewDidLoad()

        connectButton.layer.cornerRadius = 4
        connectButton.layer.borderWidth = 1
        connectButton.layer.borderColor = BLUE.cgColor
        pageControl.currentPage = 1
        self.delegate?.refreshHomeViewLabels()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        connectedLabel.isHidden = true
        connectButton.isHidden = true
    }
    @IBAction func connectButtonPressed(sender: AnyObject) {
        delegate?.createDeviceListViewController()
    }


}
