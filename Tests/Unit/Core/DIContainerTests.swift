import XCTest
@testable import Marilena

class DIContainerTests: XCTestCase {
    var container: DIContainerImpl!
    
    override func setUp() {
        super.setUp()
        container = DIContainerImpl()
    }
    
    override func tearDown() {
        container = nil
        super.tearDown()
    }
    
    func testRegisterAndResolveFactory() {
        // Given
        container.register(String.self) { "Test String" }
        
        // When
        let result = container.resolve(String.self)
        
        // Then
        XCTAssertEqual(result, "Test String")
    }
    
    func testRegisterAndResolveSingleton() {
        // Given
        let testString = "Singleton Test"
        container.register(String.self, instance: testString)
        
        // When
        let result1 = container.resolve(String.self)
        let result2 = container.resolve(String.self)
        
        // Then
        XCTAssertEqual(result1, testString)
        XCTAssertEqual(result2, testString)
        XCTAssertTrue(result1 == result2) // Same instance
    }
    
    func testResolveOptional() {
        // When
        let result: String? = container.resolve(String.self)
        
        // Then
        XCTAssertNil(result)
    }
}

