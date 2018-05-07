//
//  SyncInterface.swift
//  SharkORM
//
//  Created by Adrian Herridge on 12/11/2017.
//  Copyright © 2017 Adrian Herridge. All rights reserved.
//

import Foundation

@objc public class SyncService { 
    @objc public class func StartService() -> Void {
        SyncNetwork.sharedInstance.active = true
    }
    @objc public class func StopService() -> Void {
        SyncNetwork.sharedInstance.active = false
    }
    @objc public class func SynchroniseNow() -> Void {
        SyncNetwork.sharedInstance.synchroniseNow()
    }
}
