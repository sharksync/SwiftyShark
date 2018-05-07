//    MIT License
//
//    Copyright (c) 2016 SharkSync
//
//    Permission is hereby granted, free of charge, to any person obtaining a copy
//    of this software and associated documentation files (the "Software"), to deal
//    in the Software without restriction, including without limitation the rights
//    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//    copies of the Software, and to permit persons to whom the Software is
//    furnished to do so, subject to the following conditions:
//
//    The above copyright notice and this permission notice shall be included in all
//    copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//    SOFTWARE.

import Foundation
import SharkORM.Private

class SyncRequest {
    
    var changes: [SharkSyncChange] = []
    var groups: [SRKSyncGroup] = []
    
    func requestObject() -> [String: Any] {
        
        var requestData: [String: Any] = [:]
        
        // embed the current session information
        requestData["app_id"] = SharkSync.sharedObject().applicationKey
        requestData["device_id"] = SharkSync.sharedObject().deviceId
        requestData["app_api_access_key"] = SharkSync.sharedObject().accountKeyKey
        
        // debug/testing
        requestData["device_id"] = "9e4ac6a5-aac3-4362-b530-0be53a9e6619"
        
        // pull out a reasonable amount of writes to be sent to the server
        let changeResults = (SharkSyncChange.query().limit(100).order(by: "timestamp").fetch()) as! [SharkSyncChange]
        self.changes = changeResults
        
        // now add in the changes, and the tidemarks
        var changes: [[String:Any]] = []
        
        for change: SharkSyncChange in changeResults {
            let secondsAgo = Date().timeIntervalSince1970 - change.timestamp
            changes.append(["path": change.path ?? "",
                            "value": change.value ?? "",
                            "secondsAgo": secondsAgo,
                            "group": change.recordGroup ?? "",
                            "operation": change.action]
            )
        }
        
        requestData["changes"] = changes
        
        // now select out the data groups to poll for, oldest first
        let groupResults = SRKSyncGroup.query().limit(100).order(by: "last_polled").fetch() as! [SRKSyncGroup]
        self.groups = groupResults
        var groups: [[String:Any]] = []
        for group: SRKSyncGroup in groupResults {
            groups.append(["group": group.groupName ?? "", "tidemark": group.tidemark_uuid ?? NSNull()])
        }
        requestData["groups"] = groups
        return requestData
    }
    
    func requestResponded(_ response: [String: Any], changes: [SharkSyncChange]) {
        
        /* clear down the transmitted data, as we know it arrived okay */
        self.changes.removeAll()
        
        // check for success/error
        if !((response["Success"] as? Bool) ?? false) {
            // there was an error from the service, so we need to bail at this point
            return
        }
        
        // remove the outbound items
        for change in changes {
            change.remove()
        }
        
        /* now work through the response */
        for group in (response["Groups"] as? [[String:Any]]) ?? [] {
            
            let groupName = group["Group"] as! String
            let tidemark = group["Tidemark"] as! String
            
            // now pull out the changes for this group
            for change in (group["Changes"] as? [[String:Any]]) ?? [] {
                
                let path = (change["Path"] as? String ?? "//").components(separatedBy: "/")
                let value = change["Value"] as? String ?? ""
                let record_id = path[0]
                let class_name = path[1]
                let property = path[2]
                
                // process this change
                if property.contains("__delete__") {
                    
                    /* just delete the record and add an entry into the destroyed table to prevent late arrivals from breaking things */
                    let deadObject = SRKSyncObject.object(fromClass: class_name, withPrimaryKey: record_id) as? SRKSyncObject
                    if deadObject != nil {
                        deadObject?.__removeRawNoSync()
                    }
                    let defObj = SRKDefunctObject()
                    defObj.defunctId = record_id
                    defObj.commit()
                    
                } else {
                    
                    // deal with an insert/update
                    
                    // existing object, uopdate the value
                    var decryptedValue = SharkSync.decryptValue(value)
                    
                    let targetObject = SRKSyncObject.object(fromClass: class_name, withPrimaryKey: record_id) as? SRKSyncObject
                    if targetObject != nil {
                        
                        // check to see if this property is actually in the class, if not, store it for a future schema
                        for fieldName: String in targetObject!.fieldNames() as! [String] {
                            if (fieldName == property) {
                                targetObject?.setField(property, value: decryptedValue as! NSObject)
                                if targetObject?.getRecordGroup() == nil {
                                    targetObject?.setRecordVisibilityGroup(groupName)
                                }
                                if targetObject?.__commitRaw(withObjectChainNoSync: nil) != nil {
                                    decryptedValue = nil
                                }
                            }
                        }
                        
                        if decryptedValue != nil {
                            
                            // cache this object for a future instance of the schema, when this field exists
                            let deferredChange = SRKDeferredChange()
                            deferredChange.key = record_id
                            deferredChange.className = class_name
                            deferredChange.value = value
                            deferredChange.property = property
                            deferredChange.commit()
                            
                        }
                        
                    }
                    else {
                        if SRKDefunctObject.query().where(withFormat: "defunctId = %@", withParameters: [record_id]).count() > 0 {
                            // defunct object, do nothing
                        }
                        else {
                            // not previously defunct, but new key found, so create an object and set the value
                            let targetObject = SRKSyncObject.object(fromClass: class_name) as? SRKSyncObject
                            if targetObject != nil {
                                
                                targetObject!.id = record_id
                                
                                // check to see if this property is actually in the class, if not, store it for a future schema
                                for fieldName: String in targetObject!.fieldNames() as! [String] {
                                    if (fieldName == property) {
                                        targetObject!.setField(property, value: decryptedValue as! NSObject)
                                        if targetObject?.getRecordGroup() == nil {
                                            targetObject?.setRecordVisibilityGroup(groupName)
                                        }
                                        if targetObject!.__commitRaw(withObjectChainNoSync: nil) {
                                            decryptedValue = nil
                                        }
                                    }
                                }
                                if decryptedValue != nil {
                                    // cache this object for a future instance of the schema, when this field exists
                                    let deferredChange = SRKDeferredChange()
                                    deferredChange.key = record_id
                                    deferredChange.className = class_name
                                    deferredChange.value = value
                                    deferredChange.property = property
                                    deferredChange.commit()
                                }
                            }
                        }
                    }
                    
                }
                
            }
            
            // now update the group tidemark so as to not receive this data again
            let grp = SRKSyncGroup.groupWithEncodedName(groupName)
            if grp != nil {
                grp!.tidemark_uuid = tidemark
                grp!.last_polled = NSNumber(value: Date().timeIntervalSince1970)
                grp!.commit()
            }
            
        }
    }
    
}
