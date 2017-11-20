import Foundation
import UIKit

class SplashViewController: UIViewController {

    @IBOutlet var logo: UILabel!

    convenience init() {
        self.init(
                nibName: "SplashViewController",
                bundle: Bundle.main)
    }

    override init(nibName nib: String?, bundle nibBundle: Bundle?) {
        super.init(nibName: nib, bundle: nibBundle)
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        logo.isHidden = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        logo.isHidden = false
        var timer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(self.timerAction), userInfo: nil, repeats: true)


        logo.fadeTransition(0.5)
    }

    @objc func timerAction() {
        // do nothing
    }


}
