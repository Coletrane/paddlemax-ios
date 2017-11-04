import Foundation
import UIKit
import Dispatch


protocol UARTViewControllerDelegate: HelpViewControllerDelegate {
    
    func sendData(_ newData:Data)
    
}


class UARTViewController: UIViewController, UITextFieldDelegate, UITextViewDelegate, UIPopoverControllerDelegate {

    enum ConsoleDataType {
        case log
        case rx
        case tx
    }
    
    enum ConsoleMode {
        case ascii
        case hex
    }
    
    var delegate:UARTViewControllerDelegate?
    @IBOutlet var helpViewController:HelpViewController!
    @IBOutlet weak var consoleView:UITextView!
    @IBOutlet weak var msgInputView:UIView!
    @IBOutlet var msgInputYContraint:NSLayoutConstraint?    //iPad
    @IBOutlet weak var inputField:UITextField!
    @IBOutlet weak var inputTextView:UITextView!
    @IBOutlet weak var consoleCopyButton:UIButton!
    @IBOutlet weak var consoleClearButton:UIButton!
    @IBOutlet weak var consoleModeControl:UISegmentedControl!
    @IBOutlet var sendButton: UIButton!
    @IBOutlet var echoSwitch:UISwitch!
    
    fileprivate var echoLocal:Bool = false
    fileprivate var keyboardIsShown:Bool = false
    fileprivate var consoleAsciiText:NSAttributedString? = NSAttributedString(string: "")
    fileprivate var consoleHexText: NSAttributedString? = NSAttributedString(string: "")
    fileprivate let backgroundQueue : DispatchQueue = DispatchQueue(label: "com.adafruit.bluefruitconnect.bgqueue", attributes: [])
    fileprivate var lastScroll:CFTimeInterval = 0.0
    fileprivate let scrollIntvl:CFTimeInterval = 1.0
    fileprivate var lastScrolledLength = 0
    fileprivate var scrollTimer:Timer?
    fileprivate var blueFontDict:NSDictionary!
    fileprivate var redFontDict:NSDictionary!
    fileprivate let unkownCharString:NSString = "�"
    fileprivate let kKeyboardAnimationDuration = 0.3
    fileprivate let notificationCommandString = "N!"
    
    
    convenience init(aDelegate:UARTViewControllerDelegate){
        
        //Separate NIBs for iPhone 3.5", iPhone 4", & iPad
        
        var nibName:NSString
        
        if IS_IPHONE {
            nibName = "UARTViewController_iPhone"
        }
        else{   //IPAD
            nibName = "UARTViewController_iPad"
        }
        
        self.init(nibName: nibName as String, bundle: Bundle.main)
        
        self.delegate = aDelegate
        self.title = "UART"
        
    }
    
    
    override func viewDidLoad(){
        
        //setup help view
        self.helpViewController.title = "UART Help"
        self.helpViewController.delegate = delegate
        
        //round corners on console
        self.consoleView.clipsToBounds = true
        self.consoleView.layer.cornerRadius = 4.0
        
        //round corners on inputTextView
        self.inputTextView.clipsToBounds = true
        self.inputTextView.layer.cornerRadius = 4.0

        //retrieve console font
        let consoleFont = consoleView.font
        blueFontDict = NSDictionary(objects: [consoleFont!, UIColor.blue], forKeys: [NSAttributedStringKey.font as NSCopying,NSAttributedStringKey.foregroundColor as NSCopying])
        redFontDict = NSDictionary(objects: [consoleFont!, UIColor.red], forKeys: [NSAttributedStringKey.font as NSCopying,NSAttributedStringKey.foregroundColor as NSCopying])

        //fix for UITextView
        consoleView.layoutManager.allowsNonContiguousLayout = false
    }
    
    override func didReceiveMemoryWarning(){
        
        super.didReceiveMemoryWarning()
    
        clearConsole(self)
        
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(animated)
        
        //update per prefs
        echoLocal = uartShouldEchoLocal()
        echoSwitch.setOn(echoLocal, animated: false)
        
        //register for keyboard notifications
        NotificationCenter.default.addObserver(self, selector: #selector(UARTViewController.keyboardWillShow(_:)), name: NSNotification.Name(rawValue: "UIKeyboardWillShowNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(UARTViewController.keyboardWillHide(_:)), name: NSNotification.Name(rawValue: "UIKeyboardWillHideNotification"), object: nil)
        
        //register for textfield notifications
        //        NSNotificationCenter.defaultCenter().addObserver(self, selector: "textFieldDidChange", name: "UITextFieldTextDidChangeNotification", object:self.view.window)

    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        scrollTimer?.invalidate()
        
        scrollTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(UARTViewController.scrollConsoleToBottom(_:)), userInfo: nil, repeats: true)
        scrollTimer?.tolerance = 0.75
    }
    
    
    override func viewDidDisappear(_ animated: Bool) {
        
        scrollTimer?.invalidate()
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        
        //unregister for keyboard notifications
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        super.viewWillDisappear(animated)
        
    }
    
    
    func updateConsoleWithIncomingData(_ newData:Data) {
        
        //Write new received data to the console text view
        backgroundQueue.async(execute: { () -> Void in
            //convert data to string & replace characters we can't display
            let dataLength:Int = newData.count
            var data = [UInt8](repeating: 0, count: dataLength)
            
            (newData as NSData).getBytes(&data, length: dataLength)
            
            for index in 0...dataLength-1 {
                if (data[index] <= 0x1f) || (data[index] >= 0x80) { //null characters
                    if (data[index] != 0x9)       //0x9 == TAB
                        && (data[index] != 0xa)   //0xA == NL
                        && (data[index] != 0xd) { //0xD == CR
                            data[index] = 0xA9
                    }
                    
                }
            }
            
            
            let newString = NSString(bytes: &data, length: dataLength, encoding: String.Encoding.utf8.rawValue)
            printLog(self, funcName: "updateConsoleWithIncomingData", logString: newString! as String)
            
            //Check for notification command & send if needed
//            if newString?.containsString(self.notificationCommandString) == true {
//                printLog(self, "Checking for notification", "does contain match")
//                let msgString = newString!.stringByReplacingOccurrencesOfString(self.notificationCommandString, withString: "")
//                self.sendNotification(msgString)
//            }
            
            
            //Update ASCII text on background thread A
            let appendString = "" // or "\n"
            let attrAString = NSAttributedString(string: ((newString! as String)+appendString), attributes: self.redFontDict as? [NSAttributedStringKey : Any])
            let newAsciiText = NSMutableAttributedString(attributedString: self.consoleAsciiText!)
            newAsciiText.append(attrAString)
            
            let newHexString = newData.hexRepresentationWithSpaces(true)
            let attrHString = NSAttributedString(string: newHexString as String, attributes: self.redFontDict as? [NSAttributedStringKey : Any])
            let newHexText = NSMutableAttributedString(attributedString: self.consoleHexText!)
            newHexText.append(attrHString)
            
            
            
            DispatchQueue.main.async(execute: { () -> Void in
                self.updateConsole(newAsciiText, hexText: newHexText)
//                self.insertConsoleText(attrAString.string, hexText: attrHString.string)
            })
        })
        
    }
    
    
    func updateConsole(_ asciiText: NSAttributedString, hexText: NSAttributedString){
        
        consoleAsciiText = asciiText
        consoleHexText = hexText
        
        
        //scroll output to bottom
//        let time = CACurrentMediaTime()
//        if ((time - lastScroll) > scrollIntvl) {
        
            //write string to console based on mode selection
            switch (consoleModeControl.selectedSegmentIndex) {
            case 0:
                //ASCII
                consoleView.attributedText = consoleAsciiText
                break
            case 1:
                //Hex
                consoleView.attributedText = consoleHexText
                break
            default:
                consoleView.attributedText = consoleAsciiText
                break
            }
            
//            scrollConsoleToBottom()
//            lastScroll = time
//        }
        
        
    }
    
    
    @objc func scrollConsoleToBottom(_ timer:Timer) {
    
//        printLog(self, "scrollConsoleToBottom", "")
        
        let newLength = consoleView.attributedText.length
        
        if lastScrolledLength != newLength {
            
            consoleView.scrollRangeToVisible(NSMakeRange(newLength-1, 1))
            
            lastScrolledLength = newLength
            
        }
        
    }
    
    
    func updateConsoleWithOutgoingString(_ newString:NSString){
        
        //Update ASCII text
//        let appendString = "" // or "\n"
//        let attrString = NSAttributedString(string: (newString as String) + appendString, attributes: textColorDict as? [String : AnyObject])
//        let newAsciiText = NSMutableAttributedString(attributedString: self.consoleAsciiText!)
//        newAsciiText.append(attrString)
//        consoleAsciiText = newAsciiText
//        
//        
//        //Update Hex text
//        let attrHexString = NSAttributedString(string: newString.toHexSpaceSeparated() as String, attributes: textColorDict as? [String : AnyObject])
//        let newHexText = NSMutableAttributedString(attributedString: self.consoleHexText!)
//        newHexText.append(attrHexString)
//        consoleHexText = newHexText
//        
//        //write string to console based on mode selection
//        switch consoleModeControl.selectedSegmentIndex {
//        case 0: //ASCII
//            consoleView.attributedText = consoleAsciiText
//            break
//        case 1: //Hex
//            consoleView.attributedText = consoleHexText
//            break
//        default:
//            consoleView.attributedText = consoleAsciiText
//            break
//        }
        
        //scroll output
//        scrollConsoleToBottom()
        
    }
    
    
    func resetUI() {
        
        //Clear console & update buttons
        if consoleView != nil{
            clearConsole(self)
        }
        
        //Dismiss keyboard
        if inputField != nil {
            inputField.resignFirstResponder()
        }
        
    }
    
    
    @IBAction func clearConsole(_ sender : AnyObject) {
        
        consoleView.text = ""
        consoleAsciiText = NSAttributedString()
        consoleHexText = NSAttributedString()
        
    }
    
    
    @IBAction func copyConsole(_ sender : AnyObject) {
        
        let pasteBoard = UIPasteboard.general
        pasteBoard.string = consoleView.text
        let cyan = UIColor(red: 32.0/255.0, green: 149.0/255.0, blue: 251.0/255.0, alpha: 1.0)
        consoleView.backgroundColor = cyan
        
        UIView.animate(withDuration: 0.45, delay: 0.0, options: UIViewAnimationOptions.curveEaseIn, animations: { () -> Void in
            self.consoleView.backgroundColor = UIColor.white
        }) { (finished) -> Void in
            
        }
        
    }
    
    
    @IBAction func sendMessage(_ sender:AnyObject){
        
//        sendButton.enabled = false
        
//        if (inputField.text == ""){
//            return
//        }
//        let newString:NSString = inputField.text
        
        if (inputTextView.text == ""){
            return
        }
        let newString:NSString = inputTextView.text as! NSString
     
        sendUartMessage(newString)
        
//        inputField.text = ""
        inputTextView.text = ""
        
      
        
    }
    
    
    func sendUartMessage(_ message: NSString) {
        // Send to uart
        let messageStringPtr = UnsafePointer(message.utf8String!).withMemoryRebound(to: UInt8.self, capacity: 8) {
            return $0
        }
        let data = Data(bytes: messageStringPtr, count:message.length)
        delegate?.sendData(data)
        
        // Show on UI
        if echoLocal == true {
            updateConsoleWithOutgoingString(message)
        }
    }
    
    
    @IBAction func echoSwitchValueChanged(_ sender:UISwitch) {
        
        let boo = sender.isOn
        uartShouldEchoLocalSet(boo)
        echoLocal = boo
        
    }
    
    
    func receiveData(_ newData : Data){
        
        if (isViewLoaded && view.window != nil) {

            // Update UI
            updateConsoleWithIncomingData(newData)
        }
        
    }
    
    
    @objc func keyboardWillHide(_ sender : Notification) {
        
        if let keyboardSize = (sender.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            
            let yOffset:CGFloat = keyboardSize.height
            let oldRect:CGRect = msgInputView.frame
            msgInputYContraint?.constant += yOffset
            
            if IS_IPAD {
                let newRect = CGRect(x: oldRect.origin.x, y: oldRect.origin.y + yOffset, width: oldRect.size.width, height: oldRect.size.height)
                msgInputView.frame = newRect    //frame animates automatically
            }
         
            else {
                
                let newRect = CGRect(x: oldRect.origin.x, y: oldRect.origin.y + yOffset, width: oldRect.size.width, height: oldRect.size.height)
                msgInputView.frame = newRect    //frame animates automatically
                
            }
            
            keyboardIsShown = false
            
        }
        else {
            printLog(self, funcName: "keyboardWillHide", logString: "Keyboard frame not found")
        }
        
    }
    
    
    @objc func keyboardWillShow(_ sender : Notification) {
    
        //Raise input view when keyboard shows
    
        if keyboardIsShown {
            return
        }
    
        //calculate new position for input view
        if let keyboardSize = (sender.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            
            let yOffset:CGFloat = keyboardSize.height
            let oldRect:CGRect = msgInputView.frame
            msgInputYContraint?.constant -= yOffset     //Using autolayout on iPad
            
//            if (IS_IPAD){
            
                let newRect = CGRect(x: oldRect.origin.x, y: oldRect.origin.y - yOffset, width: oldRect.size.width, height: oldRect.size.height)
                self.msgInputView.frame = newRect   //frame animates automatically
//            }
//            
//            else {  //iPhone
//             
//                var newRect = CGRectMake(oldRect.origin.x, oldRect.origin.y - yOffset, oldRect.size.width, oldRect.size.height)
//                self.msgInputView.frame = newRect   //frame animates automatically
//                
//            }
            
            keyboardIsShown = true
            
        }
        
        else {
            printLog(self, funcName: "keyboardWillHide", logString: "Keyboard frame not found")
        }
    
    }
    
    
    //MARK: UITextViewDelegate methods
    
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        
        if textView === consoleView {
            //tapping on consoleview dismisses keyboard
            inputTextView.resignFirstResponder()
            return false
        }
        
        return true
    }
    
    
//    func textViewDidEndEditing(textView: UITextView) {
//        
//        sendMessage(self)
//        inputTextView.resignFirstResponder()
//        
//    }
    
    
    //MARK: UITextFieldDelegate methods
    
    func textFieldShouldReturn(_ textField: UITextField) ->Bool {
        
        //Keyboard's Done button was tapped
        
//        sendMessage(self)
//        inputField.resignFirstResponder()

        
        return true
    }
    
    
    @IBAction func consoleModeControlDidChange(_ sender : UISegmentedControl){
        
        //Respond to console's ASCII/Hex control value changed
        
        switch sender.selectedSegmentIndex {
        case 0:
            consoleView.attributedText = consoleAsciiText
            break
        case 1:
            consoleView.attributedText = consoleHexText
            break
        default:
            consoleView.attributedText = consoleAsciiText
            break
        }
        
    }
    
    
    func didConnect(){
        
        resetUI()
        
    }
    
    
    func sendNotification(_ msgString:String) {
        
        let note = UILocalNotification()
//        note.fireDate = NSDate().dateByAddingTimeInterval(2.0)
//        note.fireDate = NSDate()
        note.alertBody = msgString
        note.soundName =  UILocalNotificationDefaultSoundName
        
        DispatchQueue.main.async(execute: { () -> Void in
            UIApplication.shared.presentLocalNotificationNow(note)
        })
        
        
    }
    
    // MARK: UIPopoverControllerDelegate
    
    func popoverControllerDidDismissPopover(_ popoverController: UIPopoverController) {

    }

}





