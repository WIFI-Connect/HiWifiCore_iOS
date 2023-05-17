//
//  SSIDFetcher.swift
//  hiwificore
//
//  Created by Alex on 17.09.20.
//  Copyright © 2020 INT. WIFI Connect GmbH. All rights reserved.
//

import Foundation
import MessageUI
import CoreLocation

internal class SSIDFetcher {

  internal func execute(completion: @escaping (_ success: Bool) -> Void) {
              
    guard NetworkHelper.isConnectedToNetwork() else {
        completion(false)
        return
    }
  
    if HiWifiService.application_uid == "HiWifiMode" {
      // Get the current location
      LocationManager.shared.getLocation { location, error in
        if error != nil || location == nil {
          completion(false)
          return
        }
        self.fetchHiWifiData(completion: completion, location: location)
      }
    } else {
      fetchData(completion: completion)
    }
  }
  
  internal func fetchData(completion: @escaping (_ success: Bool) -> Void) {
    guard let url = URL(string: SERVICE_URL_PROD + SERVICE_ACTION_GETSSIDS) else {
        completion(false)
        return
    }

    let fetchPasswords = HiWifiService.usePasswordManager
    let jsonDict: [String:Any] = ["token":"aAaJ5ScYZeKHNKs8cftwUJgXpQaw5s4X",
                                  "app_uid": HiWifiService.application_uid,
                                  "password": fetchPasswords]
    
    
    let jsonData = try! JSONSerialization.data(withJSONObject: jsonDict, options: [])
    
    var request = URLRequest(url: url)
    request.httpMethod = "post"
    request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
    request.httpBody = jsonData
    
  URLCache.shared.removeAllCachedResponses()
    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
        
        guard let dataResponse = data, error == nil else {
            completion(false)
            return
        }
        
        do {
            
            guard let json = try JSONSerialization.jsonObject(with: dataResponse, options: []) as? [String: AnyObject] else {
                completion(false)
                return
            }
            
            if let status = json["code"] as? String, status == "200" {
                
                if let ssids = json["ssids"] as? [[String:String]] {
                    
                    Logger.log("Fetched ssidlist successful: size = \(ssids.count)")
                    CoreDataManager.shared.saveSSIDList(data: ssids)
                    completion(true)
                    
                } else {
                    completion(false)
                }
                
            } else {
                
                let errorCode = json["code"] as? String ?? "json error"
                Logger.log("result code: \(errorCode)")
                completion(false)
                
            }
            
        } catch let parsingError {
            Logger.log("JSON parse error:\(parsingError)")
            completion(false)
        }
                    
    }
    
    task.resume()
  }

  internal func fetchHiWifiData(completion: @escaping (_ success: Bool) -> Void, location: CLLocation!) {
    guard let url = URL(string: "https://api.hiwifipro.com/HiWifi/v1/GET-SSID") else {
        completion(false)
        return
    }

    let fetchPasswords = HiWifiService.usePasswordManager
    let jsonDict: [String:Any] = ["token":"aAaJ5ScYZeKHNKs8cftwUJgXpQaw5s4X",
                                  "app_uid": "DD1E6-B9C9D-702B4-2E55C-F9935",
                                  "password": fetchPasswords,
                                  "latitude": "\(location.coordinate.latitude)",
                                  "longitude": "\(location.coordinate.longitude)"
    ]
    
    let jsonData = try! JSONSerialization.data(withJSONObject: jsonDict, options: [])
    
    var request = URLRequest(url: url)
    request.httpMethod = "post"
    request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
    request.httpBody = jsonData
    
    URLCache.shared.removeAllCachedResponses()
    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
        
        guard let dataResponse = data, error == nil else {
            completion(false)
            return
        }
        
        do {
            
            guard let json = try JSONSerialization.jsonObject(with: dataResponse, options: []) as? [String: AnyObject] else {
                completion(false)
                return
            }
            
            if let status = json["code"] as? String, status == "200" {
                
                if let ssids = json["ssids"] as? [[String:String]] {
                    
                    Logger.log("Fetched ssidlist successful: size = \(ssids.count)")
                    CoreDataManager.shared.saveSSIDList(data: ssids)
                  
                    if let radiusString = json["radius"] as? String {
                        let radius = Int(radiusString) ?? 0
                        if radius > 0 {
                            HiWifiService.ssidListLocation = location
                            HiWifiService.ssidListRadius = radius
                        } else {
                            HiWifiService.ssidListLocation = nil
                            HiWifiService.ssidListRadius = 0
                        }
                    }
                    completion(true)
                    
                } else {
                    completion(false)
                }
                
            } else {
                
                let errorCode = json["code"] as? String ?? "json error"
                Logger.log("result code: \(errorCode)")
                completion(false)
                
            }
            
        } catch let parsingError {
            Logger.log("JSON parse error:\(parsingError)")
            completion(false)
        }
                    
    }
    
    task.resume()
  }

}
