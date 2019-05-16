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
    var departmentId: Int?
    
}

final class SwiftySharkTests: XCTestCase {
    
    func testExample() {
        
        let db = SwiftyShark(provider: SQLiteProvider(path: "/Users/adrian/Downloads", filename: "test.db"))
        
        db.create(Person(), pk: "id", auto: true, indexes: ["name"])
        db.create(Department(), pk: "id", auto: true, indexes: ["name"])
        
        _ = db.execute(sql: "DELETE FROM Person;", params: [])
        
        let p = Person()
        p.age = 40
        p.name = "Adrian"
        
        let d = Department()
        d.address = "18 Funtley Road, Funtley, Fareham"
        
        // or can be placed using the default store
        d.put()
        p.put()
        
        p.departmentId = d.id
        p.put()
        
        // queries are on the objects themselves again, much like before
        let results = Person().fetch(Query().where("name = ?", parameters: ["Adrian"]).limit(10))

    }

    static var allTests = [
        ("testExample", testExample),
    ]
    
}
