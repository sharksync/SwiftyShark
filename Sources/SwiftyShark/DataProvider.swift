//
//  ProviderInterface.swift
//  SwiftyShark
//
//  Created by Adrian Herridge on 08/05/2019.
//

import Foundation

public protocol DataProvider {
    
    func close()
    func execute(sql: String, params:[Any?], silenceErrors: Bool) -> Result
    func create<T>(_ object: T, pk: String, auto: Bool, indexes: [String]) where T: Encodable
    func put<T>(_ object: T) -> Result where T: Codable
    func query<T>(_ object: T, sql: String, params: [Any?]) -> [T] where T: Codable
    func upsert(table: String, values: [String:Any?]) -> Result
    func query(sql: String, params:[Any?]) -> Result
    
}
