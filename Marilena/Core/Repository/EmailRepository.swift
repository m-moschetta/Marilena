import Foundation
import CoreData
import Combine

// MARK: - Email Repository Implementation

/// Repository per la gestione delle email con Cache integration
/// Implementa EmailRepositoryProtocol mantenendo compatibilità con sistema esistente
/// EmailMessage è una struct Codable che viene gestita tramite EmailService
@MainActor
public class EmailRepository: EmailRepositoryProtocol {
    
    // MARK: - Properties
    
    private let emailService: EmailService
    private let cacheService: CacheServiceProtocol?
    
    /// Cache key prefix per le email
    private let cacheKeyPrefix = "email_"
    
    /// Cache duration per le email (30 minuti)
    private let cacheDuration: TimeInterval = 30 * 60
    
    // MARK: - Initialization
    
    public init(emailService: EmailService? = nil, cacheService: CacheServiceProtocol? = nil) {
        self.emailService = emailService ?? EmailService()
        self.cacheService = cacheService
        print("📧 EmailRepository: Initialized with EmailService and cache")
    }
    
    // MARK: - RepositoryProtocol Implementation
    
    public func findById(_ id: String) async -> EmailMessage? {
        print("📧 EmailRepository: Finding email by ID: \(id)")
        
        // 1. Try cache first if available
        if let cacheService = cacheService {
            let cacheKey = "\(cacheKeyPrefix)\(id)"
            if let cachedEmail = await cacheService.get(EmailMessage.self, forKey: cacheKey) {
                print("📧 EmailRepository: Found email in cache")
                return cachedEmail
            }
        }
        
        // 2. Search in EmailService emails array
        let email = emailService.emails.first { $0.id == id }
        
        // 3. Cache the result if found
        if let email = email, let cacheService = cacheService {
            let cacheKey = "\(cacheKeyPrefix)\(id)"
            await cacheService.set(email, forKey: cacheKey)
            await cacheService.setExpiration(forKey: cacheKey, expiration: Date().addingTimeInterval(cacheDuration))
        }
        
        print("📧 EmailRepository: Found email in EmailService: \(email != nil)")
        return email
    }
    
    public func findAll() async -> [EmailMessage] {
        print("📧 EmailRepository: Finding all emails")
        
        let allEmails: [EmailMessage] = emailService.emails.sorted { $0.date > $1.date }
        print("📧 EmailRepository: Found \(allEmails.count) emails")
        return allEmails
    }
    
    public func save(_ entity: EmailMessage) async throws {
        print("📧 EmailRepository: Saving email: \(entity.id)")
        
        // Note: EmailMessage is managed by EmailService, this is for cache invalidation
        if let cacheService = cacheService {
            let cacheKey = "\(cacheKeyPrefix)\(entity.id)"
            await cacheService.remove(forKey: cacheKey)
        }
        
        print("✅ EmailRepository: Email cache invalidated")
    }
    
    public func delete(_ entity: EmailMessage) async throws {
        print("📧 EmailRepository: Deleting email: \(entity.id)")
        
        // Note: EmailMessage deletion is managed by EmailService
        // Here we only handle cache invalidation
        if let cacheService = cacheService {
            let cacheKey = "\(cacheKeyPrefix)\(entity.id)"
            await cacheService.remove(forKey: cacheKey)
        }
        
        print("✅ EmailRepository: Email cache invalidated")
    }
    
    public func deleteById(_ id: String) async throws {
        print("📧 EmailRepository: Deleting email by ID: \(id)")
        
        if let email = await findById(id) {
            try await delete(email)
        } else {
            print("⚠️ EmailRepository: Email not found for deletion: \(id)")
        }
    }
    
    // MARK: - EmailRepositoryProtocol Implementation
    
    public func findBySender(_ sender: String) async -> [EmailMessage] {
        print("📧 EmailRepository: Finding emails by sender: \(sender)")
        
        let filteredEmails: [EmailMessage] = emailService.emails.filter { 
            $0.from.lowercased().contains(sender.lowercased()) 
        }
        let results: [EmailMessage] = filteredEmails.sorted { $0.date > $1.date }
        
        print("📧 EmailRepository: Found \(results.count) emails from sender")
        return results
    }
    
    public func findByCategory(_ category: EmailCategory) async -> [EmailMessage] {
        print("📧 EmailRepository: Finding emails by category: \(category.displayName)")
        
        let filteredEmails: [EmailMessage] = emailService.emails.filter { 
            $0.category == category 
        }
        let results: [EmailMessage] = filteredEmails.sorted { $0.date > $1.date }
        
        print("📧 EmailRepository: Found \(results.count) emails in category")
        return results
    }
    
    public func findByDateRange(from: Date, to: Date) async -> [EmailMessage] {
        print("📧 EmailRepository: Finding emails in date range: \(from) to \(to)")
        
        let filteredEmails: [EmailMessage] = emailService.emails.filter { 
            $0.date >= from && $0.date <= to 
        }
        let results: [EmailMessage] = filteredEmails.sorted { $0.date > $1.date }
        
        print("📧 EmailRepository: Found \(results.count) emails in date range")
        return results
    }
    
    public func search(query: String) async -> [EmailMessage] {
        print("📧 EmailRepository: Searching emails with query: \(query)")
        
        let queryLower = query.lowercased()
        let filteredEmails: [EmailMessage] = emailService.emails.filter { email in
            email.subject.lowercased().contains(queryLower) ||
            email.body.lowercased().contains(queryLower) ||
            email.from.lowercased().contains(queryLower)
        }
        let results: [EmailMessage] = filteredEmails.sorted { $0.date > $1.date }
        
        print("📧 EmailRepository: Found \(results.count) emails matching search")
        return results
    }
    
    public func countByCategory(_ category: EmailCategory) async -> Int {
        print("📧 EmailRepository: Counting emails by category: \(category.displayName)")
        
        let count = emailService.emails.filter { $0.category == category }.count
        print("📧 EmailRepository: Found \(count) emails in category")
        return count
    }
    
    // MARK: - Additional Helper Methods
    
    /// Trova email non lette
    public func findUnread() async -> [EmailMessage] {
        print("📧 EmailRepository: Finding unread emails")
        
        let filteredEmails: [EmailMessage] = emailService.emails.filter { !$0.isRead }
        let results: [EmailMessage] = filteredEmails.sorted { $0.date > $1.date }
        print("📧 EmailRepository: Found \(results.count) unread emails")
        return results
    }
    
    /// Trova email importanti/con priorità alta
    public func findHighPriority() async -> [EmailMessage] {
        print("📧 EmailRepository: Finding high priority emails")
        
        // Note: EmailMessage non ha priority, usiamo criteri alternativi
        let filteredEmails: [EmailMessage] = emailService.emails.filter { email in
            // Considera priorità alta: email non lette o con categoria work
            !email.isRead || email.category == .work
        }
        let results: [EmailMessage] = filteredEmails.sorted { $0.date > $1.date }
        
        print("📧 EmailRepository: Found \(results.count) high priority emails")
        return results
    }
    
    /// Batch save per performance improvement
    public func saveBatch(_ emails: [EmailMessage]) async throws {
        print("📧 EmailRepository: Batch saving \(emails.count) emails")
        
        // Note: EmailMessage is managed by EmailService, invalidate cache for all
        if let cacheService = cacheService {
            for email in emails {
                let cacheKey = "\(cacheKeyPrefix)\(email.id)"
                await cacheService.remove(forKey: cacheKey)
            }
        }
        
        print("✅ EmailRepository: Batch cache invalidation completed successfully")
    }
    
    /// Cache warming - precarica email frequentemente accedute
    public func warmCache(for emailIds: [String]) async {
        print("📧 EmailRepository: Warming cache for \(emailIds.count) emails")
        
        guard let cacheService = cacheService else { return }
        
        for emailId in emailIds {
            if let email = await findById(emailId) {
                let cacheKey = "\(cacheKeyPrefix)\(emailId)"
                await cacheService.set(email, forKey: cacheKey)
                await cacheService.setExpiration(forKey: cacheKey, expiration: Date().addingTimeInterval(cacheDuration))
            }
        }
        
        print("✅ EmailRepository: Cache warming completed")
    }
}