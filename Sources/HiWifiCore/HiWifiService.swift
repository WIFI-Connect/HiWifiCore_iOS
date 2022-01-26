//
//  HiWifiService.swift
//  hiwificore
//
//  Created by Alexander Aries on 20.08.20.
//  Copyright © 2020 INT. WIFI Connect GmbH. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation
import Network
import UserNotifications

public enum HiWifiSetupStatus : Int32 {

    case unknown = 0

    case successful = 1
    
    case alreadyCalled = 2

    case configurationMissingOrIncorrect = 3
    
    case locationAuthorizationMissing = 4
    
    case errorLoadingSSIDs = 5
}

public class HiWifiService : NSObject, CLLocationManagerDelegate, WifiObserver, HiWifiPushInterface {

    private var listener: HiWifiLocationListener? = nil
    private var locationManager: CLLocationManager? = nil
    private var location: CLLocationCoordinate2D? = nil

    private var setupCallback: ((_ status: HiWifiSetupStatus) -> Void)? = nil

    private var locationAuthorizationRequested: Bool = false
    private var locationAuthorizationPromptShown: Bool = false
    private var locationPermissionGranted: Bool = false
    
    private var ssidList: [String] = []
    private var currentAccessPoint: AccessPointObject?

    private var lastStateWifiConnected = false
    
    private var resetCacheTimer: Timer? = nil
    
    private var deviceLocationCallback: ((_ location: CLLocationCoordinate2D?) -> Void)? = nil
    private var requestLocationTimoutTimer: Timer? = nil
    
    private let wifiChangeLock = NSLock()
    private var searchNetworkInfo: NetworkInfo? = nil
    private var connectedNetworkInfo: NetworkInfo? = nil
    private var checkConnectionTimer: Timer? = nil

    internal static var application_uid = ""
    internal static var pushEnabled = true
    internal static var usePasswordManager: Bool = false
    internal static var passwordManagerDisplayName: String = "HiWifi Netzwerk"
    internal static var userHiWifiSSIDList: Bool = true

    public init(locationManager: CLLocationManager) {
        
        super.init()
        
        self.locationManager = locationManager
        self.locationManager?.delegate = self
        self.locationManager?.allowsBackgroundLocationUpdates = true
        self.locationManager?.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }
    
    public func setup(config: String? = nil, completion: @escaping (_ status: HiWifiSetupStatus) -> Void) {
        
        if setupCallback != nil {
            completion(.alreadyCalled)
            return
        }
        
        if loadConfig(config) == false {
            completion(.configurationMissingOrIncorrect)
        }

        setupCallback = completion
        
        checkLocationAuthorization()
    }
    
    private func checkLocationAuthorization() {
        let authorizationStatus = CLLocationManager.authorizationStatus()
        if authorizationStatus == .authorizedAlways {
            self.locationPermissionGranted = true
            self.setupAfterLocatinAuthorization()
        } else if authorizationStatus == .notDetermined {
            self.locationAuthorizationRequested = true
            print("request when in use authorization...")
            self.locationManager?.requestWhenInUseAuthorization()
        } else if authorizationStatus == .authorizedWhenInUse {
            self.locationAuthorizationRequested = true
            self.locationAuthorizationPromptShown = false
            NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
            print("request always authorization...")
            self.locationManager?.requestAlwaysAuthorization()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                print("check for prompt!")
                if self.locationAuthorizationPromptShown == false {
                    self.locationAuthorizationRequested = false
                    self.setupCallback!(.locationAuthorizationMissing)
                    NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
                }
            }
        } else {
            if self.setupCallback != nil {
                self.setupCallback!(.locationAuthorizationMissing)
                NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
            }
        }
    }

    @objc func appWillResignActive() {
        print("App will resign active!")
        if self.locationAuthorizationRequested {
            NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
            self.locationAuthorizationPromptShown = true
            NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        }
    }
    
    @objc func appDidBecomeActive() {
        print("App did become active!")
        if self.locationAuthorizationRequested {
            NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
            DispatchQueue.main.async {
                self.checkLocationAuthorization()
            }
        }
    }
    
    private func setupAfterLocatinAuthorization() {
        if HiWifiService.userHiWifiSSIDList {
            getSSIDs { success in
                self.resetCache()
                if success && HiWifiService.usePasswordManager {
                    HotspotManager.registerLoginCallback()
                }
                if self.setupCallback != nil {
                    self.setupCallback!(success ? .successful : .errorLoadingSSIDs)
                }
            }
        } else {
            if self.setupCallback != nil {
                self.setupCallback!(.successful)
            }
        }
    }
    
    private func loadConfig(_ name: String?) -> Bool {
        let configName = name != nil ? name : "HiWifiServiceConfig.json"
        if let fileURL = Bundle.main.url(forResource: configName, withExtension: nil) {
            do {
                let jsonData = try Data(contentsOf: fileURL)
                guard let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: AnyObject] else {
                    return false
                }
                Logger.log("HiWifi Service configuration (\(configName!))")
                if let application_uid = json["application_uid"] as? String {
                    HiWifiService.application_uid = application_uid
                    Logger.log("- application_uid = \"\(application_uid)\"")
                } else {
                    assertionFailure("Missing application_uid in HiWifi Service configuration (\(fileURL))")
                }
                if let pushEnabled = json["pushEnabled"] as? Bool {
                    HiWifiService.pushEnabled = pushEnabled
                    Logger.log("- pushEnabled = \(pushEnabled)")
                }
                if let usePasswordManager = json["usePasswordManager"] as? Bool {
                    HiWifiService.usePasswordManager = usePasswordManager
                    Logger.log("- usePasswordManager = \(usePasswordManager)")
                    if usePasswordManager {
                        if let passwordManagerDisplayName = json["passwordManagerDisplayName"] as? String {
                            HiWifiService.passwordManagerDisplayName = passwordManagerDisplayName
                            Logger.log("- passwordManagerDisplayName = \"\(passwordManagerDisplayName)\"")
                        }
                    }
                }
                if let userHiWifiSSIDList = json["userHiWifiSSIDList"] as? Bool {
                    HiWifiService.userHiWifiSSIDList = userHiWifiSSIDList
                    Logger.log("- userHiWifiSSIDList = \(userHiWifiSSIDList)")
                }
                return true
            } catch {
                print("Error loading file at \(fileURL): \(error)")
                return false
            }
        }
        print("Could not load HiWifi Service configuration (\(configName!))")
        return false
    }
    
    public func requestLocationUpdates(_ listener: HiWifiLocationListener) {
        WifiHelper.shared.addObserver(observer: self)
        self.listener = listener
        self.locationManager?.startUpdatingLocation()
    }
    
    public func cancelLocationUpdates() {
        WifiHelper.shared.removeObserver(observer: self)
        self.locationManager?.stopUpdatingLocation()
        self.listener = nil
    }
    
    public func addOpenNetworks(ssid: String) {
        HotspotManager.registerWifi(ssid: ssid)
    }
    
    internal func getDeviceLocation(completion: @escaping ((_ location: CLLocationCoordinate2D?) -> Void)) {
        self.deviceLocationCallback = completion
        self.requestLocationTimoutTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false, block: { Timer in
            if self.deviceLocationCallback != nil {
                self.deviceLocationCallback!(self.location)
                self.deviceLocationCallback = nil
            }
        })
        self.locationManager?.requestLocation()
    }
    
    func wifiDidChange(status: NWPath.Status) {
                
        print("wifi did change: \(status)")
                
        switch status {
            case .satisfied:
                // We received a connect notification
                startLocationSearch()
                
            case .unsatisfied, .requiresConnection:
                // We received a disconnect notification
                wifiChangeLock.lock()
                // Is the app currently not checking a new network connection and do we had a network connection
                if searchNetworkInfo == nil && connectedNetworkInfo != nil {
                    Logger.log("Check disconnect in 5 seconds!")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        self.checkDisconnect()
                    }
                } else if searchNetworkInfo != nil {
                    Logger.log("Skip disconnect check as a location search is running!")
                } else if connectedNetworkInfo == nil {
                    Logger.log("No connected network info!")
                }
                wifiChangeLock.unlock()

            default:
                Logger.log("unknown wifi state")
       }
    }
        
    private func startLocationSearch() {
        
        var startSearch = false
        wifiChangeLock.lock()
        if checkConnectionTimer != nil {
            checkConnectionTimer?.invalidate()
            checkConnectionTimer = nil
        }
        
        // Is the app currently not checking a new network connection, do we have a network connection and has the network connection changed?
        let networkInfo = WifiHelper.shared.getConnectedNetworkInfo()
        if searchNetworkInfo == nil, networkInfo != nil, networkInfo != connectedNetworkInfo {
            // Start checking a new network connection
            Logger.log("start Location Search...")
            startSearch = true
            searchNetworkInfo = networkInfo
        } else if searchNetworkInfo != nil {
            Logger.log("A location search is already running!")
        } else if networkInfo == nil {
            Logger.log("No network connection!")
        } else if networkInfo == connectedNetworkInfo {
            Logger.log("Network \(networkInfo!) already connected!")
        }
        wifiChangeLock.unlock()
        if  startSearch {
            getCurrentLocation(completion: {location, error in
                if location != nil {
                    self.listener?.onUpdate(location: location, error: error)
                } else if let error = error {
                    self.listener?.onUpdate(location: location, error: error)
                }
                self.wifiChangeLock.lock()
                if let networkInfo = WifiHelper.shared.getConnectedNetworkInfo(), networkInfo == self.searchNetworkInfo {
                    Logger.log("New connection:\(self.searchNetworkInfo!)")
                    self.connectedNetworkInfo = self.searchNetworkInfo;
                    self.searchNetworkInfo = nil
                } else if networkInfo == nil {
                    Logger.log("Check disconnect in 5 seconds!")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        self.checkDisconnect()
                    }
                } else if self.searchNetworkInfo != nil {
                    Logger.log("Checked network \(self.searchNetworkInfo!), but now \(networkInfo!)!")
                    self.searchNetworkInfo = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.startLocationSearch()
                    }
                }
                self.wifiChangeLock.unlock()
                Logger.log("Location Search finished!")
            })
        }
    }

    private func checkDisconnect() {
        self.wifiChangeLock.lock()
        Logger.log("Check disconnect status...")
        // Are we not currently checking a network connection and had been connected to a network?
        if searchNetworkInfo == nil, connectedNetworkInfo != nil {
            // Do we currently have a network connection?
            if WifiHelper.shared.getConnectedNetworkInfo() == nil {
                // Ok > disconnect
                Logger.log("Disconnect from \(connectedNetworkInfo!)!")
                self.resetCache()
                self.connectedNetworkInfo = nil
            } else {
                // Still connected to a network
                Logger.log("Connected to \(connectedNetworkInfo!)!")
            }
        } else if searchNetworkInfo != nil {
            Logger.log("Skip disconnect check as a location search is running!")
        } else if connectedNetworkInfo == nil {
            Logger.log("No connected network info!")
        }
        self.wifiChangeLock.unlock()
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

        requestLocationTimoutTimer?.invalidate()
        requestLocationTimoutTimer = nil
        
        let locValue = manager.location?.coordinate
        if locValue != nil {
            location = locValue
        }
        
        if self.deviceLocationCallback != nil {
            self.deviceLocationCallback!(locValue)
            self.deviceLocationCallback = nil
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
         print("error:: \(error.localizedDescription)")

        requestLocationTimoutTimer?.invalidate()
        requestLocationTimoutTimer = nil

        if self.deviceLocationCallback != nil {
            self.deviceLocationCallback!(nil)
            self.deviceLocationCallback = nil
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Logger.log("CLLocationManager didChangeAuthorization \(status)")
        if self.locationAuthorizationRequested {
            self.locationAuthorizationRequested = false
            NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.checkLocationAuthorization()
            }
        }
    }
    
    public func getCurrentLocation(completion: @escaping (_ ap: HiWifiLocation?, _ error: HiWifiError?) -> Void) {
        
        Logger.log("get current location...")
        let error = checkSettings()
        
        guard error == nil else {
            completion(nil, error)
            return
        }
        
        Logger.log("get current location...settings ok")
        
        HiWifiLocationService(service: self).getWifiLocation(completion: { hiWifiLocation, error in
            completion(hiWifiLocation, error)
        })
        
    }
    
    private func checkSettings() -> HiWifiError? {
        
        guard CLLocationManager.locationServicesEnabled() else {
            return .LocationNotEnabled
        }
        
        guard locationPermissionGranted else {
            return .NoLocationPermission
        }
        
        guard WifiHelper.shared.isConnectedToWifi() else {
            return .WifiNotConnected
        }
        
        return nil
    }
    
    public func onReceive(notification: UNNotification) {
        NotificationHelper.shared.onClick(notification: notification)
    }
    
    private func getSSIDs(completion: @escaping (_ success: Bool) -> Void) {
        Logger.log("loading ssid list...")
        self.ssidList = CoreDataManager.shared.fetchSSIDList()
        
        if NetworkHelper.isConnectedToNetwork() {
            SSIDFetcher().execute(completion: { success in
                Logger.log("SSID List fetched success: \(success)")
                self.ssidList = CoreDataManager.shared.fetchSSIDList()
                completion(success)
            })
        }
    
    }
    
    private func resetCache() {
        CoreDataManager.shared.deleteAccessPoints()
        NotificationHelper.shared.clearHistory()
    }
    
}

public protocol HiWifiLocationListener {
    func onUpdate(location: HiWifiLocation?, error: HiWifiError?)
}

public protocol HiWifiPushInterface {
    func onReceive(notification: UNNotification)
}

public enum HiWifiError {
    case NoLocationPermission, LocationNotEnabled, WifiNotConnected, LocationNotFound
}
