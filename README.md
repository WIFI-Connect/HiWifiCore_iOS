# HiWifiCore Swift Package

This is the Swift Package that is needed to add the HiWifi service to an existing Xcode project/app.

### How to add the HiWifi service to your existing Xcode project/app

- Update your existing Xcode project to Xcode 12.5.1 or later.

- Change the deployment target of your app to iOS 13 or later.

- Add the HiWifiCore Swift Package [https://github.com/WIFI-Connect/HiWifiCore_iOS.git](https://github.com/WIFI-Connect/HiWifiCore_iOS.git) to your project  
  **Make sure version 1.0.2 or later of the package is used!**  
  The Swift package CryptoSwift 1.4.0 will be added automatically too.

- Add the following capabilities unter **"Signing & Capabilities"** to your app target(s):  
  **Access WiFi Information**, **Push Notifications**, **Background Modes > Location updates**

- Add the following keys with a description to the Info.plist of your app:  
  **Privacy - Location When In Use Usage Description** (NSLocationWhenInUseUsageDescription)  
  **Privacy - Location Always and When In Use Usage Description** (NSLocationAlwaysAndWhenInUseUsageDescription)  
  So the app can access the current Wi-Fi information even when running in the background.

- Add the provided custom **HiWifiServiceConfig.json** file to your project/app.  
  If you don't have a custom HiWifiServiceConfig.json file yet you can use the file from the **HiWifiCore Demo** project at  
  [https://github.com/WIFI-Connect/HiWifiCoreDemo_iOS](https://github.com/WIFI-Connect/HiWifiCoreDemo_iOS) for testing.

### How to use the HiWifi service in your app

- Add/Change the following code in your AppDelegate class:

		import HiWifiCore

		class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, HiWifiLocationListener {
		
		  var hiwifiService: HiWifiService = HiWifiService(locationManager: CLLocationManager())
			
		  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		    // Override point for customization after application launch.
		    DispatchQueue.main.async {
		      self.setupHiWifiService()
		    }
		    return true
		  }

		  func setupHiWifiService() {
			self.hiwifiService.setup() { status in
			  if status == .successful {
			    let options: UNAuthorizationOptions = [.alert, .sound, .badge]
			    UNUserNotificationCenter.current().requestAuthorization(options: options) { (didAllow, error) in
			      if !didAllow {
			        print("HiWifi service: User declined notifications!")
			      } else {
			        DispatchQueue.main.async {
			          UNUserNotificationCenter.current().delegate = self
			          self.hiwifiService.requestLocationUpdates(self)
			          print("HiWifi service: Running...")
			        }
			      }
			    }
			  } else {
			    print("HiWifi service: Setup failed with status: \(status)")
			  }
			}
		  }
	
		  // MARK: - UNUserNotificationCenterDelegate
			
		  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: (UNNotificationPresentationOptions) -> Void) {
			print("app notification foreground callback")
			completionHandler([UNNotificationPresentationOptions.alert, UNNotificationPresentationOptions.sound, UNNotificationPresentationOptions.badge])
		  }
			
		  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
			let targetInfo: String = response.notification.request.content.categoryIdentifier
			if targetInfo.starts(with: "hiwifi") {
			  hiwifiService.onReceive(notification: response.notification)
			}
			completionHandler()
		  }
			
			
		  // MARK: - HiWifiLocationListener
			
		  func onUpdate(location: HiWifiLocation?, error: HiWifiError?) {
			print("onUpdate:\(String(describing: location)) error:\(String(describing: error))")
		  }


- Check if you can build and run your app without any error messages on a real device.

- If you are using the **HiWifiServiceConfig.json** file from the **HiWifiCore Demo** project check if your app sends a notification when you connect your device to a WiFi access point with the SSID "hiwifitest". **The access point needs internet access!**

- If your are using the provided custom **HiWifiServiceConfig.json** file check if your app sends a notification when you connect your device to a WiFi access point with any SSID configured in the GoLive Control Center for your app. **All access points need internet access!**