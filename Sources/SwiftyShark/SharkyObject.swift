//
//  SharkyObject.swift
//  SwiftyShark
//
//  Created by Adrian Herridge on 09/05/2019.
//

import Foundation

public protocol SharkyObject where Self:Codable {
    func put()
}

public extension SharkyObject {
    
    func put() {
        let l = SwiftyShark(provider: SQLiteProvider(path: "", filename: ""))
        _ = l.put(self)
    }
    
    func fetch(_ query: Query) -> [Self] {
        return []
    }
    
}
