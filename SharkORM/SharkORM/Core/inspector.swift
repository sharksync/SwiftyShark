//
//  Inspector.swift
//  SharkORM
//
//  Created by Adrian Herridge on 05/05/2018.
//  Copyright © 2018 SharkSync. All rights reserved.
//

import Foundation

internal class Inspector {
    
    internal class func PersistableProperties(_ class: AnyClass) -> [String:DataType] {
        return [:]
    }
    
    internal class func Indexes(_ class: AnyClass) -> [Index] {
        return []
    }
    
    internal class func DefaultValues(_ class: AnyClass) -> [String:Value] {
        return [:]
    }
    
}
