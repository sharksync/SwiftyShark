//
//  Value.swift
//  SharkORM
//
//  Created by Adrian Herridge on 05/05/2018.
//  Copyright © 2018 SharkSync. All rights reserved.
//

import Foundation

public class Value {
    
    var stringValue: String!
    var dataValue: Data!
    var numericValue: NSNumber!
    var type: DataType
    
    internal init(_ value: Any) {
        let mirror = Mirror(reflecting: value)
        if mirror.subjectType == String.self {
            type = .String
            stringValue = value as! String
        } else if (mirror.subjectType == Float.self) {
            type = .Double
            numericValue = NSNumber(value: value as! Float)
        } else if (mirror.subjectType == Double.self) {
            type = .Double
            numericValue = NSNumber(value: value as! Double)
        } else if (mirror.subjectType == Data.self) {
            type = .Data
            dataValue = value as! Data
        } else if (mirror.subjectType == Int.self) {
            type = .Int
            numericValue = NSNumber(value: value as! Int)
        } else if (mirror.subjectType == Int64.self) {
            type = .Int
            numericValue = NSNumber(value: value as! Int64)
        } else if (mirror.subjectType == UInt64.self) {
            type = .Int
            numericValue = NSNumber(value: value as! UInt64)
        } else if (value is NSNumber) {
            type = .Double
            numericValue = value as! NSNumber
        } else if (value is NSString) {
            type = .String
            stringValue = value as! String
        } else {
            type = .Null
        }
    }
    
    internal func asBool() -> Bool {
        if type == .Int {
            return numericValue.boolValue
        }
        return false
    }
    
    internal func asAny() -> Any? {
        
        if type == .String {
            return stringValue
        }
        
        if type == .Int {
            return numericValue.intValue
        }
        
        if type == .Double {
            return numericValue.doubleValue
        }
        
        if type == .Data {
            return dataValue
        }
        
        return nil
    }
    
    internal func asString() -> String? {
        if type == .String {
            return stringValue
        }
        return nil
    }
    
    internal func asInt() -> Int? {
        
        if type == .Int {
            return numericValue.intValue
        }
        
        return nil
    }
    
    internal func asInt64() -> Int64? {
        
        if type == .Int {
            return numericValue.int64Value
        }
        
        return nil
    }
    
    internal func asUInt64() -> UInt64? {
        
        if type == .Int {
            return numericValue.uint64Value
        }
        
        return nil
    }
    
    internal func asDouble() -> Double? {
        
        if type == .Double {
            return numericValue.doubleValue
        }
        
        return nil
    }
    
    internal func getType() -> DataType {
        return type
    }
    
}
