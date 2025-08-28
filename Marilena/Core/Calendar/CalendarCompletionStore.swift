import Foundation
import CoreData

/// Optional Core Data persistence for completed event keys.
/// Works only if the Core Data model contains an entity named `CompletedEvent`
/// with attributes: `key` (String, unique), `completedAt` (Date).
final class CalendarCompletionStore {
    private let context: NSManagedObjectContext
    private var entity: NSEntityDescription?

    init(context: NSManagedObjectContext) {
        self.context = context
        self.entity = NSEntityDescription.entity(forEntityName: "CompletedEvent", in: context)
    }

    private var isAvailable: Bool { entity != nil }

    func loadAllKeys() -> Set<String> {
        guard isAvailable else { return [] }
        let fetch = NSFetchRequest<NSManagedObject>(entityName: "CompletedEvent")
        do {
            let items = try context.fetch(fetch)
            let keys = items.compactMap { $0.value(forKey: "key") as? String }
            return Set(keys)
        } catch {
            return []
        }
    }

    func upsert(key: String, completedAt: Date = Date()) {
        guard isAvailable else { return }
        context.perform {
            let fetch = NSFetchRequest<NSManagedObject>(entityName: "CompletedEvent")
            fetch.predicate = NSPredicate(format: "key == %@", key)
            let obj: NSManagedObject
            let existing = (try? self.context.fetch(fetch))?.first
            if let e = existing { obj = e }
            else {
                guard let entity = self.entity else { return }
                obj = NSManagedObject(entity: entity, insertInto: self.context)
                obj.setValue(key, forKey: "key")
            }
            obj.setValue(completedAt, forKey: "completedAt")
            try? self.context.save()
        }
    }

    func remove(key: String) {
        guard isAvailable else { return }
        context.perform {
            let fetch = NSFetchRequest<NSManagedObject>(entityName: "CompletedEvent")
            fetch.predicate = NSPredicate(format: "key == %@", key)
            if let items = try? self.context.fetch(fetch) {
                for obj in items { self.context.delete(obj) }
                try? self.context.save()
            }
        }
    }
}
