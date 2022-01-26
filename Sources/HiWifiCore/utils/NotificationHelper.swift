//
//  NotificationHelper.swift
//  hiwificore
//
//  Created by Alex on 26.08.20.
//  Copyright © 2020 INT. WIFI Connect GmbH. All rights reserved.
//

import Foundation
import UserNotifications

internal class NotificationItem {
    var date: Date = Date()
    var pushtitle: String?
    var pushtext: String?
    var urlinfo: String?
}

internal class NotificationHelper : NSObject, UNUserNotificationCenterDelegate {
    
    internal static let shared = NotificationHelper()
    
    internal var notificationHistory: [NotificationItem] = []
    
    func clearHistory() {
        notificationHistory = []
    }
    
    internal func scheduleNotification(_ ap: AccessPointObject) {
        
        // Check for the same notification data in the history!
        var notificationItem = notificationHistory.first { item in
            if item.pushtitle == ap.pushtitle, item.pushtext == ap.pushtext, item.urlinfo == ap.urlinfo {
                return true
            }
            return false
        }
        if notificationItem != nil {
            // This notification data was shown before
            let now = Date()
            let beforeTwoHours = now.addingTimeInterval(-60 * 60 * 2)
            if beforeTwoHours < notificationItem!.date {
                // This notification data was shown within the last two hours so we don't show it again
                notificationItem!.date = now
                return
            }
            // Update the date
            notificationItem!.date = now
        } else {
            // Add a new notification info for this notification data
            notificationItem = NotificationItem()
            notificationItem!.pushtitle = ap.pushtitle
            notificationItem!.pushtext = ap.pushtext
            notificationItem!.urlinfo = ap.urlinfo
            notificationHistory.append(notificationItem!)
        }
        
        let pushTitle = ap.pushtitle ?? ""
        let pushText = ap.pushtext ?? ""
        let pushBody = ap.urlinfo ?? ""
        
        let content = UNMutableNotificationContent()
        content.title = pushTitle
        content.subtitle = pushText
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = "hiwifi_" + pushBody
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.01, repeats: false)
        let request = UNNotificationRequest(identifier: "com.hiwifipro.apps.core", content: content, trigger: trigger)
                
        UNUserNotificationCenter.current().add(request)
    }
    
    internal func onClick(notification: UNNotification) {
        
        let targetInfo: String = notification.request.content.categoryIdentifier
        let pushUrl = targetInfo.removePrefix("hiwifi_")
        pushUrl.openUrl()
    }
}
