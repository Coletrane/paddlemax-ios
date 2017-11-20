import Foundation
import CoreBluetooth
import UIKit

extension Data {

    func hexRepresentationWithSpaces(_ spaces: Bool) -> NSString {

        var byteArray = [UInt8](repeating: 0x0, count: self.count)
        // The Test Data is moved into the 8bit Array.
        (self as NSData).getBytes(&byteArray, length: self.count)

        var hexBits = "" as String
        for value in byteArray {
            let newHex = NSString(format: "0x%2X", value) as String
            hexBits += newHex.replacingOccurrences(of: " ", with: "0", options: NSString.CompareOptions.caseInsensitive)
            if spaces {
                hexBits += " "
            }
        }
        return hexBits as NSString
    }


    func hexRepresentation() -> String {

        let dataLength: Int = self.count
        let string = NSMutableString(capacity: dataLength * 2)
        let dataBytes: UnsafeRawPointer = (self as NSData).bytes
        for idx in 0..<dataLength {
            let byteArr = [UInt(dataBytes.load(fromByteOffset: idx, as: UInt8.self))]
            string.appendFormat("%02x", byteArr)
        }

        return string as String
    }


    func stringRepresentation() -> String {

        //Write new received data to the console text view

        //convert data to string & replace characters we can't display
        let dataLength: Int = self.count
        var data = [UInt8](repeating: 0, count: dataLength)

        (self as NSData).getBytes(&data, length: dataLength)

        for index in 0..<dataLength {
            if (data[index] <= 0x1f) || (data[index] >= 0x80) { //null characters
                if (data[index] != 0x9)       //0x9 == TAB
                       && (data[index] != 0xa)   //0xA == NL
                       && (data[index] != 0xd) { //0xD == CR
                    data[index] = 0xA9
                }

            }
        }

        let newString = NSString(bytes: &data, length: dataLength, encoding: String.Encoding.utf8.rawValue)

        return newString! as String

    }

}


extension NSString {

    func toHexSpaceSeparated() -> NSString {

        let len = UInt(self.length)
        var charArray = [unichar](repeating: 0x0, count: self.length)

        //        let chars = UnsafeMutablePointer<unichar>(malloc(len * UInt(sizeofValue(unichar))))

        self.getCharacters(&charArray)

        let hexString = NSMutableString()
        var charString: NSString

        for i in 0..<len {
            charString = NSString(format: "0x%02X", charArray[Int(i)])

            if (charString.length == 1) {
                charString = "0" + (charString as String) as NSString
            }

            hexString.append(charString.appending(" "))
        }


        return hexString
    }

}


extension CBUUID {

    func representativeString() -> NSString {

        let data = self.data
        var byteArray = [UInt8](repeating: 0x0, count: data.count)
        (data as NSData).getBytes(&byteArray, length: data.count)

        let outputString = NSMutableString(capacity: 16)

        for value in byteArray {

            switch (value) {
            case 9:
                outputString.appendFormat("%02x-", value)
                break
            default:
                outputString.appendFormat("%02x", value)
            }

        }

        return outputString
    }


    func equalsString(_ toString: String, caseSensitive: Bool, omitDashes: Bool) -> Bool {

        var aString = toString
        var verdict = false
        var options = NSString.CompareOptions.caseInsensitive

        if omitDashes == true {
            aString = toString.replacingOccurrences(of: "-", with: "", options: NSString.CompareOptions.literal, range: nil)
        }

        if caseSensitive == true {
            options = NSString.CompareOptions.literal
        }

//        println("\(self.representativeString()) ?= \(aString)")

        verdict = aString.compare(self.representativeString() as String, options: options, range: nil, locale: Locale.current) == ComparisonResult.orderedSame

        return verdict

    }

}


func printLog(_ obj: AnyObject, funcName: String, logString: String?) {

    if LOGGING != true {
        return
    }

    if logString != nil {
        print("\(obj.classForCoder!.description()) \(funcName) : \(logString!)")
    } else {
        print("\(obj.classForCoder!.description()) \(funcName)")
    }

}


func binaryforByte(_ value: UInt8) -> String {

    var str = String(value, radix: 2)
    let len = str.characters.count
    if len < 8 {
        var addzeroes = 8 - len
        while addzeroes > 0 {
            str = "0" + str
            addzeroes -= 1
        }
    }

    return str
}


extension UIImage {
    func tintWithColor(_ color: UIColor) -> UIImage {

        UIGraphicsBeginImageContextWithOptions(self.size, false, 0.0)
        let context = UIGraphicsGetCurrentContext()

        // flip the image
        context?.scaleBy(x: 1.0, y: -1.0)
        context?.translateBy(x: 0.0, y: -self.size.height)

        // multiply blend mode
        context?.setBlendMode(CGBlendMode.multiply)

        let rect = CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height)
        context?.clip(to: rect, mask: self.cgImage!)
        color.setFill()
        context?.fill(rect)

        // create uiimage
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage!

    }
}

extension UIColor {
    convenience init(red: Int, green: Int, blue: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")

        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }

    convenience init(_ rgb: Int) {
        self.init(
            red: (rgb >> 16) & 0xFF,
            green: (rgb >> 8) & 0xFF,
            blue: rgb & 0xFF
        )
    }
}

extension UIView {
    func fadeTransition(_ duration:CFTimeInterval) {
        let animation = CATransition()
        animation.timingFunction = CAMediaTimingFunction(name:
        kCAMediaTimingFunctionEaseInEaseOut)
        animation.type = kCATransitionFade
        animation.duration = duration
        layer.add(animation, forKey: kCATransitionFade)
    }
}
