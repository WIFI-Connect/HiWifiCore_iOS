//
//  HiWifiLocation.swift
//  HiWifiCore
//
//  Created by Alexander Aries on 24.03.21.
//

import Foundation

public class HiWifiLocation {
    public var bssid: String?
    public var locationInfo: [String:String]?
}

extension AccessPointObject {
    func toHiWifiLocation() -> HiWifiLocation {
        let loc = HiWifiLocation()
        loc.bssid = self.bssid0
        loc.locationInfo = self.info?.toDict()
        return loc
    }
}
