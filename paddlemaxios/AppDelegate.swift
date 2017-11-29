import Foundation
import UIKit
import WatchConnectivity
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, WCSessionDelegate {

    var window:UIWindow?

    var tabBarController: UITabBarController!
    var splashViewController: SplashViewController!

    required override init() {
        super.init()
    }
    
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        window = UIWindow(frame: UIScreen.main.bounds)

        tabBarController = TabBarController()
        splashViewController = SplashViewController()

//        if let loggedIn = UserDefaults.standard.string(forKey: USER_LOGIN) {
//            window!.rootViewController = tabBarController
//        } else {
//            window!.rootViewController = splashViewController
//        }
        window!.rootViewController = tabBarController

        window!.makeKeyAndVisible()

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.sound, .alert, .badge],
            completionHandler: { (bool, err) in
                // TODO: handle them saying no
            })

        // Register Settings bundle and set default values
        var appDefaults = Dictionary<String, AnyObject>()
        appDefaults["updatescheck_preference"] = true as AnyObject;
        appDefaults["betareleases_preference"] = false as AnyObject;
        UserDefaults.standard.register(defaults: appDefaults)
        UserDefaults.standard.synchronize()
        
        if WCSession.isSupported() {
            print("creating WCSession …")
            let session = WCSession.default
            session.delegate = self
            session.activate()
            
            if session.isReachable == true {
                print("WCSession is reachable")
            }
            else {
                print("WCSession is not reachable")
            }
        }
        
        return true
        
    }
    
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Stop scanning
        if UIApplication.shared.keyWindow?.rootViewController is DeviceListViewController {
            let devList = UIApplication.shared.keyWindow?.rootViewController as! DeviceListViewController
            devList.stopScan()
        }
    }
    
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        
//        mainViewController?.didBecomeActive()
    }
    
    
//    func applicationWillTerminate(application: UIApplication) {
//        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
//    }
    
    
    // TODO: implement the watch

    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {

        
    }
    
    func application(_ application: UIApplication,
        handleWatchKitExtensionRequest userInfo: [AnyHashable: Any]?,
        reply: (@escaping ([AnyHashable: Any]?) -> Void)) {

    }

    // TODO: Implement these
    @available(iOS 9.3, *)
    func sessionDidDeactivate(_ session: WCSession) {
//        super.sessionDidDeactivate(session: WCSession)
    }

    @available(iOS 9.3, *)
    func sessionDidBecomeInactive(_ session: WCSession) {
//        super.sessionDidBecomeInactive(session: WCSession)
    }

    @available(iOS 9.3, *)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
//        super.session(session: WCSession, activationState, WCSessionActivationState, error?)
    }
    
}
