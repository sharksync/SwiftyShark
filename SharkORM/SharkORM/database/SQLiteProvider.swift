//
//  SQLiteProvider.swift
//  SharkORM
//
//  Created by Adrian Herridge on 05/05/2018.
//  Copyright © 2018 SharkSync. All rights reserved.
//

import Foundation
import SQLite3

class SQLiteProvider : DatabaseProtocol {
    
    internal var db: OpaquePointer?
    internal let SQLITE_STATIC = unsafeBitCast(0, to: sqlite3_destructor_type.self)
    internal let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    public required init(_ filename: String) {
        
        // create any folders up until this point as well
        let _ = sqlite3_open("\(filename)", &db);
        
    }
    
    public func close() {
        sqlite3_close(db)
        db = nil;
    }
    
    public func execute(sql: String, params:[Value]) throws {
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, Int32(sql.utf8.count), &stmt, nil) == SQLITE_OK {
            
            bind(stmt: stmt, params: params);
            while sqlite3_step(stmt) != SQLITE_DONE {
                
            }
            
        } else {
            
            // error in statement
            throw DatabaseError.Syntax(String(cString: sqlite3_errmsg(db)))
            
        }
        
        sqlite3_finalize(stmt)
        
    }
    
    public func query(sql: String, params:[Any]) throws -> [Record] {
        
        var results: [Record] = []
        
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
                            value = Value(NSData(bytes:sqlite3_column_blob(stmt, Int32(i)), length: Int(sqlite3_column_bytes(stmt, Int32(i)))))
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
            throw DatabaseError.Syntax(String(cString: sqlite3_errmsg(db)))
        }
        
        sqlite3_finalize(stmt)
        
        return results
        
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
            case .Data:
                sqlite3_bind_blob(stmt, paramCount, [UInt8](v.dataValue!), Int32(v.dataValue!.count), SQLITE_TRANSIENT)
            case .Double:
                sqlite3_bind_double(stmt, paramCount, v.numericValue.doubleValue)
            case .Int:
                sqlite3_bind_int64(stmt, paramCount, v.numericValue.int64Value)
            case .Array:
                // would have to be codable, and then serialised
                break
            case .Bool:
                sqlite3_bind_int64(stmt, paramCount, v.numericValue.int64Value)
            case .Dictionary:
                // would have to be codable, and then serialised
                break
            case .Float:
                sqlite3_bind_double(stmt, paramCount, v.numericValue.doubleValue)
            case .SharkObject:
                break
            }
            
            paramCount += 1
            
        }
        
    }
    
}
