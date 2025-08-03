import Foundation
import CoreData

@objc(CacheEntry)
public class CacheEntry: NSManagedObject {
    @NSManaged public var key: String?
    @NSManaged public var data: Data?
    @NSManaged public var entityName: String?
    @NSManaged public var timestamp: Date?
}
