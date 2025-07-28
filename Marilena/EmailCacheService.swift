import Foundation
import CoreData
import Combine

// MARK: - Email Cache Service
// Servizio per la gestione della cache locale delle email con CoreData

@MainActor
public class EmailCacheService: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var cachedEmails: [EmailMessage] = []
    @Published public var isLoading = false
    @Published public var error: String?
    
    // MARK: - Private Properties
    private let persistenceController: PersistenceController?
    private let maxCacheSize = 20
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(persistenceController: PersistenceController? = nil) {
        self.persistenceController = persistenceController ?? PersistenceController.shared
        
        // Verifica se CoreData funziona, altrimenti disabilita la cache
        if persistenceController?.container.persistentStoreCoordinator.persistentStores.isEmpty ?? true {
            print("⚠️ CoreData: Nessun persistent store disponibile, disabilito la cache")
            self.cachedEmails = []
        } else {
            loadCachedEmails()
        }
    }
    
    // MARK: - Public Methods
    
    /// Salva le email nella cache locale
    public func cacheEmails(_ emails: [EmailMessage], for accountId: String) async {
        isLoading = true
        error = nil
        
        do {
            let context = persistenceController?.container.viewContext
            
            // Rimuovi email vecchie se superiamo il limite
            await cleanupOldEmails(in: context, accountId: accountId)
            
            // Salva le nuove email
            for email in emails {
                await saveEmailToCache(email, accountId: accountId, in: context)
            }
            
            // Salva il contesto
            try context?.save()
            
            // Ricarica dalla cache
            loadCachedEmails()
            
            print("✅ EmailCacheService: Salvate \(emails.count) email in cache")
            
        } catch {
            print("❌ EmailCacheService Error nel salvataggio cache: \(error)")
            // Non bloccare l'app se la cache non funziona
            self.error = nil
        }
        
        isLoading = false
    }
    
    /// Marca un'email come letta nella cache e nel server
    public func markEmailAsRead(_ emailId: String, accountId: String) async {
        // Aggiorna cache locale
        await updateEmailReadStatus(emailId: emailId, isRead: true, accountId: accountId)
        
        // Comunica al server
        await notifyServerEmailRead(emailId: emailId, accountId: accountId)
        
        // Ricarica dalla cache
        loadCachedEmails()
        
        print("✅ EmailCacheService: Email \(emailId) marcata come letta")
    }
    
    /// Ottiene le email dalla cache
    public func getCachedEmails(for accountId: String? = nil) -> [EmailMessage] {
        return cachedEmails
    }
    
    /// Pulisce la cache per un account specifico
    public func clearCache(for accountId: String) async {
        do {
            let context = persistenceController?.container.viewContext
            let request: NSFetchRequest<CachedEmail> = CachedEmail.fetchRequest()
            request.predicate = NSPredicate(format: "accountId == %@", accountId)
            
            let cachedEmails = try context?.fetch(request)
            
            for cachedEmail in cachedEmails ?? [] {
                context?.delete(cachedEmail)
            }
            
            try context?.save()
            loadCachedEmails()
            
            print("✅ EmailCacheService: Cache pulita per account \(accountId)")
            
        } catch {
            self.error = "Errore nella pulizia cache: \(error.localizedDescription)"
            print("❌ EmailCacheService Error: \(error)")
        }
    }
    
    // MARK: - Delete Email
    
    func deleteEmail(_ emailId: String) async {
        guard let context = persistenceController?.container.viewContext else { return }
        
        let fetchRequest: NSFetchRequest<CachedEmail> = CachedEmail.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", emailId)
        
        do {
            let emails = try context.fetch(fetchRequest)
            for email in emails {
                email.isMarkedAsDeleted = true
            }
            
            try context.save()
            print("🗑️ EmailCacheService: Email \(emailId) marcata come eliminata")
        } catch {
            print("❌ EmailCacheService: Errore eliminazione email dalla cache: \(error)")
        }
    }
    
    // MARK: - Archive Email
    
    func archiveEmail(_ emailId: String) async {
        guard let context = persistenceController?.container.viewContext else { return }
        
        let fetchRequest: NSFetchRequest<CachedEmail> = CachedEmail.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", emailId)
        
        do {
            let emails = try context.fetch(fetchRequest)
            for email in emails {
                email.isArchived = true
            }
            
            try context.save()
            print("📦 EmailCacheService: Email \(emailId) archiviata")
        } catch {
            print("❌ EmailCacheService: Errore archiviazione email nella cache: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func loadCachedEmails() {
        do {
            let context = persistenceController?.container.viewContext
            let request: NSFetchRequest<CachedEmail> = CachedEmail.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            
            let cachedEmails = try context?.fetch(request)
            
            self.cachedEmails = cachedEmails?.compactMap { cachedEmail in
                guard let id = cachedEmail.id,
                      let from = cachedEmail.from,
                      let subject = cachedEmail.subject,
                      let body = cachedEmail.body,
                      let date = cachedEmail.date else {
                    return nil
                }
                
                return EmailMessage(
                    id: id,
                    from: from,
                    to: cachedEmail.to?.components(separatedBy: ",") ?? [],
                    subject: subject,
                    body: body,
                    date: date,
                    isRead: cachedEmail.isRead,
                    hasAttachments: cachedEmail.hasAttachments,
                    emailType: EmailType(rawValue: cachedEmail.emailType ?? "received") ?? .received
                )
            } ?? []
            
            print("📧 EmailCacheService: Caricate \(self.cachedEmails.count) email dalla cache")
            
        } catch {
            print("❌ EmailCacheService Error nel caricamento cache: \(error)")
            // Non bloccare l'app se la cache non funziona
            self.cachedEmails = []
            self.error = nil // Non mostrare errori di cache all'utente
        }
    }
    
    private func saveEmailToCache(_ email: EmailMessage, accountId: String, in context: NSManagedObjectContext?) async {
        guard let context = context else { return }
        
        // Verifica se l'email esiste già
        let request: NSFetchRequest<CachedEmail> = CachedEmail.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ AND accountId == %@", email.id, accountId)
        
        do {
            let existingEmails = try context.fetch(request)
            
            if let existingEmail = existingEmails.first {
                // Aggiorna email esistente
                existingEmail.from = email.from
                existingEmail.to = email.to.joined(separator: ",")
                existingEmail.subject = email.subject
                existingEmail.body = email.body
                existingEmail.date = email.date
                existingEmail.isRead = email.isRead
                existingEmail.hasAttachments = email.hasAttachments
                existingEmail.emailType = email.emailType.rawValue
                existingEmail.lastUpdated = Date()
            } else {
                // Crea nuova email in cache
                let cachedEmail = CachedEmail(context: context)
                cachedEmail.id = email.id
                cachedEmail.from = email.from
                cachedEmail.to = email.to.joined(separator: ",")
                cachedEmail.subject = email.subject
                cachedEmail.body = email.body
                cachedEmail.date = email.date
                cachedEmail.isRead = email.isRead
                cachedEmail.hasAttachments = email.hasAttachments
                cachedEmail.emailType = email.emailType.rawValue
                cachedEmail.accountId = accountId
                cachedEmail.createdAt = Date()
                cachedEmail.lastUpdated = Date()
            }
            
        } catch {
            print("❌ EmailCacheService Error: Errore nel salvataggio email \(email.id): \(error)")
        }
    }
    
    private func cleanupOldEmails(in context: NSManagedObjectContext?, accountId: String) async {
        do {
            let request: NSFetchRequest<CachedEmail> = CachedEmail.fetchRequest()
            request.predicate = NSPredicate(format: "accountId == %@", accountId)
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            
            let cachedEmails = try context?.fetch(request)
            
            if cachedEmails?.count ?? 0 > maxCacheSize {
                let emailsToDelete = Array(cachedEmails?.suffix(from: maxCacheSize) ?? [])
                
                for email in emailsToDelete {
                    context?.delete(email)
                }
                
                print("��️ EmailCacheService: Rimosse \(emailsToDelete.count) email vecchie dalla cache")
            }
            
        } catch {
            print("❌ EmailCacheService Error: Errore nella pulizia cache: \(error)")
        }
    }
    
    private func updateEmailReadStatus(emailId: String, isRead: Bool, accountId: String) async {
        do {
            let context = persistenceController?.container.viewContext
            let request: NSFetchRequest<CachedEmail> = CachedEmail.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@ AND accountId == %@", emailId, accountId)
            
            let cachedEmails = try context?.fetch(request)
            
            if let cachedEmail = cachedEmails?.first {
                cachedEmail.isRead = isRead
                cachedEmail.lastUpdated = Date()
                try context?.save()
            }
            
        } catch {
            print("❌ EmailCacheService Error: Errore nell'aggiornamento stato email: \(error)")
        }
    }
    
    private func notifyServerEmailRead(emailId: String, accountId: String) async {
        // La comunicazione con il server è ora gestita da EmailService
        // che chiama direttamente le API di Gmail e Microsoft Graph
        print("📡 EmailCacheService: Email \(emailId) marcata come letta - comunicazione server gestita da EmailService")
    }
}

// MARK: - CoreData Stack (Unificato con PersistenceController)
// Ora EmailCacheService usa PersistenceController.shared invece di CoreDataStack 