//
//  Query.swift
//  SwiftyShark
//
//  Created by Adrian Herridge on 08/05/2019.
//

import Foundation



class George: Codable, SharkyObject {
    var subGeorge: George? = George()
}

public class Query {
    
    private var `where`: String = "1 = 1"
    private var limit: Int = 999999999
    private var params: [Any] = []
    private var order: String = "ROWID"
    private var offset: Int = 0
    
    func `where`(_ `where`: String) -> Query {
        self.where = `where`
        return self
    }
    
    func `where`(_ `where`: String, parameters:[Any]) -> Query {
        self.where = `where`
        self.params = parameters
        return self
    }
    
    func order(_ order: String) -> Query {
        self.order = order
        return self
    }
    
    func limit(_ limit: Int) -> Query {
        self.limit = limit
        return self
    }
    
    func offset(_ offset: Int) -> Query {
        self.offset = offset
        return self
    }
    
}
