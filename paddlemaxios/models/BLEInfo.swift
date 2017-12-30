import Foundation


public struct BLEDescriptor {
    
    var title:String!
    var UUID:Foundation.UUID!
    
}


public struct BLECharacteristic {
    
    var title:String!
    var UUID:Foundation.UUID!
    var descriptors:[BLEDescriptor]
    
}


public struct BLEService {
    
    var title:String!
    var UUID:Foundation.UUID!
    var characteristics:[BLECharacteristic]
    
}
