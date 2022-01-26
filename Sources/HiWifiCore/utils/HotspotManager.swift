//
//  HotspotManager.swift
//  HiWifi
//
//  Created by Alexander Aries on 04.02.21.
//

import Foundation
import NetworkExtension
#if SWIFT_PACKAGE
import HiWifiCoreCrypto
#endif

class HotspotManager {
    
    static let sharedSSIDs = CoreDataManager.shared.getSharedSSIDs()
        
    class func registerWifi(ssid: String) {
        
        #if DEBUG
        let hotspotConfig1 = NEHotspotConfiguration(ssid: ssid, passphrase: "Testing202!", isWEP: false)
        #else
        let hotspotConfig1 = NEHotspotConfiguration(ssid: ssid)
        #endif
        
        NEHotspotConfigurationManager.shared.apply(hotspotConfig1, completionHandler: { error in
            if let error = error {
                Logger.log(error.localizedDescription)
            }
        })
        
    }
    
    class func registerWifi(ssid: String, password: String) {
        
        let hotspotConfig1 = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: false)
        
        NEHotspotConfigurationManager.shared.apply(hotspotConfig1, completionHandler: { error in
            if let error = error {
                Logger.log(error.localizedDescription)
            }
        })
        
    }
    
    class func isDebugging(network: NEHotspotNetwork) -> Bool {

        var bssid = network.bssid
        bssid.checkLeadingZeros()

        return bssid == "82:ce:b7:0f:bc:8c" // false //(bssid == "2e:91:ab:09:ab:73") || (bssid == "e2:28:6d:4b:d0:61") || (bssid == "e2:28:6d:4b:d0:60")

        /*
         2e:91:ab:09:ab:73
         e2:28:6d:4b:d0:61
         e2:28:6d:4b:d0:60
         */

    }
        
    class func registerLoginCallback() {
        
        let options: [String: NSObject] = [kNEHotspotHelperOptionDisplayName : "Velmart Netzwork" as NSObject]
        let queue: DispatchQueue = DispatchQueue(label: "WIFI-Connect-GmbH.HiWifi", attributes: DispatchQueue.Attributes.concurrent)

        Logger.log("Register hotspot helper...")

        let success = NEHotspotHelper.register(options: options, queue: queue) { (cmd: NEHotspotHelperCommand) in
            
            Logger.log("Received command: \(cmd.commandType.rawValue)")
            
            switch (cmd.commandType) {
                
            case .filterScanList:
                    
                let list: [NEHotspotNetwork] = cmd.networkList!
                
                let desiredNetwork : [NEHotspotNetwork]? = getKnownScanResults(list)
                Logger.log("Found \(String(describing: desiredNetwork?.count)) known networks")
                if let network = desiredNetwork {
                
                    network.forEach { n in
                        if isDebugging(network: n) {
                            
                            print("Use password for test netzwork!")
                            n.setPassword("Testing202!")
                            
                        } else if let ssidObject = n.isSharedNetwork {
                            
                            let pw = ssidObject.password
                            if pw != nil, pw != "OPEN" {
#if SWIFT_PACKAGE
                                if let decryptPw = try? HiWfiCrypto().decrypt(string: pw!) {
                                    n.setPassword(decryptPw)
                                }
#endif
                            }
                        }
                    }
                    
                    //Respond back with the filtered list
                    let response = cmd.createResponse(NEHotspotHelperResult.success)
                    response.setNetworkList(network)
                    response.deliver()
                    
                }
                
            case .evaluate, .presentUI:
                    
                if let network = cmd.network {
                    
                    Logger.log("Evaluate: network = \(network.ssid)")

                    if(network.isSharedNetwork != nil) {
                        
                        //Set high confidence for the network
                        network.setConfidence(NEHotspotHelperConfidence.high)
                        
                        let response = cmd.createResponse(NEHotspotHelperResult.success)
                        response.setNetwork(network)
                        response.deliver() //Respond back
                    
                    } else {
                        let response = cmd.createResponse(NEHotspotHelperResult.unsupportedNetwork)
                        response.deliver()
                    }
                }
                
            case .authenticate, .maintain:
                    
                if let network = cmd.network {
                    Logger.log("Connected with \(network.ssid)....authenticate")
                                        
                    if network.isSharedNetwork != nil {
                        let response = cmd.createResponse(.success)
                        response.setNetwork(network)
                        response.deliver()
                    }
                    else {
                        
                        let response = cmd.createResponse(NEHotspotHelperResult.unsupportedNetwork)
                        response.deliver()
                        
                    }
                }
            case .none, .logoff:
                let response = cmd.createResponse(.success)
                response.deliver()
            @unknown default:
                Logger.log("unknown hotspothelper command")
            }
            
        }
        
        Logger.log("Register hotspot helper...success = \(success)")
        
    }
        
    private class func getKnownScanResults(_ list: [NEHotspotNetwork]) -> [NEHotspotNetwork]? {
        
        var networkArray: [NEHotspotNetwork] = []
                
        for hp in list {

            if(hp.isSharedNetwork != nil) { networkArray.append(hp)  }

        }
        if (networkArray.count > 0) {
            return networkArray
        } else {
            return nil
        }
    }
    
}

extension NEHotspotNetwork {
    var isSharedNetwork: SSIDObject? {
        get {
            for ssidObject in HotspotManager.sharedSSIDs {
                if ssidObject.ssid_name == self.ssid {
                    return ssidObject
                }
            }
            return nil
        }
    }
}
