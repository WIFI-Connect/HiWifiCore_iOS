//
//  WifiHelper.swift
//  hiwificore
//
//  Created by Alex on 26.08.20.
//  Copyright © 2020 INT. WIFI Connect GmbH. All rights reserved.
//

import Foundation
import SystemConfiguration.CaptiveNetwork
import Network
import NetworkExtension


internal class WifiHelper {
    
    var test = 1
    
    internal static let shared = WifiHelper()
    
    internal struct WifiChangeObservation {
        weak var observer: WifiObserver?
    }
    
    private var monitor = NWPathMonitor(requiredInterfaceType: .wifi)
    private var observations = [ObjectIdentifier: WifiChangeObservation]()
    private var currentStatus: Network.NWPath.Status {
        get {
            return monitor.currentPath.status
        }
    }
    
    init() {
        monitor.pathUpdateHandler = { [unowned self] path in
            for (id, observations) in self.observations {

                //If any observer is nil, remove it from the list of observers
                guard let observer = observations.observer else {
                    self.observations.removeValue(forKey: id)
                    continue
                }

                DispatchQueue.main.async(execute: {
                    observer.wifiDidChange(status: path.status)
                })
            }
        }
        
    }
    
    func nextTest() {
        test += 1
    }
    
    internal func addObserver(observer: WifiObserver) {
        let id = ObjectIdentifier(observer)
        observations[id] = WifiChangeObservation(observer: observer)
        monitor.start(queue: DispatchQueue.global(qos: .background))
    }

    internal func removeObserver(observer: WifiObserver) {
        let id = ObjectIdentifier(observer)
        observations.removeValue(forKey: id)
    }
    
    internal func isConnectedToWifi() -> Bool {
        return getConnectedSSID() != nil
    }
    
    internal func getConnectedSSID() -> String? {
        
        guard let interfaceNames = CNCopySupportedInterfaces() as? [String] else {
            return nil
        }
        
        return interfaceNames.compactMap { name in
            
            guard let info = CNCopyCurrentNetworkInfo(name as CFString) as? [String: AnyObject] else {
                return nil
            }
            guard let ssid = info[kCNNetworkInfoKeySSID as String] as? String else {
                return nil
            }
            return ssid
            
        }.first
        
    }

    internal func getConnectedNetworkInfo() -> NetworkInfo? {
        
        guard let interfaceNames = CNCopySupportedInterfaces() as? [String] else {
            return nil
        }
        
        return interfaceNames.compactMap { name in
            
            guard let info = CNCopyCurrentNetworkInfo(name as CFString) as? [String: AnyObject] else {
                return nil
            }
            guard let ssid = info[kCNNetworkInfoKeySSID as String] as? String else {
                return nil
            }
            
            guard var bssid = info[kCNNetworkInfoKeyBSSID as String] as? String else {
                return nil
            }
            /* TEST!
            if test == 1 {
                bssid = "9c:71:3a:ec:fa:40"
            } else if test == 2 {
                bssid = "9c:71:3a:ed:0d:a0"
            } else {
                bssid = "c4:ff:1f:77:3e:c0"
            } */
            bssid.checkLeadingZeros()
                        
            return NetworkInfo(ssid: ssid, bssid: bssid)
            
        }.first
        
    }
    
//    internal func getConnectedNetworkInfo14() -> NetworkInfo? {
//
//        NEHotspotNetwork.fetchCurrent { hotspotNetwork in
//            if let ssid = hotspotNetwork?.ssid {
//                return NetworkInfo(ssid: hotspotNetwork?.ssid, bssid: hotspotNetwork?.bssid)
//            }
//        }
//
//    }
    
}

internal struct NetworkInfo : Equatable {
    var ssid: String
    var bssid: String
}

internal protocol WifiObserver: AnyObject {
    func wifiDidChange(status: Network.NWPath.Status)
}
