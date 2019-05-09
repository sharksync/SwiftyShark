import Dispatch
import Foundation

public typealias Record = [String:Value]

public enum DataType {
    case String
    case Blob
    case Null
    case Int
    case Double
}

public enum SWSQLOp {
    case Insert
    case Update
    case Delete
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

public class SwiftyShark {
    
    var provider: DataProvider
    
    public init(provider: DataProvider) {
        self.provider = provider
    }
    
    func close() {
        self.provider.close()
    }
    
    public func execute(sql: String, params:[Any?], silenceErrors: Bool) -> Result {
        return self.provider.execute(sql: sql, params: params, silenceErrors: silenceErrors)
    }
    
    public func create<T>(_ object: T, pk: String, auto: Bool, indexes: [String]) where T: Encodable {
        self.provider.create(object, pk: pk, auto: auto, indexes: indexes)
    }
    
    public func put<T>(_ object: T) -> Result where T: Codable {
        return self.provider.put(object)
    }
    
    public func query<T>(_ object: T, sql: String, params: [Any?]) -> [T] where T: Codable {
        return self.provider.query(object, sql: sql, params: params)
    }
    
    public func upsert(table: String, values: [String:Any?]) -> Result {
        return self.provider.upsert(table: table, values: values)
    }
    
    public func execute(sql: String, params:[Any?]) -> Result {
        return self.provider.execute(sql: sql, params: params, silenceErrors: false)
    }
    
    public func query(sql: String, params:[Any?]) -> Result {
        return self.provider.query(sql: sql, params: params)
    }
 
}


