//
//  CoreDataManager.swift
//  hiwificore
//
//  Created by Alex on 24.08.20.
//  Copyright © 2020 INT. WIFI Connect GmbH. All rights reserved.
//

import Foundation
import CoreData

internal class CoreDataManager {
    
    internal static let shared = CoreDataManager()
    
    private let model: String = "HiWifi"
    
    private lazy var persistentContainer: NSPersistentContainer = {

#if SWIFT_PACKAGE
        let modelURL = Bundle.module.url(forResource: self.model, withExtension: "momd")!
#else
        let modelURL = Bundle.main.url(forResource: self.model, withExtension: "momd")!
#endif
        let managedObjectModel =  NSManagedObjectModel(contentsOf: modelURL)
            
        let container = NSPersistentContainer(name: self.model, managedObjectModel: managedObjectModel!)
        container.loadPersistentStores { (storeDescription, error) in
            if let err = error {
                fatalError("Loading of store failed:\(err)")
            }
        }
        return container
    }()
    
    internal func saveAccessPoints(data: [[String:Any]]) {
        
        NSLog("save accesspoints ...")
        deleteAccessPoints()
        
        let privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateContext.parent = persistentContainer.viewContext

        for ap in data {

            var accessPointInfo: AccessPointObject? = nil
            privateContext.performAndWait {
                accessPointInfo = NSEntityDescription.insertNewObject(forEntityName: "AccessPointObject", into: privateContext) as? AccessPointObject
            }
            if accessPointInfo != nil {
                accessPointInfo!.setValue(ap["ssid_name"] ?? "", forKeyPath: "ssid_name")
                accessPointInfo!.setValue(ap["pushtitle"] ?? "", forKeyPath: "pushtitle")
                accessPointInfo!.setValue(ap["pushtext"] ?? "", forKeyPath: "pushtext")
                accessPointInfo!.setValue(ap["bssid0"] ?? "", forKeyPath: "bssid0")
                accessPointInfo!.setValue(ap["bssid1"] ?? "", forKeyPath: "bssid1")
                accessPointInfo!.setValue(ap["urlinfo"] ?? "", forKeyPath: "urlinfo")
                accessPointInfo!.setValue((ap["info"] as? [String:String])?.toJsonString() ?? "", forKey: "info")
                
                privateContext.performAndWait {
                    do {
                        try privateContext.save()
                    } catch let error {
                        Logger.log("Error saving APs: \(error)")
                    }
                }
            } else {
                Logger.log("Could not create a new AccessPointObject in contect:\(privateContext)")
            }
        }
        persistentContainer.viewContext.performAndWait {
            do {
                try persistentContainer.viewContext.save()
            } catch let error {
                Logger.log("Save context error:\(error)")
            }
        }
    }
    
    internal func saveSSIDList(data: [[String:String]]) {
        
        NSLog("save ssid list ...")

        deleteSSIDList()
        
        guard data.count > 0 else { return }
        let privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateContext.parent = persistentContainer.viewContext
        
        for ssid in data {
            
            if let ssidName = ssid["ssid_name"] {
                var ssidInfo: SSIDObject? = nil
                privateContext.performAndWait {
                    ssidInfo = NSEntityDescription.insertNewObject(forEntityName: "SSIDObject", into: privateContext) as? SSIDObject
                }
                if ssidInfo != nil {
                    ssidInfo!.setValue(ssidName.trimSSID(), forKeyPath: "ssid_name")
                    
                    if let pw = ssid["password"] {
                        ssidInfo!.setValue(pw, forKeyPath: "password")
                    }

                    privateContext.performAndWait {
                        do {
                            try privateContext.save()
                        } catch let error {
                            Logger.log("Error saving APs: \(error)")
                        }
                    }
                } else {
                    Logger.log("Could not create a new SSIDObject in contect:\(privateContext)")
                }
            }
        }
        persistentContainer.viewContext.performAndWait {
            do {
                try persistentContainer.viewContext.save()
            } catch let error {
                Logger.log("Save context error:\(error)")
            }
        }
        NSLog("save ssid list successful")
    }
    
    internal func fetchSSIDList() -> [String] {
        
        NSLog("fetch ssid list...")
        let context = persistentContainer.viewContext
        
        let fetchRequest = NSFetchRequest<SSIDObject>(entityName: "SSIDObject")
        
        do {
            
            let ssids = try context.fetch(fetchRequest)
            
            var ssidList: [String] = []
            for ssid in ssids {
                
                if let ssidName = ssid.ssid_name {
                    ssidList.append(ssidName)
                }
                
            }
            
            NSLog("fetch ssid list successful")
            return ssidList
            
        } catch let fetchErr {
            Logger.log("Failed to fetch SSIDs: \(fetchErr.localizedDescription)")
            return []
        }
    }
    
    internal func fetchAccessPoints() -> [AccessPointObject]? {
        
        let context = persistentContainer.viewContext
        
        let fetchRequest = NSFetchRequest<AccessPointObject>(entityName: "AccessPointObject")
        
        do{
            
            let aps = try context.fetch(fetchRequest)
            
            return aps
            
        } catch let fetchErr {
            Logger.log("Failed to fetch APs: \(fetchErr.localizedDescription)")
            return nil
        }
    }
    
    internal func getSharedSSIDs() -> [SSIDObject] {
        
        let context = persistentContainer.viewContext
        
        let fetchRequest = NSFetchRequest<SSIDObject>(entityName: "SSIDObject")
        fetchRequest.predicate = NSPredicate(format: "password != nil AND password != %@", "")

        
        do {
            
            let sharedSSIDs = try context.fetch(fetchRequest)
            
            
            NSLog("fetch sharedSSIDs list successful")
            return sharedSSIDs
            
        } catch let fetchErr {
            Logger.log("Failed to fetch sharedSSIDs: \(fetchErr.localizedDescription)")
            return []
        }
        
    }
    
    internal func fetchAccessPointBy(bssid: String) -> AccessPointObject? {
        
        let context = persistentContainer.viewContext
         
        let fetchRequest = NSFetchRequest<AccessPointObject>(entityName: "AccessPointObject")
        fetchRequest.predicate = NSPredicate(format: "bssid0 = %@ OR bssid1 = %@", bssid, bssid)
        
        do {
            
            let ap = try context.fetch(fetchRequest)
            return ap.first
            
        } catch let fetchErr {
            Logger.log("Failed to fetch AP by bssid, error = \(fetchErr.localizedDescription)")
            return nil
        }
        
    }
    
    internal func deleteAccessPoints() {
        delete(entityName: "AccessPointObject")
    }
    
    private func deleteSSIDList() {
        delete(entityName: "SSIDObject")
    }
    
    private func delete(entityName: String) {

        let privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateContext.parent = persistentContainer.viewContext

        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        privateContext.performAndWait {
            do {
                let objects = try privateContext.fetch(fetchRequest)
                for object in objects {
                    privateContext.delete(object)
                }
                try privateContext.save()
            } catch let error {
                Logger.log("Save context error:\(error)")
            }
        }
        persistentContainer.viewContext.performAndWait {
            do {
                try persistentContainer.viewContext.save()
            } catch let error {
                Logger.log("Save context error:\(error)")
            }
        }
    }

    
    private func deteteMessageInfos() {
        delete(entityName: "MessageObject")
    }
    
}
extension Dictionary {
    func toJsonString() -> String {
        return String(data: try! JSONSerialization.data(withJSONObject: self, options: []), encoding: .ascii) ?? ""
    }
}
