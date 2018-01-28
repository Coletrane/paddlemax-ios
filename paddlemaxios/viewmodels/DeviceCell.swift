import UIKit


class DeviceCell: UITableViewCell {

    // Outlets
    @IBOutlet var nameLabel:UILabel!
    @IBOutlet var signalImageView:UIImageView!

    // Variables
    var signalImages:[UIImage]!
    fileprivate var lastSigIndex = -1
    fileprivate var lastSigUpdate:Double = Date.timeIntervalSinceReferenceDate
    fileprivate let updateIntvl = 3.0


    // MARK: constructors
    init(labelText text: String) {
        super.init(style: UITableViewCellStyle.default, reuseIdentifier: nil)

        nameLabel = UILabel()
        nameLabel.text = text
        signalImageView = UIImageView()
        self.signalImages = [UIImage](arrayLiteral: UIImage(named: "signalStrength-0.png")!,
                UIImage(named: "signalStrength-1.png")!,
                UIImage(named: "signalStrength-2.png")!,
                UIImage(named: "signalStrength-3.png")!,
                UIImage(named: "signalStrength-4.png")!)

    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        // Initialization code

    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    
    func updateSignalImage(_ RSSI:NSNumber) {

        // Only update every few seconds
        let now = Date.timeIntervalSinceReferenceDate
        if lastSigIndex != -1 && (now - lastSigUpdate) < updateIntvl {
            return
        }
        
        let rssiInt = RSSI.intValue
        var index = 0
        
        if rssiInt == 127 {     // value of 127 reserved for RSSI not available
            index = 0
        }
        else if rssiInt <= -84 {
            index = 0
        }
        else if rssiInt <= -72 {
            index = 1
        }
        else if rssiInt <= -60 {
            index = 2
        }
        else if rssiInt <= -48 {
            index = 3
        }
        else {
            index = 4
        }
     
        if index != lastSigIndex {
            signalImageView.image = signalImages[index]
            lastSigIndex = index
            lastSigUpdate = now
        }
        
    }
    
}
