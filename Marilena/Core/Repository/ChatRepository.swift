import Foundation
import CoreData
import Combine

// MARK: - Chat Repository Implementation

/// Repository per la gestione delle chat con supporto email-chat preservation
/// Implementa ChatRepositoryProtocol mantenendo compatibilità totale con sistema esistente
@MainActor
public class ChatRepository: ChatRepositoryProtocol {
    
    // MARK: - Properties
    
    private let context: NSManagedObjectContext
    private let cacheService: CacheServiceProtocol?
    
    /// Cache key prefix per le chat
    private let cacheKeyPrefix = "chat_"
    
    /// Cache duration per le chat (1 ora)
    private let cacheDuration: TimeInterval = 60 * 60
    
    // MARK: - Initialization
    
    public init(context: NSManagedObjectContext? = nil, cacheService: CacheServiceProtocol? = nil) {
        self.context = context ?? PersistenceController.shared.container.viewContext
        self.cacheService = cacheService
        print("💬 ChatRepository: Initialized with context and cache")
    }
    
    // MARK: - RepositoryProtocol Implementation
    
    public func findById(_ id: UUID) async -> ChatMarilena? {
        print("💬 ChatRepository: Finding chat by ID: \(id)")
        
        // Note: CoreData entities non sono Codable, usiamo solo CoreData cache
        
        // 2. Fetch from CoreData
        let fetchRequest: NSFetchRequest<ChatMarilena> = ChatMarilena.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            let chat = results.first
            
            print("💬 ChatRepository: Found chat in CoreData: \(chat != nil)")
            return chat
        } catch {
            print("❌ ChatRepository: Error finding chat by ID: \(error)")
            return nil
        }
    }
    
    public func findAll() async -> [ChatMarilena] {
        print("💬 ChatRepository: Finding all chats")
        
        let fetchRequest: NSFetchRequest<ChatMarilena> = ChatMarilena.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "dataCreazione", ascending: false)]
        
        do {
            let results = try context.fetch(fetchRequest)
            print("💬 ChatRepository: Found \(results.count) chats")
            return results
        } catch {
            print("❌ ChatRepository: Error finding all chats: \(error)")
            return []
        }
    }
    
    public func save(_ entity: ChatMarilena) async throws {
        print("💬 ChatRepository: Saving chat: \(entity.id?.uuidString ?? "unknown")")
        
        do {
            try context.save()
            print("✅ ChatRepository: Chat saved successfully")
        } catch {
            print("❌ ChatRepository: Error saving chat: \(error)")
            throw error
        }
    }
    
    public func delete(_ entity: ChatMarilena) async throws {
        print("💬 ChatRepository: Deleting chat: \(entity.id?.uuidString ?? "unknown")")
        
        let chatId = entity.id
        context.delete(entity)
        
        do {
            try context.save()
            print("✅ ChatRepository: Chat deleted successfully")
        } catch {
            print("❌ ChatRepository: Error deleting chat: \(error)")
            throw error
        }
    }
    
    public func deleteById(_ id: UUID) async throws {
        print("💬 ChatRepository: Deleting chat by ID: \(id)")
        
        if let chat = await findById(id) {
            try await delete(chat)
        } else {
            print("⚠️ ChatRepository: Chat not found for deletion: \(id)")
        }
    }
    
    // MARK: - ChatRepositoryProtocol Implementation
    
    public func findByType(_ type: String) async -> [ChatMarilena] {
        print("💬 ChatRepository: Finding chats by type: \(type)")
        
        let fetchRequest: NSFetchRequest<ChatMarilena> = ChatMarilena.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "tipo == %@", type)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "dataCreazione", ascending: false)]
        
        do {
            let results = try context.fetch(fetchRequest)
            print("💬 ChatRepository: Found \(results.count) chats of type \(type)")
            return results
        } catch {
            print("❌ ChatRepository: Error finding chats by type: \(error)")
            return []
        }
    }
    
    public func findEmailChatBySender(_ sender: String) async -> ChatMarilena? {
        print("💬 ChatRepository: Finding email chat by sender: \(sender)")
        
        let fetchRequest: NSFetchRequest<ChatMarilena> = ChatMarilena.fetchRequest()
        
        // Cerca chat email per questo mittente specifico
        let typePredicate = NSPredicate(format: "tipo == %@", "email")
        let senderPredicate = NSPredicate(format: "emailSender == %@", sender)
        
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            typePredicate, senderPredicate
        ])
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "lastEmailDate", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            let chat = results.first
            print("💬 ChatRepository: Found email chat for sender: \(chat != nil)")
            return chat
        } catch {
            print("❌ ChatRepository: Error finding email chat by sender: \(error)")
            return nil
        }
    }
    
    public func findRecent(limit: Int) async -> [ChatMarilena] {
        print("💬 ChatRepository: Finding \(limit) recent chats")
        
        let fetchRequest: NSFetchRequest<ChatMarilena> = ChatMarilena.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "dataCreazione", ascending: false)]
        fetchRequest.fetchLimit = limit
        
        do {
            let results = try context.fetch(fetchRequest)
            print("💬 ChatRepository: Found \(results.count) recent chats")
            return results
        } catch {
            print("❌ ChatRepository: Error finding recent chats: \(error)")
            return []
        }
    }
    
    public func countMessages(for chat: ChatMarilena) async -> Int {
        print("💬 ChatRepository: Counting messages for chat: \(chat.id?.uuidString ?? "unknown")")
        
        guard let chatId = chat.id else {
            print("⚠️ ChatRepository: Chat has no ID, cannot count messages")
            return 0
        }
        
        let fetchRequest: NSFetchRequest<MessaggioMarilena> = MessaggioMarilena.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "chat.id == %@", chatId as CVarArg)
        
        do {
            let count = try context.count(for: fetchRequest)
            print("💬 ChatRepository: Found \(count) messages in chat")
            return count
        } catch {
            print("❌ ChatRepository: Error counting messages: \(error)")
            return 0
        }
    }
    
    // MARK: - Additional Helper Methods (Email-Chat Support)
    
    /// Trova tutte le chat email attive
    public func findAllEmailChats() async -> [ChatMarilena] {
        print("💬 ChatRepository: Finding all email chats")
        
        return await findByType("email")
    }
    
    /// Trova chat email per thread ID
    public func findEmailChatByThreadId(_ threadId: String) async -> ChatMarilena? {
        print("💬 ChatRepository: Finding email chat by thread ID: \(threadId)")
        
        let fetchRequest: NSFetchRequest<ChatMarilena> = ChatMarilena.fetchRequest()
        
        let typePredicate = NSPredicate(format: "tipo == %@", "email")
        let threadPredicate = NSPredicate(format: "emailThreadId == %@", threadId)
        
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            typePredicate, threadPredicate
        ])
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            let chat = results.first
            print("💬 ChatRepository: Found email chat for thread: \(chat != nil)")
            return chat
        } catch {
            print("❌ ChatRepository: Error finding email chat by thread: \(error)")
            return nil
        }
    }
    
    /// Trova chat con messaggi non letti
    public func findChatsWithUnreadMessages() async -> [ChatMarilena] {
        print("💬 ChatRepository: Finding chats with unread messages")
        
        let fetchRequest: NSFetchRequest<ChatMarilena> = ChatMarilena.fetchRequest()
        
        // Trova chat che hanno messaggi con isRead = false
        fetchRequest.predicate = NSPredicate(format: "ANY messaggi.isRead == NO")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "dataCreazione", ascending: false)]
        
        do {
            let results = try context.fetch(fetchRequest)
            print("💬 ChatRepository: Found \(results.count) chats with unread messages")
            return results
        } catch {
            print("❌ ChatRepository: Error finding chats with unread messages: \(error)")
            return []
        }
    }
    
    /// Aggiorna ultima data email per chat email
    public func updateLastEmailDate(_ chat: ChatMarilena, date: Date) async throws {
        print("💬 ChatRepository: Updating last email date for chat: \(chat.id?.uuidString ?? "unknown")")
        
        chat.lastEmailDate = date
        
        do {
            try await save(chat)
            print("✅ ChatRepository: Last email date updated successfully")
        } catch {
            print("❌ ChatRepository: Error updating last email date: \(error)")
            throw error
        }
    }
    
    /// Batch operations per performance
    public func saveBatch(_ chats: [ChatMarilena]) async throws {
        print("💬 ChatRepository: Batch saving \(chats.count) chats")
        
        do {
            try context.save()
            print("✅ ChatRepository: Batch save completed successfully")
        } catch {
            print("❌ ChatRepository: Error in batch save: \(error)")
            throw error
        }
    }
    
    /// Note: CoreData has its own caching mechanism, no additional warming needed
    
    /// Supporto per statistiche email-chat system
    public func getEmailChatStats() async -> (totalEmailChats: Int, activeThreads: Int, unreadMessages: Int) {
        print("💬 ChatRepository: Getting email chat statistics")
        
        let emailChats = await findAllEmailChats()
        let unreadChats = await findChatsWithUnreadMessages()
        
        // Conta thread unici
        let uniqueThreads = Set(emailChats.compactMap { $0.emailThreadId })
        
        let stats = (
            totalEmailChats: emailChats.count,
            activeThreads: uniqueThreads.count,
            unreadMessages: unreadChats.count
        )
        
        print("💬 ChatRepository: Stats - Total: \(stats.totalEmailChats), Threads: \(stats.activeThreads), Unread: \(stats.unreadMessages)")
        return stats
    }
}