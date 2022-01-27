//
//  SSIDFetcher.swift
//  hiwificore
//
//  Created by Alex on 17.09.20.
//  Copyright © 2020 INT. WIFI Connect GmbH. All rights reserved.
//

import Foundation
import MessageUI

internal class SSIDFetcher {
    
    internal func execute(completion: @escaping (_ success: Bool) -> Void) {
                
        URLCache.shared.removeAllCachedResponses()
        
        guard NetworkHelper.isConnectedToNetwork() else {
            completion(false)
            return
        }
        
        guard let url = URL(string: SERVICE_URL_PROD + SERVICE_ACTION_GETSSIDS) else {
            completion(false)
            return
        }

        let fetchPasswords = HiWifiService.usePasswordManager
        let hiwifiCoreVersion = Logger.shared.appVersion
        let jsonDict: [String:Any] = ["type":"getssids",
                                      "token":"aAaJ5ScYZeKHNKs8cftwUJgXpQaw5s4X",
                                      "application_uid": HiWifiService.application_uid,
                                      "country_code":Locale.current.languageCode!,
                                      "os":"ios",
                                      "os_version": UIDevice.current.systemVersion,
                                      "app_version": hiwifiCoreVersion,
                                      "password": fetchPasswords]
        
        
        let jsonData = try! JSONSerialization.data(withJSONObject: jsonDict, options: [])
        
        var request = URLRequest(url: url)
        request.httpMethod = "post"
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
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
    
}
