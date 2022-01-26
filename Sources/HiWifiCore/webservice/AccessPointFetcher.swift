//
//  AccessPointFetcher.swift
//  hiwificore
//
//  Created by Alex on 24.08.20.
//  Copyright © 2020 INT. WIFI Connect GmbH. All rights reserved.
//

import Foundation
import CoreLocation
import CoreData
import MessageUI

internal class AccessPointFetcher {
    
    private let bssid: String
    private let ssid: String
    private let latitude: String
    private let longitude: String
    private var urlInfo: String
    private var retry: Int64 = 0

    init(bssid: String, ssid: String, latitude: String, longitude: String) {
        self.bssid = bssid
        self.ssid = ssid
        self.latitude = latitude
        self.longitude = longitude
        
        urlInfo = SERVICE_ACTION_GETPUSHTEXT
        
    }
    
    internal func execute(completion: @escaping (_ success: Bool) -> Void) {
                
        Logger.log("AccessPointFetcher für bssid: \(bssid) und ssid: \(ssid)...")
        URLCache.shared.removeAllCachedResponses()
        
        guard NetworkHelper.isConnectedToNetwork() else {
            completion(false)
            return
        }
        
        guard let url = URL(string: SERVICE_URL_PROD + SERVICE_ACTION_GETPUSHTEXT) else {
            completion(false)
            return
        }
        
        let array: [String] = []
        let hiwifiCoreVersion = Logger.shared.appVersion
        let jsonDict: [String:Any] = ["type": "WELCOME",
                                      "language": Locale.current.languageCode!,
                                      "connected_access_point":bssid,
                                      "ssid":ssid,
                                      "latitude":latitude,
                                      "longitude":longitude,
                                      "near_access_points":array,
                                      "os":"ios",
                                      "os_version":UIDevice.current.systemVersion,
                                      "app_version": hiwifiCoreVersion,
                                      "token":"aAaJ5ScYZeKHNKs8cftwUJgXpQaw5s4X",
                                      "application_uid": HiWifiService.application_uid]
        
        let jsonData = try! JSONSerialization.data(withJSONObject: jsonDict, options: [])
        
        var request = URLRequest(url: url)
        request.httpMethod = "post"
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request) { ( data, response, error) in
            
            guard let dataResponse = data, error == nil else {
                if error != nil {
                    if self.retry < 3 {
                        self.retry += 1
                        Logger.log("Retry after error (\(self.retry))")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.execute(completion: completion)
                        }
                    } else {
                        completion(false)
                    }
                } else {
                    completion(false)
                }
                return
            }
            
            do {
                
                Logger.log("AccessPointFetcher response: \(String(data: dataResponse, encoding: .utf8) ?? "") ")
                guard let json = try JSONSerialization.jsonObject(with: dataResponse, options: []) as? [String: AnyObject] else { return }
                
                if let status = json["code"] as? String, status == "200" {
                    
                    if let wlans = json["wlans"] as? [[String:Any]] {

                        CoreDataManager.shared.saveAccessPoints(data: wlans)
                        completion(true)
                        
                    }
                    
                } else {
                    
                    completion(false)
                    
                }
                
            } catch {
                completion(false)
            }
        }
        
        task.resume()
        
    }
    
}
