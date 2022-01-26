//
//  HiWifiLocationService.swift
//  HiWifiCore
//
//  Created by Reinhard Dietzel on 23.03.21.
//

import Foundation
import CoreLocation

internal class HiWifiLocationService {

    private var ssidList = CoreDataManager.shared.fetchSSIDList()
    private var service: HiWifiService
    
    init(service: HiWifiService) {
        self.service = service
    }
    
    public func getWifiLocation(completion: @escaping (_ ap: HiWifiLocation?, _ error: HiWifiError?) -> Void) {
                
        let networkInfo = WifiHelper.shared.getConnectedNetworkInfo()
                
        if let networkInfo = networkInfo {
            
            guard isKnownSSID(networkInfo.ssid) else {
                completion(nil, .LocationNotFound)
                return
            }
            
            getLocationFor(bssid: networkInfo.bssid, ssid: networkInfo.ssid, completion: {ap in
                
                if let ap = ap {
                
                    Logger.log("Location Search...found AP with bssid: \(ap.bssid0 ?? "n/a")")
                    completion(ap.toHiWifiLocation(), nil)


                } else {
                    completion(nil, .LocationNotFound)
                }
                
            })
                        
        } else {
            completion(nil, .LocationNotFound)
        }
        
    }
    
    private func isKnownSSID(_ ssid: String, _ includeSSIDList: Bool = true) -> Bool {
        return ssidList.isEmpty || self.ssidList.contains(ssid)
    }
    
    private func getLocationFor(bssid: String, ssid: String, newGroup: Bool = false, completion: @escaping (_ accessPointObject: AccessPointObject?) -> Void) {
        
        let ap = CoreDataManager.shared.fetchAccessPointBy(bssid: bssid)
        
        if let ap = ap {
            
            if newGroup && HiWifiService.pushEnabled {
                NotificationHelper.shared.scheduleNotification(ap)
            }
            completion(ap)
            
        } else if NetworkHelper.isConnectedToNetwork() {
            
            self.service.getDeviceLocation(completion: { location in
                
                if location == nil {
                    Logger.log("getDeviceLocation failed!")
                    completion(nil)
                } else {
                    AccessPointFetcher(bssid: bssid, ssid: ssid, latitude: location!.latitude.description, longitude: location!.longitude.description).execute(completion: { success in
                                        
                        Logger.log("Ap not found in cache...call api")
                        if success {
                            Logger.log("Api request successfull")
                            self.getLocationFor(bssid: bssid, ssid: ssid, newGroup: true, completion: completion)
                        } else {
                            Logger.log("Api request failed")
                            completion(nil)
                        }
                    })
                }
            })
        } else {
            completion(nil)
        }
    }
}
