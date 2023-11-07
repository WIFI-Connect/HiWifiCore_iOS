//
//  LocationManager.swift
//  HiWifi
//
//  Created by Daniel Schwill on 12.05.22.
//

import Foundation
import CoreLocation

typealias GetLocationCompletionHandler = (CLLocation?, Error?) -> (Void)
typealias RequestAuthorizationCompletionHandler = (CLAuthorizationStatus) -> (Void)

class LocationManager: NSObject, CLLocationManagerDelegate {
  
  static let shared = LocationManager()

  let locationManager = CLLocationManager()
  
  var location: CLLocation?

  let serialQueue = DispatchQueue(label: "Serial Queue") // custom dispatch queues are serial by default
  var getLocationCompleterHandlers: [GetLocationCompletionHandler] = []
  var requestLocationAuthorizationCompleterHandlers: [RequestAuthorizationCompletionHandler] = []
  
  private override init() {
    super.init()
    locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    locationManager.delegate = self
  }

  public func requestLocationAuthorization(_ completionHandler: @escaping RequestAuthorizationCompletionHandler) {
    serialQueue.async {
      var status = CLAuthorizationStatus.notDetermined
      if #available(iOS 14, *) {
        status = CLLocationManager().authorizationStatus
      } else {
        status = CLLocationManager.authorizationStatus()
      }

      if status == .notDetermined {
        self.requestLocationAuthorizationCompleterHandlers.append(completionHandler)
        self.locationManager.requestWhenInUseAuthorization()
      } else {
        DispatchQueue.main.async {
          completionHandler(status)
        }
      }
    }
  }
  
  public func getLocation(_ completionHandler: @escaping GetLocationCompletionHandler) {
    serialQueue.async {
      // If we don't have a location or the location is older than 5 minutes?
#if DEBUG
      let elapsedTime: TimeInterval = 0
#else
      let elapsedTime: TimeInterval = 5 * 60
#endif
      if self.location == nil || Date().timeIntervalSince(self.location!.timestamp) > elapsedTime {
        // Request a new location
        self.getLocationCompleterHandlers.append(completionHandler)
        self.locationManager.requestLocation()
      } else {
        // Use the last location
        DispatchQueue.main.async {
          completionHandler(self.location!, nil)
        }
      }
    }
  }
  
  // MARK: CLLocationManagerDelegate

  public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    if status != .notDetermined {
      serialQueue.async {
        for completionHandler in self.requestLocationAuthorizationCompleterHandlers {
          DispatchQueue.main.async {
            completionHandler(status)
          }
        }
        self.requestLocationAuthorizationCompleterHandlers = []
      }
    }
  }

  public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    // print("locationManager:didUpdateLocations:\(locations)")
    serialQueue.async {
      for location in locations {
        if self.location == nil {
          self.location = location
        } else if location.distance(from: self.location!) >= self.location!.horizontalAccuracy * 0.25 {
          self.location = location
        } else if location.horizontalAccuracy <= self.location!.horizontalAccuracy {
          self.location = location
        }
      }
      if self.location == nil { return }

      for completionHandler in self.getLocationCompleterHandlers {
        DispatchQueue.main.async {
          completionHandler(self.location!, nil)
        }
      }
      self.getLocationCompleterHandlers = []
    }
  }
  
  public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    // print("locationManager:didFailWithError:\(error)")
    serialQueue.async {
      for completionHandler in self.getLocationCompleterHandlers {
        DispatchQueue.main.async {
          completionHandler(nil, error)
        }
      }
      self.getLocationCompleterHandlers = []
    }
  }

}
