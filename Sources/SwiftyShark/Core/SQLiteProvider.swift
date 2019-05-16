//
//  SQLiteProvider.swift
//  SwiftyShark
//
//  Created by Adrian Herridge on 08/05/2019.
//

import Foundation

#if os(Linux)
import CSQLiteLinux
#else
import CSQLiteDarwin
#endif

import Dispatch

internal let SQLITE_STATIC = unsafeBitCast(0, to: sqlite3_destructor_type.self)
internal let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public class SQLiteProvider: DataProvider {
    
    var db: OpaquePointer?
    
    init(path: String, filename: String) {
        
        // create any folders up until this point as well
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: nil)
        
        let _ = sqlite3_open("\(path)/\(filename)", &db);
        sqlite3_create_function(db, "SHA512", 1, SQLITE_ANY, nil, nil, sha512step, sha512finalize)
        
    }
    
    public func close() {
        sqlite3_close(db)
        db = nil;
    }
    
    public func execute(sql: String, params:[Any?], silenceErrors: Bool) -> Result {
        
        let result = Result()
        
        var values: [Value] = []
        for o in params {
            values.append(Value(o))
        }
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, Int32(sql.utf8.count), &stmt, nil) == SQLITE_OK {
            
            bind(stmt: stmt, params: values);
            while sqlite3_step(stmt) != SQLITE_DONE {
                
            }
            
        } else {
            // error in statement
            if !silenceErrors {
                result.error = "\(String(cString: sqlite3_errmsg(db)))"
            }
        }
        
        sqlite3_finalize(stmt)
        
        return result
        
    }
    
    public func create<T>(_ object: T, pk: String, auto: Bool, indexes: [String]) where T: Codable {
        
        let mirror = Mirror(reflecting: object)
        let name = "\(mirror)".split(separator: " ").last!
        
        // find the pk, examine the type and create the table
        for c in mirror.children {
            if c.label != nil {
                if c.label! == pk {
                    let propMirror = Mirror(reflecting: c.value)
                    if propMirror.subjectType == String?.self {
                        _ = self.execute(sql: "CREATE TABLE IF NOT EXISTS \(name) (\(pk) TEXT PRIMARY KEY);", params: [])
                    } else if propMirror.subjectType == Int?.self {
                        _ = self.execute(sql: "CREATE TABLE IF NOT EXISTS \(name) (\(pk) INTEGER PRIMARY KEY \(auto ? "AUTOINCREMENT" : ""));", params: [])
                    }
                }
            }
        }
        
        for c in mirror.children {
            
            if c.label != nil {
                let propMirror = Mirror(reflecting: c.value)
                if propMirror.subjectType == String?.self {
                    _ = self.execute(sql: "ALTER TABLE \(name) ADD COLUMN \(c.label!) TEXT", params: [], silenceErrors:true)
                } else if propMirror.subjectType == Int?.self || propMirror.subjectType == UInt64?.self || propMirror.subjectType == UInt?.self || propMirror.subjectType == Int64?.self {
                    _ = self.execute(sql: "ALTER TABLE \(name) ADD COLUMN \(c.label!) INTEGER", params: [], silenceErrors:true)
                } else if propMirror.subjectType == Double?.self {
                    _ = self.execute(sql: "ALTER TABLE \(name) ADD COLUMN \(c.label!) REAL", params: [], silenceErrors:true)
                } else if propMirror.subjectType == Data?.self {
                    _ = self.execute(sql: "ALTER TABLE \(name) ADD COLUMN \(c.label!) BLOB", params: [], silenceErrors:true)
                }
            }
            
        }
        
        for i in indexes {
            _ = self.execute(sql: "CREATE INDEX IF NOT EXISTS idx_\(name)_\(i.replacingOccurrences(of: ",", with: "_")) ON \(name) (\(i));", params: [], silenceErrors:true)
        }
        
    }
    
    public func put<T>(_ object: T) -> Result where T: Codable {
        
        let mirror = Mirror(reflecting: object)
        let name = "\(mirror)".split(separator: " ").last!
        
        var placeholders: [String] = []
        var columns: [String] = []
        var params: [Any?] = []
        let types: [Any.Type] = [String?.self, String.self,Int?.self,Int.self,UInt64?.self,UInt64.self,UInt?.self,UInt.self,Int64?.self,Int64.self,Double?.self,Double.self,Data?.self,Data.self]
        
        // find the pk, examine the type and create the table
        for c in mirror.children {
            if c.label != nil {
                let propMirror = Mirror(reflecting: c.value)
                for t in types {
                    if t == propMirror.subjectType {
                        
                        placeholders.append("?")
                        params.append(unwrap(c.value))
                        columns.append(c.label!)
                    }
                }
            }
        }
        
        let newId = 100;

        return execute(sql: "INSERT OR REPLACE INTO \(name) (\(columns.joined(separator: ","))) VALUES (\(placeholders.joined(separator: ",")))", params: params)
        
    }
    
    public func query<T>(_ object: T, sql: String, params: [Any?]) -> [T] where T: Codable {
        
        let r = query(sql: sql, params: params)
        if r.error != nil {
            return []
        }
        
        var results: [T] = []
        
        
        for record in r.results {
            
            let decoder = JSONDecoder()
            decoder.dataDecodingStrategy = .base64
            
            var row: [String] = []
            
            for k in record.keys {
                
                switch record[k]!.getType() {
                case .Null:
                    row.append("\"\(k)\" : null")
                    break
                case .Blob:
                    row.append("\"\(k)\" : \"\(record[k]!.asData()!.base64EncodedString())\"")
                    break
                case .Double:
                    row.append("\"\(k)\" : \(unwrap(record[k]!.asDouble())!)")
                    break
                case .Int:
                    row.append("\"\(k)\" : \(unwrap(record[k]!.asInt())!)")
                    break
                case .String:
                    row.append("\"\(k)\" : \"\(unwrap(record[k]!.asString())!)\"")
                    break
                }
            }
            
            var jsonString = "{\(row.joined(separator: ","))}"
            
            do {
                let rowObject: T = try decoder.decode(T.self, from: Data(bytes: Array(jsonString.utf8)))
                results.append(rowObject)
            } catch {
                print("JSON causing the issue: \n\n\(jsonString)\n")
                print(error)
            }
            
            
        }
        
        return results
        
    }
    
    public func upsert(table: String, values: [String:Any?]) -> Result {
        
        var placeholders: [String] = []
        var columns: [String] = []
        var params: [Any?] = []
        
        for k in values.keys {
            placeholders.append("?")
            params.append(values[k])
            columns.append(k)
        }
        
        return execute(sql: "INSERT OR REPLACE INTO \(table) (\(columns.joined(separator: ",")) VALUES (\(placeholders.joined(separator: ","))", params: params)
        
    }
    
    public func execute(sql: String, params:[Any?]) -> Result {
        
        return execute(sql: sql, params: params, silenceErrors: false)
        
    }
    
    public func query(sql: String, params:[Any?]) -> Result {
        
        let result = Result()
        var results: [[String:Value]] = []
        
        var values: [Value] = []
        for o in params {
            values.append(Value(o))
        }
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, Int32(sql.utf8.count), &stmt, nil) == SQLITE_OK {
            bind(stmt: stmt, params: values);
            while sqlite3_step(stmt) == SQLITE_ROW {
                
                var rowData: Record = [:]
                let columns = sqlite3_column_count(stmt)
                if columns > 0 {
                    for i in 0...Int(columns-1) {
                        
                        let columnName = String.init(cString: sqlite3_column_name(stmt, Int32(i)))
                        var value: Value
                        
                        switch sqlite3_column_type(stmt, Int32(i)) {
                        case SQLITE_INTEGER:
                            value = Value(Int(sqlite3_column_int64(stmt, Int32(i))))
                        case SQLITE_FLOAT:
                            value = Value(Double(sqlite3_column_double(stmt, Int32(i))))
                        case SQLITE_TEXT:
                            value = Value(String.init(cString:sqlite3_column_text(stmt, Int32(i))))
                        case SQLITE_BLOB:
                            let d = Data(bytes: sqlite3_column_blob(stmt, Int32(i)), count: Int(sqlite3_column_bytes(stmt, Int32(i))))
                            value = Value(d)
                        case SQLITE_NULL:
                            value = Value(NSNull())
                        default:
                            value = Value(NSNull())
                            break;
                        }
                        
                        rowData[columnName] = value
                        
                    }
                }
                results.append(rowData)
                
            }
        } else {
            // error in statement
            result.error = "\(String(cString: sqlite3_errmsg(db)))"
        }
        
        result.results = results
        
        sqlite3_finalize(stmt)
        
        return result
        
    }
    
    private func bind(stmt: OpaquePointer?, params:[Value]) {
        
        var paramCount = sqlite3_bind_parameter_count(stmt)
        let passedIn = params.count
        
        if(Int(paramCount) != passedIn) {
            // error
        }
        
        paramCount = 1;
        
        for v in params {
            
            switch v.type {
            case .String:
                let s = v.stringValue!
                sqlite3_bind_text(stmt, paramCount, s,Int32(s.count) , SQLITE_TRANSIENT)
            case .Null:
                sqlite3_bind_null(stmt, paramCount)
            case .Blob:
                sqlite3_bind_blob(stmt, paramCount, [UInt8](v.blobValue!), Int32(v.blobValue!.count), SQLITE_TRANSIENT)
            case .Double:
                sqlite3_bind_double(stmt, paramCount, v.numericValue.doubleValue)
            case .Int:
                sqlite3_bind_int64(stmt, paramCount, v.numericValue.int64Value)
            }
            
            paramCount += 1
            
        }
        
    }
    
}
