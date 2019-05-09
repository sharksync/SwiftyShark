//
//  ColumnValueObject.swift
//  SwiftyShark
//
//  Created by Adrian Herridge on 08/05/2019.
//

import Foundation

public class Value {
    
    var stringValue: String!
    var blobValue: Data!
    var numericValue: NSNumber!
    var type: DataType
    
    public init(_ value: Any?) {
        
        var testValue: Any? = nil
        if value != nil {
            testValue = unwrap(value)
        }
        
        if testValue as Any? == nil {
            type = .Null
            return;
        }
        
        let mirror = Mirror(reflecting: value!)
        if mirror.subjectType == String.self || mirror.subjectType == String?.self {
            type = .String
            stringValue = value as! String
        } else if (mirror.subjectType == Float.self || mirror.subjectType == Float?.self) {
            type = .Double
            numericValue = NSNumber(value: value as! Float)
        } else if (mirror.subjectType == Double.self || mirror.subjectType == Double?.self) {
            type = .Double
            numericValue = NSNumber(value: value as! Double)
        } else if (mirror.subjectType == Data.self || mirror.subjectType == Data?.self) {
            type = .Blob
            blobValue = value as! Data
        } else if (mirror.subjectType == Int.self || mirror.subjectType == Int?.self) {
            type = .Int
            numericValue = NSNumber(value: value as! Int)
        } else if (mirror.subjectType == Int64.self || mirror.subjectType == Int64?.self) {
            type = .Int
            numericValue = NSNumber(value: value as! Int64)
        } else if (mirror.subjectType == UInt64.self || mirror.subjectType == UInt64?.self) {
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
    
    public func asBool() -> Bool {
        if type == .Int {
            return numericValue.boolValue
        }
        return false
    }
    
    public func asAny() -> Any? {
        
        if type == .String {
            return stringValue
        }
        
        if type == .Int {
            return Int(numericValue.intValue)
        }
        
        if type == .Double {
            return Double(numericValue.doubleValue)
        }
        
        if type == .Blob {
            return blobValue
        }
        
        return nil
    }
    
    public func asString() -> String? {
        if type == .String {
            return stringValue
        }
        return nil
    }
    
    public func asInt() -> Int? {
        
        if type == .Int {
            return numericValue.intValue
        }
        
        return nil
    }
    
    public func asInt64() -> Int64? {
        
        if type == .Int {
            return numericValue.int64Value
        }
        
        return nil
    }
    
    public func asUInt64() -> UInt64? {
        
        if type == .Int {
            return numericValue.uint64Value
        }
        
        return nil
    }
    
    public func asDouble() -> Double? {
        
        if type == .Double {
            return numericValue.doubleValue
        }
        
        return nil
    }
    
    public func asData() -> Data? {
        
        if type == .Blob {
            return blobValue
        }
        
        return nil
    }
    
    public func getType() -> DataType {
        return type
    }
    
}
