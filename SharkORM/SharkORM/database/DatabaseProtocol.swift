//
//  DatabaseInterface.swift
//  SharkORM
//
//  Created by Adrian Herridge on 05/05/2018.
//  Copyright © 2018 SharkSync. All rights reserved.
//

import Foundation

public enum DatabaseError: Error {
    case Syntax(String)
}

protocol DatabaseProtocol {
    init(_ filename: String)
    func close()
    func execute(sql: String, params:[Value]) throws
    func query(sql: String, params:[Any]) throws -> [Record]
}
