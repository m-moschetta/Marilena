import Foundation
import CoreData

/// Unified cache manager per le email (combina memory + CoreData)
@MainActor
public final class EmailCacheManager {

    // MARK: - Singleton
    public static let shared = EmailCacheManager()

    // MARK: - Properties
    private var memoryCache: [String: EmailMessage] = [:]
    private let cacheQueue = DispatchQueue(label: "com.marilena.email.cache", qos: .userInitiated)
    private let maxMemoryCacheSize = 100

    // Core Data
    private let persistenceController = PersistenceController.shared
    private var context: NSManagedObjectContext {
        persistenceController.container.viewContext
    }

    // MARK: - Initialization
    private init() {}

    // MARK: - Public Methods

    /// Recupera email da cache (memory -> CoreData)
    public func getEmail(id: String) -> EmailMessage? {
        // 1. Try memory cache first
        if let cached = memoryCache[id] {
            return cached
        }

        // 2. Try CoreData
        let fetchRequest: NSFetchRequest<CachedEmail> = CachedEmail.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        fetchRequest.fetchLimit = 1

        do {
            if let cachedEmail = try context.fetch(fetchRequest).first {
                let email = convertToEmailMessage(cachedEmail)
                // Populate memory cache
                memoryCache[id] = email
                return email
            }
        } catch {
            print("❌ EmailCacheManager: Error fetching from CoreData: \(error)")
        }

        return nil
    }

    /// Recupera tutte le email da cache
    public func getAllEmails() -> [EmailMessage] {
        let fetchRequest: NSFetchRequest<CachedEmail> = CachedEmail.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fetchRequest.predicate = NSPredicate(format: "isMarkedAsDeleted == NO")

        do {
            let cachedEmails = try context.fetch(fetchRequest)
            return cachedEmails.map { convertToEmailMessage($0) }
        } catch {
            print("❌ EmailCacheManager: Error fetching all from CoreData: \(error)")
            return []
        }
    }

    /// Salva/aggiorna email in cache (memory + CoreData)
    public func saveEmail(_ email: EmailMessage) {
        // 1. Update memory cache
        memoryCache[email.id] = email
        trimMemoryCacheIfNeeded()

        // 2. Update CoreData
        let fetchRequest: NSFetchRequest<CachedEmail> = CachedEmail.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", email.id)
        fetchRequest.fetchLimit = 1

        do {
            let existing = try context.fetch(fetchRequest).first

            let cachedEmail = existing ?? CachedEmail(context: context)
            updateCachedEmail(cachedEmail, with: email)

            if context.hasChanges {
                try context.save()
            }
        } catch {
            print("❌ EmailCacheManager: Error saving to CoreData: \(error)")
        }
    }

    /// Salva batch di email (ottimizzato per performance)
    public func saveBatch(_ emails: [EmailMessage]) {
        context.perform { [weak self] in
            guard let self = self else { return }

            // Fetch esistenti
            let ids = emails.map { $0.id }
            let fetchRequest: NSFetchRequest<CachedEmail> = CachedEmail.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id IN %@", ids)

            do {
                let existing = try self.context.fetch(fetchRequest)
                let existingDict = Dictionary(uniqueKeysWithValues: existing.map { ($0.id ?? "", $0) })

                for email in emails {
                    let cachedEmail = existingDict[email.id] ?? CachedEmail(context: self.context)
                    self.updateCachedEmail(cachedEmail, with: email)

                    // Update memory cache
                    Task { @MainActor in
                        self.memoryCache[email.id] = email
                    }
                }

                if self.context.hasChanges {
                    try self.context.save()
                }

                Task { @MainActor in
                    self.trimMemoryCacheIfNeeded()
                }

            } catch {
                print("❌ EmailCacheManager: Error in batch save: \(error)")
            }
        }
    }

    /// Merge di nuove email con cache esistente (evita duplicati)
    public func mergeEmails(_ newEmails: [EmailMessage]) -> [EmailMessage] {
        var emailDict = Dictionary(uniqueKeysWithValues: getAllEmails().map { ($0.id, $0) })

        for email in newEmails {
            emailDict[email.id] = email
            saveEmail(email) // Async save
        }

        return Array(emailDict.values).sorted { $0.date > $1.date }
    }

    /// Elimina email da cache
    public func deleteEmail(id: String) {
        // 1. Remove from memory
        memoryCache.removeValue(forKey: id)

        // 2. Mark as deleted in CoreData (soft delete)
        let fetchRequest: NSFetchRequest<CachedEmail> = CachedEmail.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        fetchRequest.fetchLimit = 1

        do {
            if let cachedEmail = try context.fetch(fetchRequest).first {
                cachedEmail.isMarkedAsDeleted = true
                if context.hasChanges {
                    try context.save()
                }
            }
        } catch {
            print("❌ EmailCacheManager: Error deleting: \(error)")
        }
    }

    /// Archivia email
    public func archiveEmail(id: String) {
        // Remove from memory
        memoryCache.removeValue(forKey: id)

        // Mark as archived in CoreData
        let fetchRequest: NSFetchRequest<CachedEmail> = CachedEmail.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        fetchRequest.fetchLimit = 1

        do {
            if let cachedEmail = try context.fetch(fetchRequest).first {
                cachedEmail.isArchived = true
                if context.hasChanges {
                    try context.save()
                }
            }
        } catch {
            print("❌ EmailCacheManager: Error archiving: \(error)")
        }
    }

    /// Invalida cache per account
    public func invalidateCache(for accountEmail: String) {
        memoryCache.removeAll()

        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = CachedEmail.fetchRequest()
        let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        do {
            try context.execute(batchDelete)
            try context.save()
        } catch {
            print("❌ EmailCacheManager: Error invalidating cache: \(error)")
        }
    }

    /// Pulisce cache vecchia (oltre X giorni)
    public func cleanOldCache(olderThan days: Int = 30) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = CachedEmail.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date < %@", cutoffDate as NSDate)

        let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        do {
            try context.execute(batchDelete)
            try context.save()
            print("✅ EmailCacheManager: Cleaned cache older than \(days) days")
        } catch {
            print("❌ EmailCacheManager: Error cleaning old cache: \(error)")
        }
    }

    // MARK: - Private Methods

    private func trimMemoryCacheIfNeeded() {
        guard memoryCache.count > maxMemoryCacheSize else { return }

        // Rimuovi le email più vecchie
        let sorted = memoryCache.values.sorted { $0.date > $1.date }
        let toKeep = Array(sorted.prefix(maxMemoryCacheSize))

        memoryCache = Dictionary(uniqueKeysWithValues: toKeep.map { ($0.id, $0) })
    }

    private func convertToEmailMessage(_ cached: CachedEmail) -> EmailMessage {
        // Parse `to` field (stored as comma-separated string)
        let toArray = cached.to?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []

        return EmailMessage(
            id: cached.id ?? UUID().uuidString,
            from: cached.from ?? "",
            to: toArray,
            subject: cached.subject ?? "",
            body: cached.body ?? "",
            date: cached.date ?? Date(),
            isRead: cached.isRead,
            hasAttachments: cached.hasAttachments,
            category: nil // Category not stored in CoreData yet
        )
    }

    private func updateCachedEmail(_ cached: CachedEmail, with email: EmailMessage) {
        cached.id = email.id
        cached.from = email.from
        cached.to = email.to.joined(separator: ", ") // Store as comma-separated string
        cached.subject = email.subject
        cached.body = email.body
        cached.date = email.date
        cached.isRead = email.isRead
        cached.hasAttachments = email.hasAttachments
        cached.lastUpdated = Date()
        // Note: category field doesn't exist in CachedEmail yet
    }
}
