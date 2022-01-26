//
//  StringExtensions.swift
//  hiwificore
//
//  Created by Alex on 17.09.20.
//  Copyright © 2020 INT. WIFI Connect GmbH. All rights reserved.
//

import Foundation
import UIKit

internal extension String {
    
    func removePrefix(_ prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }
    
    func containsIgnoreCase(_ string : String) -> Bool {
        return self.localizedCaseInsensitiveContains(string)
    }
    
    func trimSSID() -> String {
        return self.trimmingCharacters(in: CharacterSet.init(charactersIn: "\""))
    }
    
    func openUrl() {
        if self.count > 0 {
            var prefix = ""
            var urlString = self
            if urlString.hasPrefix("http://") {
                prefix = "http://"
                urlString = urlString.removePrefix("http://")
            } else if urlString.hasPrefix("https://") {
                prefix = "https://"
                urlString = urlString.removePrefix("https://")
            }
            urlString = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            guard let url = URL(string: prefix + urlString) else {
                return
            }
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else if prefix == "" {
                guard let url = URL(string: "https://" + urlString) else {
                    return
                }
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    mutating func checkLeadingZeros() {
        
        guard self.count > 0 else { return }
        
        let splittedBSSID = self.split(separator: ":")
        var correctBSSID: String = ""
        for bssid in splittedBSSID {
            
            
            var part = bssid
            if(part.count < 2) {
                part = "0" + part
            }
            correctBSSID = correctBSSID + part + ":"
        }
        
        correctBSSID = String(correctBSSID.dropLast())
        self = correctBSSID
    }
    
    func urlEncoded() -> String {
        return self.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
    }
    
    func cleanForLog() -> String {
        var cleanedString = self.replacingOccurrences(of: "'", with: "&sbquo;")
        cleanedString = cleanedString.replacingOccurrences(of: "\"", with: "&quot;")
        return cleanedString
    }
    
    func spaceCleaned() -> String {
        return self.replacingOccurrences(of: " ", with: "%20")
    }
    
    func toDict() -> [String: String]? {
        guard !self.isEmpty else { return nil }
        if let data = self.data(using: .utf8) {
            do {
                return try (JSONSerialization.jsonObject(with: data, options: []) as? [String: String])
            } catch {
                print(error.localizedDescription)
            }
        }
        return nil
    }
}

