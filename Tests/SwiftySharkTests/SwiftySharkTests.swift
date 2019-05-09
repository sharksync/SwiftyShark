import XCTest
@testable import SwiftyShark

final class Department: Codable, SharkyObject {
    
    var id: Int?
    var name: String?
    var address: String?
    
}

final class Person: Codable, SharkyObject {
    
    var id: Int?
    var name: String?
    var age: Int?
    var department: Department?
    
}

final class SwiftySharkTests: XCTestCase {
    
    func testExample() {
        
        let db = SwiftyShark(provider: SQLiteProvider(path: "/Users/adrian/Downloads", filename: "test.db"))
        
        db.create(Person(), pk: "id", auto: true, indexes: ["name"])
        
        let p = Person()
        p.age = 40
        p.name = "Adrian"
        p.department = Department()
        p.department?.address = "18 Funtley Road, Funtley, Fareham"
        
        db.put(p)
        
    }

    static var allTests = [
        ("testExample", testExample),
    ]
    
}
