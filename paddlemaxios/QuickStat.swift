import Foundation
import UIKit

protocol QuickStatDelegate: HomeViewControllerDelegate {

}

class QuickStat: UIView {

    var delegate: QuickStatDelegate?

    fileprivate let QUICK_STAT_TIME = "quickStatTime"
    fileprivate let QUICK_STAT_SETTING = "quickStatSetting"

    fileprivate var timePeriod: TimePeriod!
    fileprivate var quickStat: QuickStatValue!

    override init(frame: CGRect) {
        super.init(frame: frame)

        setUserSettings()
    }

    convenience init(aDelegate: QuickStatDelegate) {
        self.init(frame: CGRect.zero)

        delegate = aDelegate
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("This class does not support NSCoding")
    }

    func setUserSettings() {
        if let userTimePeriod = UserDefaults.standard.string(forKey: QUICK_STAT_TIME) {
            timePeriod = TimePeriod(rawValue: userTimePeriod)
        } else {
            UserDefaults.standard.set(TimePeriod.oneWeek.rawValue, forKey: QUICK_STAT_TIME)
        }

        // TODO: handle localiztion measurement systems
        if let userQuickStat = UserDefaults.standard.string(forKey: QUICK_STAT_SETTING) {
            quickStat = QuickStatValue(rawValue: userQuickStat)
        } else {
            UserDefaults.standard.set(QuickStatValue.distance.rawValue, forKey: QUICK_STAT_SETTING)
        }

        delegate?.setQuickStatLabels(timePeriod: timePeriod, quickStat: quickStat)
    }



}
