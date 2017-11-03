//
//  ColorPickerViewController.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 1/23/15.
//  Copyright (c) 2015 Adafruit Industries. All rights reserved.
//

import UIKit

protocol ColorPickerViewControllerDelegate: HelpViewControllerDelegate {
    
    func sendColor(_ red:UInt8, green:UInt8, blue:UInt8)
    
}

class ColorPickerViewController: UIViewController, UITextFieldDelegate, ISColorWheelDelegate {
    
    var delegate:ColorPickerViewControllerDelegate!
    @IBOutlet var helpViewController:HelpViewController!
    @IBOutlet var infoButton:UIButton!
    fileprivate var infoBarButton:UIBarButtonItem?
    var helpPopoverController:UIPopoverController?
    
//    @IBOutlet var redSlider:UISlider!
//    @IBOutlet var greenSlider:UISlider!
//    @IBOutlet var blueSlider:UISlider!
//    @IBOutlet var redField:UITextField!
//    @IBOutlet var greenField:UITextField!
//    @IBOutlet var blueField:UITextField!
//    @IBOutlet var swatchView:UIView!
    
    @IBOutlet var valueLable:UILabel!
    @IBOutlet var sendButton:UIButton!
    @IBOutlet var wheelView:UIView!
    @IBOutlet var wellView:UIView!
    @IBOutlet var wheelHorzConstraint:NSLayoutConstraint!
    @IBOutlet var wellVertConstraint:NSLayoutConstraint!    //34 for 3.5"
    @IBOutlet var wellHeightConstraint:NSLayoutConstraint!  //64 for 3.5"
    @IBOutlet var sendVertConstraint:NSLayoutConstraint!    //46 for 3.5"
    @IBOutlet var brightnessSlider: UISlider!
    @IBOutlet var sliderGradientView: GradientView!
    
    var colorWheel:ISColorWheel!
    
    convenience init(aDelegate:ColorPickerViewControllerDelegate){
        
        //Separate NIBs for iPhone & iPad
        
        var nibName:NSString
        
        if IS_IPHONE {
            nibName = "ColorPickerViewController_iPhone"
        }
        else{   //IPAD
            nibName = "ColorPickerViewController_iPad"
        }
        
        self.init(nibName: nibName as String, bundle: Bundle.main)
        
        self.delegate = aDelegate
        self.title = "Color Picker"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Color Picker"
        
        //setup help view
        self.helpViewController.title = "Color Picker Help"
        self.helpViewController.delegate = delegate
        
        //add info bar button
        let archivedData = NSKeyedArchiver.archivedData(withRootObject: infoButton)
        let buttonCopy = NSKeyedUnarchiver.unarchiveObject(with: archivedData) as! UIButton
        buttonCopy.addTarget(self, action: #selector(ColorPickerViewController.showInfo(_:)), for: UIControlEvents.touchUpInside)
        infoBarButton = UIBarButtonItem(customView: buttonCopy)
        self.navigationItem.rightBarButtonItem = infoBarButton
        
        sendButton.layer.cornerRadius = 4.0
        sendButton.layer.borderColor = sendButton.currentTitleColor.cgColor
        sendButton.layer.borderWidth = 1.0;
        
        wellView.backgroundColor = UIColor.white
        wellView.layer.borderColor = UIColor.black.cgColor
        wellView.layer.borderWidth = 1.0
        
        wheelView.backgroundColor = UIColor.clear
        
        //customize brightness slider
        let sliderTrackImage = UIImage(named: "clearPixel.png")
        brightnessSlider.setMinimumTrackImage(sliderTrackImage, for: UIControlState())
        brightnessSlider.setMaximumTrackImage(sliderTrackImage, for: UIControlState())
        
        sliderGradientView.endColor = wellView.backgroundColor!
        
        //adjust layout for 3.5" displays
        if (IS_IPHONE_4) {
            
            wellVertConstraint.constant   = 34
            wellHeightConstraint.constant = 64
            sendVertConstraint.constant   = 46
        }

        
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        

        
        

    }
    
    
    override func viewDidLayoutSubviews() {
        
        super.viewDidLayoutSubviews()
        
        //Add color wheel
        if wheelView.subviews.count == 0 {
//            let size = wheelView.bounds.size
            
//            let wheelSize = CGSizeMake(size.width * 0.9, size.width * 0.9)
            
            //                let rect = CGRectMake(size.width / 2 - wheelSize.width / 2,
            ////                            0.0,
            //                            size.height * 0.1,
            //                            wheelSize.width,
            //                            wheelSize.height)
            
            let rect = CGRect(
                x: 0.0,
                y: 0.0,
                width: wheelView.bounds.size.width,
                height: wheelView.bounds.size.height)
            
            colorWheel = ISColorWheel(frame: rect)
            colorWheel.delegate = self
            colorWheel.continuous = true
            
            wheelView.addSubview(colorWheel)
        }
    }
    
    
//    @IBAction func sliderValueChanged(sender:UISlider) {
//        
//        var textField:UITextField
//        
//        switch sender.tag {
//        case 0: //red
//            textField = redField
//        case 1: //green
//            textField = greenField
//        case 2: //blue
//            textField = blueField
//        default:
//            printLog(self, "\(#function)", "slider returned invalid tag")
//            return
//        }
//        
//        //Dismiss any text field
//        
//        //Update textfield
//        textField.text = "\(Int(sender.value))"
//        
//        //Update value label
//        updateValueLabel()
//        
//    }
    
    
    func updateValueLabel() {

        //RGB method
//        valueLable.text = "R:\(redField.text)  G:\(greenField.text)  B:\(blueField.text)"
//        
//        //Update color swatch
//        let color = UIColor(red: CGFloat(redSlider.value / 255.0), green: CGFloat(greenSlider.value  / 255.0), blue: CGFloat(blueSlider.value  / 255.0), alpha: 1.0)
//        swatchView.backgroundColor = color
        
    }
    
    
//    func textFieldDidEndEditing(textField: UITextField) {
//        
//        var slider:UISlider
//        
//        switch textField.tag {
//        case 0: //red
//            slider = redSlider
//        case 1: //green
//            slider = greenSlider
//        case 2: //blue
//            slider = blueSlider
//        default:
//            printLog(self, "\(#function)", "textField returned with invalid tag")
//            return
//        }
//        
//        //Update slider
//        var intVal = textField.text.toInt()?
//        if (intVal != nil) {
//            slider.value = Float(intVal!)
//        }
//        else {
//            printLog(self, "\(#function)", "textField returned non-integer value")
//            return
//        }
//        
//        //Update value label
//        updateValueLabel()
//        
//    }
    
    
    @IBAction func showInfo(_ sender:AnyObject) {
        
        // Show help info view on iPhone via flip transition, called via "i" button in navbar
        
        if (IS_IPHONE) {
            present(helpViewController, animated: true, completion: nil)
        }
            
            //iPad
        else if (IS_IPAD) {
            
            //show popover if it isn't shown
            helpPopoverController?.dismiss(animated: true)
            
            helpPopoverController = UIPopoverController(contentViewController: helpViewController)
            helpPopoverController?.backgroundColor = UIColor.darkGray
            let rightBBI:UIBarButtonItem! = self.navigationController?.navigationBar.items?.last!.rightBarButtonItem
            let aFrame:CGRect = rightBBI!.customView!.frame
            helpPopoverController?.present(from: aFrame,
                in: rightBBI.customView!.superview!,
                permittedArrowDirections: UIPopoverArrowDirection.any,
                animated: true)
        }
    }
    
    
    @IBAction func brightnessSliderChanged(_ sender: UISlider) {
        
        colorWheelDidChangeColor(colorWheel)
        
    }

    
    @IBAction func sendColor() {
        
        //Send color bytes thru UART
        
        var r:CGFloat = 0.0
        var g:CGFloat = 0.0
        var b:CGFloat = 0.0
        
        wellView.backgroundColor!.getRed(&r, green: &g, blue: &b, alpha: nil)
        
        delegate.sendColor((UInt8(255.0 * Float(r))), green: (UInt8(255.0 * Float(g))), blue: (UInt8(255.0 * Float(b))))
    }
    
    
    func colorWheelDidChangeColor(_ colorWheel:ISColorWheel) {
        
        let colorWheelColor = colorWheel.currentColor()
        
//        sliderTintView.backgroundColor = colorWheelColor
        
        sliderGradientView.endColor = colorWheelColor!
        
        let brightness = CGFloat(brightnessSlider.value)
        var red:CGFloat = 0.0
        var green:CGFloat = 0.0
        var blue:CGFloat = 0.0
        colorWheelColor?.getRed(&red, green: &green, blue: &blue, alpha: nil)
        red *= brightness; green *= brightness; blue *= brightness
        let color = UIColor(red: red, green: green, blue: blue, alpha: 1.0)
        
        wellView.backgroundColor = color
        
//        var r:CGFloat = 0.0
//        var g:CGFloat = 0.0
//        var b:CGFloat = 0.0
////        var a:UnsafeMutablePointer<CGFloat>
//        color.getRed(&r, green: &g, blue: &b, alpha: nil)
        
        valueLable.text = "R:\(Int(255.0 * Float(red)))  G:\(Int(255.0 * Float(green)))  B:\(Int(255.0 * Float(blue)))"
    
    }

}
