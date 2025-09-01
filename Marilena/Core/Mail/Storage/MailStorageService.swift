import Foundation
import CoreData
import Combine

/// Servizio per la gestione dello storage dei dati email
public class MailStorageService {
    public static let shared = MailStorageService()

    private let persistenceController = PersistenceController.shared
    private let context: NSManagedObjectContext

    private init() {
        self.context = persistenceController.container.viewContext
    }

    // MARK: - Message Operations

    /// Salva un messaggio nel database
    public func saveMessage(_ message: MailMessage) async throws {
        try await context.perform {
            // Cerca se il messaggio esiste già
            let fetchRequest: NSFetchRequest<CachedEmail> = CachedEmail.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@ AND providerId == %@", message.id, message.providerId)

            let existingMessages = try self.context.fetch(fetchRequest)

            if let existingMessage = existingMessages.first {
                // Aggiorna il messaggio esistente
                self.updateCachedEmail(existingMessage, with: message)
            } else {
                // Crea un nuovo messaggio
                let cachedEmail = CachedEmail(context: self.context)
                cachedEmail.id = message.id
                cachedEmail.providerId = message.providerId
                cachedEmail.threadId = message.threadId
                cachedEmail.subject = message.subject
                cachedEmail.bodyPlain = message.bodyPlain
                cachedEmail.bodyHTML = message.bodyHTML
                cachedEmail.snippet = message.snippet
                cachedEmail.fromEmail = message.from.email
                cachedEmail.fromName = message.from.name
                cachedEmail.date = message.date
                cachedEmail.labels = message.labels.joined(separator: ",")
                cachedEmail.isRead = message.flags.isRead
                cachedEmail.isStarred = message.flags.isStarred
                cachedEmail.isDeleted = message.flags.isDeleted
                cachedEmail.isDraft = message.flags.isDraft
                cachedEmail.isAnswered = message.flags.isAnswered
                cachedEmail.isForwarded = message.flags.isForwarded
                cachedEmail.size = Int64(message.size)
                cachedEmail.accountId = message.providerId // Per ora usiamo providerId come accountId
            }

            try self.context.save()
        }
    }

    /// Recupera messaggi per account
    public func fetchMessages(for accountId: String, limit: Int = 100) async throws -> [MailMessage] {
        try await context.perform {
            let fetchRequest: NSFetchRequest<CachedEmail> = CachedEmail.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "accountId == %@", accountId)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            fetchRequest.fetchLimit = limit

            let cachedEmails = try self.context.fetch(fetchRequest)
            return cachedEmails.compactMap { self.mailMessage(from: $0) }
        }
    }

    /// Recupera un messaggio specifico
    public func fetchMessage(id: String, accountId: String) async throws -> MailMessage? {
        try await context.perform {
            let fetchRequest: NSFetchRequest<CachedEmail> = CachedEmail.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@ AND accountId == %@", id, accountId)

            let cachedEmails = try self.context.fetch(fetchRequest)
            return cachedEmails.first.flatMap { self.mailMessage(from: $0) }
        }
    }

    /// Elimina un messaggio
    public func deleteMessage(id: String, accountId: String) async throws {
        try await context.perform {
            let fetchRequest: NSFetchRequest<CachedEmail> = CachedEmail.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@ AND accountId == %@", id, accountId)

            let cachedEmails = try self.context.fetch(fetchRequest)
            for email in cachedEmails {
                self.context.delete(email)
            }

            try self.context.save()
        }
    }

    /// Marca messaggio come letto
    public func markMessageAsRead(id: String, accountId: String, isRead: Bool) async throws {
        try await context.perform {
            let fetchRequest: NSFetchRequest<CachedEmail> = CachedEmail.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@ AND accountId == %@", id, accountId)

            let cachedEmails = try self.context.fetch(fetchRequest)
            for email in cachedEmails {
                email.isRead = isRead
            }

            try self.context.save()
        }
    }

    // MARK: - Thread Operations

    /// Salva un thread
    public func saveThread(_ thread: MailThread) async throws {
        try await context.perform {
            // Cerca se il thread esiste già
            let fetchRequest: NSFetchRequest<EmailThread> = EmailThread.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@ AND providerId == %@", thread.id, thread.providerId)

            let existingThreads = try self.context.fetch(fetchRequest)

            if let existingThread = existingThreads.first {
                // Aggiorna il thread esistente
                self.updateEmailThread(existingThread, with: thread)
            } else {
                // Crea un nuovo thread
                let emailThread = EmailThread(context: self.context)
                emailThread.id = thread.id
                emailThread.subject = thread.subject
                emailThread.participants = try JSONEncoder().encode(thread.participants)
                emailThread.messageIds = thread.messageIds.joined(separator: ",")
                emailThread.labels = Array(thread.labels).joined(separator: ",")
                emailThread.createdAt = thread.createdAt
                emailThread.lastActivity = thread.lastActivity
                emailThread.providerId = thread.providerId
                emailThread.unreadCount = Int64(thread.unreadCount)
                emailThread.totalCount = Int64(thread.totalCount)
            }

            try self.context.save()
        }
    }

    /// Recupera thread per account
    public func fetchThreads(for accountId: String, limit: Int = 50) async throws -> [MailThread] {
        try await context.perform {
            let fetchRequest: NSFetchRequest<EmailThread> = EmailThread.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "providerId == %@", accountId)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "lastActivity", ascending: false)]
            fetchRequest.fetchLimit = limit

            let emailThreads = try self.context.fetch(fetchRequest)
            return emailThreads.compactMap { try? self.mailThread(from: $0) }
        }
    }

    // MARK: - Label Operations

    /// Salva una label
    public func saveLabel(_ label: MailLabel) async throws {
        try await context.perform {
            // Cerca se la label esiste già
            let fetchRequest: NSFetchRequest<EmailLabel> = EmailLabel.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", label.id)

            let existingLabels = try self.context.fetch(fetchRequest)

            if let existingLabel = existingLabels.first {
                // Aggiorna la label esistente
                existingLabel.name = label.name
                existingLabel.type = label.type.rawValue
                existingLabel.colorHex = label.colorHex
                existingLabel.parentId = label.parentId
                existingLabel.providerMapping = try JSONEncoder().encode(label.providerMapping)
                existingLabel.isVisible = label.isVisible
                existingLabel.messageCount = Int64(label.messageCount)
            } else {
                // Crea una nuova label
                let emailLabel = EmailLabel(context: self.context)
                emailLabel.id = label.id
                emailLabel.name = label.name
                emailLabel.type = label.type.rawValue
                emailLabel.colorHex = label.colorHex
                emailLabel.parentId = label.parentId
                emailLabel.providerMapping = try JSONEncoder().encode(label.providerMapping)
                emailLabel.isVisible = label.isVisible
                emailLabel.messageCount = Int64(label.messageCount)
            }

            try self.context.save()
        }
    }

    /// Recupera tutte le label
    public func fetchLabels() async throws -> [MailLabel] {
        try await context.perform {
            let fetchRequest: NSFetchRequest<EmailLabel> = EmailLabel.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            let emailLabels = try self.context.fetch(fetchRequest)
            return emailLabels.compactMap { self.mailLabel(from: $0) }
        }
    }

    // MARK: - Filter Rule Operations

    /// Salva una regola di filtro
    public func saveFilterRule(_ rule: MailFilterRule) async throws {
        try await context.perform {
            let fetchRequest: NSFetchRequest<EmailFilterRule> = EmailFilterRule.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", rule.id)

            let existingRules = try self.context.fetch(fetchRequest)

            if let existingRule = existingRules.first {
                // Aggiorna la regola esistente
                self.updateEmailFilterRule(existingRule, with: rule)
            } else {
                // Crea una nuova regola
                let emailFilterRule = EmailFilterRule(context: self.context)
                self.updateEmailFilterRule(emailFilterRule, with: rule)
                emailFilterRule.id = rule.id
            }

            try self.context.save()
        }
    }

    /// Recupera tutte le regole di filtro
    public func fetchFilterRules() async throws -> [MailFilterRule] {
        try await context.perform {
            let fetchRequest: NSFetchRequest<EmailFilterRule> = EmailFilterRule.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "priority", ascending: false)]

            let emailFilterRules = try self.context.fetch(fetchRequest)
            return emailFilterRules.compactMap { try? self.mailFilterRule(from: $0) }
        }
    }

    // MARK: - Sync State Operations

    /// Salva lo stato di sincronizzazione
    public func saveSyncState(_ syncState: MailSyncState) async throws {
        try await context.perform {
            let fetchRequest: NSFetchRequest<EmailSyncState> = EmailSyncState.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "accountId == %@", syncState.accountId)

            let existingStates = try self.context.fetch(fetchRequest)

            if let existingState = existingStates.first {
                // Aggiorna lo stato esistente
                self.updateEmailSyncState(existingState, with: syncState)
            } else {
                // Crea un nuovo stato
                let emailSyncState = EmailSyncState(context: self.context)
                self.updateEmailSyncState(emailSyncState, with: syncState)
                emailSyncState.id = syncState.id
            }

            try self.context.save()
        }
    }

    /// Recupera lo stato di sincronizzazione per account
    public func fetchSyncState(for accountId: String) async throws -> MailSyncState? {
        try await context.perform {
            let fetchRequest: NSFetchRequest<EmailSyncState> = EmailSyncState.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "accountId == %@", accountId)

            let emailSyncStates = try self.context.fetch(fetchRequest)
            return emailSyncStates.first.flatMap { self.mailSyncState(from: $0) }
        }
    }

    // MARK: - Utility Methods

    private func mailMessage(from cachedEmail: CachedEmail) -> MailMessage? {
        guard let id = cachedEmail.id,
              let providerId = cachedEmail.providerId,
              let subject = cachedEmail.subject,
              let snippet = cachedEmail.snippet,
              let fromEmail = cachedEmail.fromEmail,
              let date = cachedEmail.date else {
            return nil
        }

        let from = MailParticipant(email: fromEmail, name: cachedEmail.fromName)
        let to = [] // Per ora semplificato
        let cc = []
        let bcc = []

        let flags = MailMessageFlags(
            isRead: cachedEmail.isRead,
            isStarred: cachedEmail.isStarred,
            isDeleted: cachedEmail.isDeleted,
            isDraft: cachedEmail.isDraft,
            isAnswered: cachedEmail.isAnswered,
            isForwarded: cachedEmail.isForwarded
        )

        let labels = (cachedEmail.labels ?? "").components(separatedBy: ",").filter { !$0.isEmpty }
        let attachments = [] // Per ora semplificato

        return MailMessage(
            id: id,
            threadId: cachedEmail.threadId,
            subject: subject,
            bodyPlain: cachedEmail.bodyPlain,
            bodyHTML: cachedEmail.bodyHTML,
            snippet: snippet,
            from: from,
            to: to,
            cc: cc,
            bcc: bcc,
            date: date,
            labels: labels,
            flags: flags,
            attachments: attachments,
            providerId: providerId,
            size: Int(cachedEmail.size)
        )
    }

    private func mailThread(from emailThread: EmailThread) throws -> MailThread {
        guard let id = emailThread.id,
              let subject = emailThread.subject,
              let participantsData = emailThread.participants,
              let messageIdsString = emailThread.messageIds,
              let labelsString = emailThread.labels,
              let createdAt = emailThread.createdAt,
              let lastActivity = emailThread.lastActivity,
              let providerId = emailThread.providerId else {
            throw NSError(domain: "MailStorageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid thread data"])
        }

        let participants = try JSONDecoder().decode(Set<MailParticipant>.self, from: participantsData)
        let messageIds = messageIdsString.components(separatedBy: ",")
        let labels = Set(labelsString.components(separatedBy: ","))

        return MailThread(
            id: id,
            subject: subject,
            participants: participants,
            messageIds: messageIds,
            labels: labels,
            createdAt: createdAt,
            lastActivity: lastActivity,
            providerId: providerId,
            unreadCount: Int(emailThread.unreadCount),
            totalCount: Int(emailThread.totalCount)
        )
    }

    private func mailLabel(from emailLabel: EmailLabel) -> MailLabel? {
        guard let id = emailLabel.id,
              let name = emailLabel.name,
              let typeString = emailLabel.type,
              let type = MailLabelType(rawValue: typeString) else {
            return nil
        }

        return MailLabel(
            id: id,
            name: name,
            type: type,
            colorHex: emailLabel.colorHex,
            parentId: emailLabel.parentId,
            providerMapping: (try? JSONDecoder().decode([String: String].self, from: emailLabel.providerMapping ?? Data())) ?? [:],
            isVisible: emailLabel.isVisible,
            messageCount: Int(emailLabel.messageCount)
        )
    }

    private func mailFilterRule(from emailFilterRule: EmailFilterRule) throws -> MailFilterRule {
        // Implementazione semplificata - in produzione servirebbe una conversione completa
        return MailFilterRule(
            id: emailFilterRule.id ?? UUID().uuidString,
            name: emailFilterRule.name ?? "",
            conditions: [], // Semplificato
            actions: [],    // Semplificato
            priority: Int(emailFilterRule.priority),
            isEnabled: emailFilterRule.isEnabled
        )
    }

    private func mailSyncState(from emailSyncState: EmailSyncState) -> MailSyncState? {
        guard let id = emailSyncState.id,
              let accountId = emailSyncState.accountId,
              let providerId = emailSyncState.providerId else {
            return nil
        }

        return MailSyncState(
            id: id,
            accountId: accountId,
            providerId: providerId,
            historyId: emailSyncState.historyId,
            etag: emailSyncState.etag,
            lastMessageId: emailSyncState.lastMessageId,
            lastFullSync: emailSyncState.lastFullSync,
            lastIncrementalSync: emailSyncState.lastIncrementalSync,
            lastErrorAt: emailSyncState.lastErrorAt,
            messagesSynced: Int(emailSyncState.messagesSynced),
            errorsCount: Int(emailSyncState.errorsCount),
            consecutiveErrors: Int(emailSyncState.consecutiveErrors),
            isSyncing: emailSyncState.isSyncing,
            syncStatus: emailSyncState.syncStatus.flatMap { MailSyncStatus(rawValue: $0) } ?? .idle
        )
    }

    private func updateCachedEmail(_ cachedEmail: CachedEmail, with message: MailMessage) {
        cachedEmail.threadId = message.threadId
        cachedEmail.subject = message.subject
        cachedEmail.bodyPlain = message.bodyPlain
        cachedEmail.bodyHTML = message.bodyHTML
        cachedEmail.snippet = message.snippet
        cachedEmail.fromEmail = message.from.email
        cachedEmail.fromName = message.from.name
        cachedEmail.date = message.date
        cachedEmail.labels = message.labels.joined(separator: ",")
        cachedEmail.isRead = message.flags.isRead
        cachedEmail.isStarred = message.flags.isStarred
        cachedEmail.isDeleted = message.flags.isDeleted
        cachedEmail.isDraft = message.flags.isDraft
        cachedEmail.isAnswered = message.flags.isAnswered
        cachedEmail.isForwarded = message.flags.isForwarded
        cachedEmail.size = Int64(message.size)
    }

    private func updateEmailThread(_ emailThread: EmailThread, with thread: MailThread) {
        emailThread.subject = thread.subject
        emailThread.participants = (try? JSONEncoder().encode(thread.participants)) ?? Data()
        emailThread.messageIds = thread.messageIds.joined(separator: ",")
        emailThread.labels = Array(thread.labels).joined(separator: ",")
        emailThread.lastActivity = thread.lastActivity
        emailThread.unreadCount = Int64(thread.unreadCount)
        emailThread.totalCount = Int64(thread.totalCount)
    }

    private func updateEmailFilterRule(_ emailFilterRule: EmailFilterRule, with rule: MailFilterRule) {
        emailFilterRule.name = rule.name
        // Implementazione semplificata per le conditions e actions
        emailFilterRule.priority = Int64(rule.priority)
        emailFilterRule.isEnabled = rule.isEnabled
        emailFilterRule.createdAt = rule.createdAt
        emailFilterRule.lastTriggeredAt = rule.lastTriggeredAt
        emailFilterRule.triggerCount = Int64(rule.triggerCount)
    }

    private func updateEmailSyncState(_ emailSyncState: EmailSyncState, with syncState: MailSyncState) {
        emailSyncState.accountId = syncState.accountId
        emailSyncState.providerId = syncState.providerId
        emailSyncState.historyId = syncState.historyId
        emailSyncState.etag = syncState.etag
        emailSyncState.lastMessageId = syncState.lastMessageId
        emailSyncState.lastFullSync = syncState.lastFullSync
        emailSyncState.lastIncrementalSync = syncState.lastIncrementalSync
        emailSyncState.lastErrorAt = syncState.lastErrorAt
        emailSyncState.messagesSynced = Int64(syncState.messagesSynced)
        emailSyncState.errorsCount = Int64(syncState.errorsCount)
        emailSyncState.consecutiveErrors = Int64(syncState.consecutiveErrors)
        emailSyncState.isSyncing = syncState.isSyncing
        emailSyncState.syncStatus = syncState.syncStatus.rawValue
    }
}
