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


class SRKSyncObject {
    private var _recordVisibilityGroup = ""
    var recordVisibilityGroup: String {
        get {
            return _recordVisibilityGroup
        }
        set(group) {
            _recordVisibilityGroup = group ?? ""
        }
    }

    class func initialize() {
        super.initialize()
    }

    convenience init(fromClass cls: String?, withPrimaryKey pk: String?) {
        if !NSClassFromString(cls) {
            if !NSClassFromString(SRKGlobals.sharedObject().getFQName(forClass: cls)) {
                return nil
            }
        }
        var cl = NSClassFromString(cls)().object(withPrimaryKeyValue: pk as NSObject?) as? AnyClass
        if cl == nil {
            cl = NSClassFromString(SRKGlobals.sharedObject().getFQName(forClass: cls))
        }
        return cl?.object(withPrimaryKeyValue: pk as NSObject?)
    }

    convenience init(fromClass cls: String?) {
        var srkClass: AnyClass = NSClassFromString(cls)
        if !srkClass {
            srkClass = NSClassFromString(SRKGlobals.sharedObject().getFQName(forClass: cls))
        }
        return srkClass()
    }

    func commit() -> Bool {
        /* because this is going to happen, we need to generate a primary key now */
        if !id {
            self.id = UUID().uuidString.lowercased()
        }
        return commit(inGroup: SHARKSYNC_DEFAULT_GROUP)
        // set the global group
    }

    func commit(inGroup group: String?) -> Bool {
        // hash this group
        group = SharkSync.md5(from: group)
        SharkSync.setEffectiveRecorGroup(group)
        if super.commit() {
            SharkSync.clearEffectiveRecordGroup()
            return true
        }
        SharkSync.clearEffectiveRecordGroup()
        return false
    }

    func remove() -> Bool {
        if recordVisibilityGroup == "" {
            SharkSync.setEffectiveRecorGroup(SharkSync.md5(from: SHARKSYNC_DEFAULT_GROUP))
        } else {
            SharkSync.setEffectiveRecorGroup(recordVisibilityGroup)
        }
        if super.remove() {
            SharkSync.clearEffectiveRecordGroup()
            return true
        }
        SharkSync.clearEffectiveRecordGroup()
        return false
    }

    func __commitRaw(withObjectChain chain: SRKEntityChain?) -> Bool {
            // hash this group
        let group = SharkSync.getEffectiveRecordGroup()
            // pull out all the change sthat have been made, by the dirtyField flags
        var changes = [AnyHashable: Any]()
        var combinedChanges = entityContentsAsObjects()
        for dirtyField: String? in dirtyFields() {
            changes[dirtyField] = combinedChanges?[dirtyField]
        }
        if recordVisibilityGroup != "" && !(recordVisibilityGroup == group) {
            // group has changed, queue a delete for the old record before the commit goes through for the new
            SharkSync.queueObject(self, withChanges: nil, withOperation: .delete, inHashedGroup: recordVisibilityGroup)
                // generate the new UUID
            let newUUID = UUID().uuidString.lowercased()
            // create a new uuid for this record, as it has to appear to the server to be new
            SharkORM().replaceUUIDPrimaryKey(self, withNewUUIDKey: newUUID)
                // if there are any embedded objects, then they will have their record group potentially changed too & and a new UUID
            var updatedEmbeddedObjects = [AnyHashable]() as? [AnyHashable]
            for o: SRKSyncObject in embeddedEntities.allValues as? [SRKSyncObject] ?? [SRKSyncObject]() {
                if (o is SRKSyncObject) {
                    // check to see if this object has already appeard in this chain.
                    if !(chain?.doesObjectExist(inChain: o) ?? false) {
                        // now check to see if this is a different record group, if so replace it and regen the UDID
                        if o.recordVisibilityGroup != "" && !(o.recordVisibilityGroup == group) {
                            // group has changed, queue a delete for the old record before the commit goes through for the new
                            SharkSync.queueObject(o, withChanges: nil, withOperation: .delete, inHashedGroup: o.recordVisibilityGroup)
                                // generate the new UUID
                            let newUUID = UUID().uuidString.lowercased()
                            // create a new uuid for this record, as it has to appear to the server to be new
                            SharkORM().replaceUUIDPrimaryKey(o, withNewUUIDKey: newUUID)
                            o.recordVisibilityGroup = group ?? ""
                            // now we have to flag all fields as dirty, because they need to have their values written to the upstream table
                            for field: String? in o.fieldNames {
                                o.dirtyFields[field] = 1
                            }
                            // add object to the list of changes
                            updatedEmbeddedObjects?.append(o)
                            o.__commitRaw(withObjectChain: chain)
                        }
                    }
                }
            }
            for r: SRKRelationship? in SharkSchemaManager.shared.relationships(withEntity: SRKSyncObject.description(), type: 1) {
                    /* this is a link field that needs to be updated */
                let e = embeddedEntities[r?.entityPropertyName] as? SRKSyncObject
                if e != nil && (e is SRKSyncObject) {
                    if let anE = e {
                        if updatedEmbeddedObjects?.contains(anE) ?? false {
                            if let aName = r?.entityPropertyName {
                                setField("\(aName)", value: (e as? SRKSyncObject)?.id)
                            }
                        }
                    }
                }
            }
                // now ensure that all values are written for this new record
            var entityValues = [AnyHashable: Any]()
            for field: String? in fieldNames {
                let value = getField(field)
                entityValues[field] = value != nil ? value : NSNull()
            }
            if let anObjects = entityContentsAsObjects() {
                changes = anObjects
            }
        }
        recordVisibilityGroup = group ?? ""
        let exists: Bool = isExists
        if super.__commitRaw(withObjectChain: chain) {
            SharkSync.queueObject(self, withChanges: changes, withOperation: exists ? .set : .create, inHashedGroup: group)
            return true
        }
        return false
    }

    func __removeRaw() -> Bool {
        let cachedPK = id()
        if super.__removeRaw() {
            self.id = cachedPK
            SharkSync.queueObject(self, withChanges: nil, withOperation: .delete, inHashedGroup: SharkSync.getEffectiveRecordGroup())
            self.id = nil
            return true
        }
        return false
    }

    func __commitRaw(withObjectChainNoSync chain: SRKEntityChain?) -> Bool {
        return super.__commitRaw(withObjectChain: SRKEntityChain())
    }

    func getRecordGroup() -> String? {
        return recordVisibilityGroup
    }

    func __removeRawNoSync() -> Bool {
        return super.__removeRaw()
    }
}
