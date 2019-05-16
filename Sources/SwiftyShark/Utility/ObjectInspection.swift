//
//  ObjectInspection.swift
//  SwiftyShark
//
//  Created by Adrian Herridge on 10/05/2019.
//

import Foundation

enum ObjectPropertyType {
    
    case Int
    case Float
    case Bool
    case String
    case Double
    case Data
    case Image
    case Unsupported
    
}

struct ObjectPropertyInfo {
    
    var name: String
    var type: ObjectPropertyType
    var nullable: Bool
    var value: Any?
    
}

struct ObjectProperties {
    
    var name: String
    var properties: [String:ObjectPropertyInfo] = [:]
    
}

func getNullable(_ type: Any.Type) -> Bool {
    
    if type == String?.self {
        return true
    }
    if type == Int?.self {
        return true
    }
    if type == UInt64?.self {
        return true
    }
    if type == UInt?.self {
        return true
    }
    if type == Int64?.self {
        return true
    }
    if type == Double?.self {
        return true
    }
    if type == Data?.self {
        return true
    }
    
    return false
    
}

func unwrap(_ subject: Any?) -> Any? {
    
    var value: Any?
    if subject == nil {
        return nil;
    }
    let mirrored = Mirror(reflecting:subject!)
    if mirrored.displayStyle != .optional {
        value = subject
    } else if let firstChild = mirrored.children.first {
        value = firstChild.value
    }
    return value
    
}

func getType(_ type: Any.Type) -> ObjectPropertyType {
    
    if type == String.self {
        return .String
    }
    if type == String?.self {
        return .String
    }
    if type == Int?.self {
        return .Int
    }
    if type == Int.self {
        return .Int
    }
    if type == UInt64?.self {
        return .Int
    }
    if type == UInt64.self {
        return .Int
    }
    if type == UInt?.self {
        return .Int
    }
    if type == UInt.self {
        return .Int
    }
    if type == Int64?.self {
        return .Int
    }
    if type == Int64.self {
        return .Int
    }
    if type == Double?.self {
        return .Double
    }
    if type == Double.self {
        return .Double
    }
    if type == Data?.self {
        return .Data
    }
    if type == Data.self {
        return .Data
    }
    
    return .Unsupported
    
}

func objectProperties(_ object: Codable) -> ObjectProperties {
    
    let mirror = Mirror(reflecting: object)
    var props = ObjectProperties(name: "\("\(mirror)".split(separator: " ").last!)", properties: [:])
    
    // find the pk, examine the type and create the table
    for c in mirror.children {
        if c.label != nil {
            let propMirror = Mirror(reflecting: c.value)
            if getType(propMirror.subjectType) != .Unsupported {
                
                props.properties[c.label!] = ObjectPropertyInfo(name:c.label! , type: getType(propMirror.subjectType), nullable: getNullable(propMirror.subjectType), value: unwrap(c.value))
                
            }
            
        }
    }
    
    return props
    
}
