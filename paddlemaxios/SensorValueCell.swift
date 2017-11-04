import UIKit

class SensorValueCell: UITableViewCell {
    
    var valueLabel:UILabel!
    
    var prefixString:String = ""
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
    
    func updateValue(_ newVal:Float){
        
        self.valueLabel.text = prefixString + ": \(newVal)"
        
    }
    
}
