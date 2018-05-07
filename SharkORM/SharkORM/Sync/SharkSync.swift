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

import AppKit
import CommonCrypto
import UIKit

#if TARGET_OS_IPHONE
typealias XXImage = UIImage
#else
typealias XXImage = NSImage
#endif
enum SharkSyncOperation : Int {
    case create = 1
    // a new object has been created
    case set = 2
    // a value(s) have been set
    case delete = 3
    // object has been removed from the store
    case increment = 4
    // value has been incremented - future implementation
    case decrement = 5
}


class SharkSync {
    var concurrentRecordGroups = [AnyHashable: Any]()

    class func initService(withApplicationId application_key: String?, apiKey account_key: String?) {
            /* get the options object */
        var options = SRKSyncOptions.query().limit(1).fetch().first as? SRKSyncOptions
        if options == nil {
            options = SRKSyncOptions()
            options?.device_id = UUID().uuidString.lowercased()
            options?.commit()
        }
        let sync = SharkSync.sharedObject()
        sync.applicationKey = application_key
        sync.accountKeyKey = account_key
        sync.deviceId = options?.device_id
        sync.settings = SharkSyncSettings()
    }

    class func setSyncSettings(_ settings: SharkSyncSettings?) {
        SharkSync.setSyncSettings(settings)
    }

    class func startSynchronisation() {
        SyncService.start()
    }

    class func synchroniseNow() {
        SyncService.synchroniseNow()
    }

    class func stopSynchronisation() {
        SyncService.stop()
    }

    class func sharedObject() -> SharkSync {
        var this: Any? = nil
        if this == nil {
            this = SharkSync()
            (this as? SharkSync)?.concurrentRecordGroups = [AnyHashable: Any]()
        }
        return this as? SharkSync ?? 0
    }

    class func md5(from inVar: String?) -> String? {
        let pointer = Int8(inVar?.utf8CString ?? 0)
        let md5Buffer = [UInt8](repeating: 0, count: CC_MD5_DIGEST_LENGTH)
        CC_MD5(pointer, strlen(pointer) as? CC_LONG, md5Buffer)
        var string = "" /* TODO: .reserveCapacity(CC_MD5_DIGEST_LENGTH * 2) */
        for i in 0..<CC_MD5_DIGEST_LENGTH {
            string += String(format: "%02x", md5Buffer[i])
        }
        return string
    }

    class func addVisibilityGroup(_ visibilityGroup: String?) {
        // adds a visibility group to the table, to be sent with all sync requests.
        // AH originally wanted the groups to be set per class, but i think it's better that a visibility group be across all classes, much good idea for the dev
        if SRKSyncGroup.query().where(withFormat: "groupName = %@", self.md5(from: visibilityGroup))?.limit(1)?.count() == nil {
            let newGroup = SRKSyncGroup()
            newGroup.groupName = self.md5(from: visibilityGroup)
            newGroup.tidemark_uuid = ""
            newGroup.commit()
        }
    }

    class func removeVisibilityGroup(_ visibilityGroup: String?) {
        let vg = self.md5(from: visibilityGroup)
        SRKSyncGroup.query().where(withFormat: "groupName = %@", vg)?.limit(1)?.fetch()?.removeAll()
        // now we need to remove all the records which were part of this visibility group
        for c: SRKSyncRegisteredClass? in SRKSyncRegisteredClass.query().fetch() {
            let sql = "DELETE FROM \(c?.className) WHERE recordVisibilityGroup = '\(vg ?? "")'"
            // TODO: execute against all attached databases
            SharkORM.executeSQL(sql, inDatabase: nil)
        }
    }

    class func getEffectiveRecordGroup() -> String? {
        let lockQueue = DispatchQueue(label: "SharkSync.sharedObject().concurrentRecordGroups")
        lockQueue.sync {
            return SharkSync.sharedObject().concurrentRecordGroups["\(Thread.current)"] as? String
        }
    }

    class func setEffectiveRecorGroup(_ group: String?) {
        SharkSync.sharedObject().concurrentRecordGroups["\(Thread.current)"] = group
    }

    class func clearEffectiveRecordGroup() {
        SharkSync.sharedObject().concurrentRecordGroups.removeValueForKey("\(Thread.current)")
    }

    class func decryptValue(_ value: String?) -> Any? {
        // the problem with base64 is that it can contain "/" chars!
        if value == nil {
            return nil
        }
        if !(value?.contains("/") ?? false) {
            return nil
        }
        let r: NSRange? = (value as NSString?)?.range(of: "/")
        let type = (value as? NSString)?.substring(to: r?.location)
        let data = (value as? NSString)?.substring(from: Int(r?.location ?? 0) + 1)
        var dValue = Data(base64Encoded: data ?? "", options: .ignoreUnknownCharacters)
            // call the block in the sync settings to encrypt the data
        let sync = SharkSync.sharedObject()
        let settings: SharkSyncSettings? = sync.settings
        dValue = settings?.decryptBlock(dValue)
        if (type == "text") {
                // turn the data back to a string
            var sValue: String? = nil
            if let aValue = dValue {
                sValue = String(data: aValue, encoding: .unicode)
            }
            return sValue
        } else if (type == "number") {
                // turn the data back to a string
            var sValue: String? = nil
            if let aValue = dValue {
                sValue = String(data: aValue, encoding: .unicode)
            }
                // now turn the sValue back to it's original value
            let f = NumberFormatter()
            f.numberStyle = .decimal
            return f.number(from: sValue ?? "")
        } else if (type == "date") {
                // turn the data back to a string
            var sValue: String? = nil
            if let aValue = dValue {
                sValue = String(data: aValue, encoding: .unicode)
            }
                // now turn the sValue back to it's original value
            let f = NumberFormatter()
            f.numberStyle = .decimal
            return Date(timeIntervalSince1970: TimeInterval(Double(f.number(from: sValue ?? "") ?? 0.0)))
        } else if (type == "bytes") {
            return dValue
        } else if (type == "image") {
            // turn the data back to an image
            if let aValue = dValue {
                return UIImage(data: aValue)
            }
            return nil
        } else if (type == "mdictionary") || (type == "dictionary") || (type == "marray") || (type == "array") {
            var error: Error?
            if (type == "mdictionary") {
                if let aValue = dValue {
                    return try? JSONSerialization.jsonObject(with: aValue, options: .mutableLeaves)
                }
                return nil
            } else if (type == "dictionary") {
                if let aValue = dValue {
                    return try? JSONSerialization.jsonObject(with: aValue, options: .mutableLeaves)
                }
                return nil
            } else if (type == "array") {
                if let aValue = dValue, let anError = try? JSONSerialization.jsonObject(with: aValue, options: .mutableLeaves) as? [Any] {
                    return anError
                }
                return nil
            } else if (type == "marray") {
                if let aValue = dValue, let anError = try? JSONSerialization.jsonObject(with: aValue, options: .mutableLeaves) as? [Any] {
                    return anError
                }
                return nil
            }
        } else if (type == "entity") {
            var dValue = Data(base64Encoded: Data(bytes: data?.utf8CString, length: data?.count ?? 0), options: [])
                // call the block in the sync settings to encrypt the data
            let sync = SharkSync.sharedObject()
            let settings: SharkSyncSettings? = sync.settings
            dValue = settings?.decryptBlock(dValue)
                // turn the data back to a string
            var sValue: String? = nil
            if let aValue = dValue {
                sValue = String(data: aValue, encoding: .unicode)
            }
            // now turn the sValue back to it's original value
            return sValue
        }
        return nil
    }

    class func queueObject(_ object: SRKEntity?, withChanges changes: [AnyHashable: Any]?, withOperation operation: Int, inHashedGroup group: String?) {
        if SRKSyncRegisteredClass.query().where(withFormat: "className = %@", object.self.description())?.count() == nil {
            let c = SRKSyncRegisteredClass()
            c.className = object.self.description() ?? ""
            c.commit()
        }
        if operation == .create || operation == .set {
            /* we have an object so look at the modified fields and queue the properties that have been set */
            for property: String? in changes?.keys ?? [String?]() {
                // exclude the group and ID keys
                if !(property == "Id") && !(property == "recordVisibilityGroup") {
                        /* because all values are encrypted by the client before being sent to the server, we need to convert them into NSData,
                                         to be encrypted however the developer wants, using any method */
                    let value = changes?[property]
                    var type: String? = nil
                    if value != nil {
                        if (value is String) {
                            type = "text"
                            var dValue: Data? = (value as? String)?.data(using: .unicode)
                                // call the block in the sync settings to encrypt the data
                            let sync = SharkSync.sharedObject()
                            let settings: SharkSyncSettings? = sync.settings
                            dValue = settings?.encryptBlock(dValue)
                            let change = SharkSyncChange()
                            if let anId = object?.id, let aDescription = object.self.description() {
                                change.path = "\(anId)/\(aDescription)/\(property ?? "")"
                            }
                            change.action = operation
                            change.recordGroup = group
                            change.timestamp = Date().timeIntervalSince1970
                            let b64Value = dValue?.base64EncodedString(options: [])
                            change.value = "\(type ?? "")/\(b64Value ?? "")"
                            change.commit()
                        } else if (value is NSNumber) {
                            type = "number"
                            var dValue: Data? = nil
                            if let aValue = value {
                                dValue = "\(aValue)".data(using: .unicode)
                            }
                                // call the block in the sync settings to encrypt the data
                            let sync = SharkSync.sharedObject()
                            let settings: SharkSyncSettings? = sync.settings
                            dValue = settings?.encryptBlock(dValue)
                            let change = SharkSyncChange()
                            if let anId = object?.id, let aDescription = object.self.description() {
                                change.path = "\(anId)/\(aDescription)/\(property ?? "")"
                            }
                            change.action = operation
                            change.recordGroup = group
                            change.timestamp = Date().timeIntervalSince1970
                            let b64Value = dValue?.base64EncodedString(options: [])
                            change.value = "\(type ?? "")/\(b64Value ?? "")"
                            change.commit()
                        } else if (value is Date) {
                            type = "date"
                            var dValue: Data? = "\(((value as? Date)?.timeIntervalSince1970) ?? 0.0)".data(using: .unicode)
                                // call the block in the sync settings to encrypt the data
                            let sync = SharkSync.sharedObject()
                            let settings: SharkSyncSettings? = sync.settings
                            dValue = settings?.encryptBlock(dValue)
                            let change = SharkSyncChange()
                            if let anId = object?.id, let aDescription = object.self.description() {
                                change.path = "\(anId)/\(aDescription)/\(property ?? "")"
                            }
                            change.action = operation
                            change.recordGroup = group
                            change.timestamp = Date().timeIntervalSince1970
                            let b64Value = dValue?.base64EncodedString(options: [])
                            change.value = "\(type ?? "")/\(b64Value ?? "")"
                            change.commit()
                        } else if (value is Data) {
                            type = "bytes"
                            var dValue = value as? Data
                                // call the block in the sync settings to encrypt the data
                            let sync = SharkSync.sharedObject()
                            let settings: SharkSyncSettings? = sync.settings
                            dValue = settings?.encryptBlock(dValue)
                            let change = SharkSyncChange()
                            if let anId = object?.id, let aDescription = object.self.description() {
                                change.path = "\(anId)/\(aDescription)/\(property ?? "")"
                            }
                            change.action = operation
                            change.recordGroup = group
                            change.timestamp = Date().timeIntervalSince1970
                            let b64Value = dValue?.base64EncodedString(options: [])
                            change.value = "\(type ?? "")/\(b64Value ?? "")"
                            change.commit()
                        } else if (value is XXImage) {
                            type = "image"
                            var dValue = .uiImageJPEGRepresentation() as? Data
                                // call the block in the sync settings to encrypt the data
                            let sync = SharkSync.sharedObject()
                            let settings: SharkSyncSettings? = sync.settings
                            dValue = settings?.encryptBlock(dValue)
                            let change = SharkSyncChange()
                            if let anId = object?.id, let aDescription = object.self.description() {
                                change.path = "\(anId)/\(aDescription)/\(property ?? "")"
                            }
                            change.action = operation
                            change.recordGroup = group
                            change.timestamp = Date().timeIntervalSince1970
                            let b64Value = dValue?.base64EncodedString(options: [])
                            change.value = "\(type ?? "")/\(b64Value ?? "")"
                            change.commit()
                        } else if (value is [Any]) || (value is [AnyHashable]) || (value is [AnyHashable: Any]) || (value is [AnyHashable: Any]) {
                            if (value is [AnyHashable: Any]) {
                                type = "mdictionary"
                            } else if (value is [AnyHashable]) {
                                type = "marray"
                            } else if (value is [AnyHashable: Any]) {
                                type = "dictionary"
                            } else if (value is [Any]) {
                                type = "array"
                            }
                            var error: Error?
                            var dValue: Data? = nil
                            if let aValue = value {
                                dValue = try? JSONSerialization.data(withJSONObject: aValue, options: .prettyPrinted)
                            }
                                // call the block in the sync settings to encrypt the data
                            let sync = SharkSync.sharedObject()
                            let settings: SharkSyncSettings? = sync.settings
                            dValue = settings?.encryptBlock(dValue)
                            let change = SharkSyncChange()
                            if let anId = object?.id, let aDescription = object.self.description() {
                                change.path = "\(anId)/\(aDescription)/\(property ?? "")"
                            }
                            change.action = operation
                            change.recordGroup = group
                            change.timestamp = Date().timeIntervalSince1970
                            let b64Value = dValue?.base64EncodedString(options: [])
                            change.value = "\(type ?? "")/\(b64Value ?? "")"
                            change.commit()
                        } else if (value is SRKEntity) {
                            type = "entity"
                            var dValue: Data? = nil
                            if let anId = (value as? SRKSyncObject)?.id {
                                dValue = "\(anId)".data(using: .unicode)
                            }
                                // call the block in the sync settings to encrypt the data
                            let sync = SharkSync.sharedObject()
                            let settings: SharkSyncSettings? = sync.settings
                            dValue = settings?.encryptBlock(dValue)
                            let change = SharkSyncChange()
                            if let anId = object?.id, let aDescription = object.self.description() {
                                change.path = "\(anId)/\(aDescription)/\(property ?? "")"
                            }
                            change.action = operation
                            change.recordGroup = group
                            change.timestamp = Date().timeIntervalSince1970
                            let b64Value = dValue?.base64EncodedString(options: [])
                            change.value = "\(type ?? "")/\(b64Value ?? "")"
                            change.commit()
                        } else if (value is NSNull) {
                            let change = SharkSyncChange()
                            if let anId = object?.id, let aDescription = object.self.description() {
                                change.path = "\(anId)/\(aDescription)/\(property ?? "")"
                            }
                            change.action = operation
                            change.recordGroup = group
                            change.timestamp = Date().timeIntervalSince1970
                            change.value = nil
                            change.commit()
                        }
                    }
                }
            }
        } else if operation == .delete {
            let change = SharkSyncChange()
            if let anId = object?.id, let aDescription = object.self.description() {
                change.path = "\(anId)/\(aDescription)/\("__delete__")"
            }
            change.action = operation
            change.recordGroup = group
            change.timestamp = Date().timeIntervalSince1970
            change.commit()
        }
    }
}

class SharkSyncSettings {
    init() {
        super.init()
        
        // these are just defaults to ensure all data is encrypted, it is reccommended that you develop your own or at least set your own aes256EncryptionKey value.
        autoSubscribeToGroupsWhenCommiting = true
        aes256EncryptionKey = SharkSync.sharedObject().applicationKey
        encryptBlock = {(_ dataToEncrypt: Data?) -> Data in
            let sync = SharkSync.sharedObject()
            let settings: SharkSyncSettings? = sync.settings
            if let aKey = dataToEncrypt?.srkaes256Encrypt(withKey: settings?.aes256EncryptionKey) {
                return aKey
            }
            return Data()
        }
        decryptBlock = {(_ dataToDecrypt: Data?) -> Data in
            let sync = SharkSync.sharedObject()
            let settings: SharkSyncSettings? = sync.settings
            if let aKey = dataToDecrypt?.srkaes256Decrypt(withKey: settings?.aes256EncryptionKey) {
                return aKey
            }
            return Data()
        }
    
    }
}
