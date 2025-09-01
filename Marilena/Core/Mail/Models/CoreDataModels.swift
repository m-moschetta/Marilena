import Foundation
import CoreData

// MARK: - Core Data Models for Mail System
// Questi modelli estendono quelli esistenti nel sistema per supportare il nuovo sistema email

extension CachedEmail {
    // Estensioni per il nuovo sistema email
    // Questi metodi aiutano la conversione tra i modelli legacy e quelli nuovi
}

extension ChatMarilena {
    // Estensioni per l'integrazione email-chat
}

// MARK: - Nuovi modelli Core Data necessari
// Questi sono i modelli che dobbiamo aggiungere al .xcdatamodeld

/*
Nel file .xcdatamodeld dobbiamo aggiungere queste entità:

1. EmailThread
   - id: String
   - subject: String
   - participants: Data (JSON encoded Set<MailParticipant>)
   - messageIds: String (comma-separated)
   - labels: String (comma-separated)
   - createdAt: Date
   - lastActivity: Date
   - providerId: String
   - unreadCount: Int64
   - totalCount: Int64

2. EmailLabel
   - id: String
   - name: String
   - type: String
   - colorHex: String (optional)
   - parentId: String (optional)
   - providerMapping: Data (JSON encoded [String: String])
   - isVisible: Bool
   - messageCount: Int64

3. EmailFilterRule
   - id: String
   - name: String
   - conditions: Data (JSON encoded [MailFilterCondition])
   - actions: Data (JSON encoded [MailFilterAction])
   - priority: Int64
   - isEnabled: Bool
   - createdAt: Date
   - lastTriggeredAt: Date (optional)
   - triggerCount: Int64

4. EmailSyncState
   - id: String
   - accountId: String
   - providerId: String
   - historyId: String (optional)
   - etag: String (optional)
   - lastMessageId: String (optional)
   - lastFullSync: Date (optional)
   - lastIncrementalSync: Date (optional)
   - lastErrorAt: Date (optional)
   - messagesSynced: Int64
   - errorsCount: Int64
   - consecutiveErrors: Int64
   - isSyncing: Bool
   - syncStatus: String

5. CalendarInteraction
   - id: String
   - participantEmail: String
   - events: Data (JSON encoded [MailCalendarEvent])
   - recordings: Data (JSON encoded [MailRecordingInfo])
   - lastContactedAt: Date
   - totalInteractions: Int64
*/

// MARK: - Convenience Extensions

extension NSManagedObjectContext {
    func performAndWait<T>(_ block: () throws -> T) throws -> T {
        var result: Result<T, Error>?
        performAndWait {
            result = Result { try block() }
        }
        return try result!.get()
    }
}

// MARK: - Migration Helpers

class MailCoreDataMigration {
    static func migrateExistingData(context: NSManagedObjectContext) async throws {
        // Migrazione dei dati esistenti dal vecchio sistema al nuovo
        // Questa funzione viene chiamata durante l'avvio per migrare i dati

        print("🔄 MailCoreDataMigration: Inizio migrazione dati email")

        // 1. Migra email esistenti in thread
        try await migrateEmailsToThreads(context: context)

        // 2. Crea labels predefinite
        try await createDefaultLabels(context: context)

        // 3. Crea regole di filtro predefinite
        try await createDefaultFilterRules(context: context)

        print("✅ MailCoreDataMigration: Migrazione completata")
    }

    private static func migrateEmailsToThreads(context: NSManagedObjectContext) async throws {
        let fetchRequest: NSFetchRequest<CachedEmail> = CachedEmail.fetchRequest()
        let emails = try context.fetch(fetchRequest)

        print("📧 MailCoreDataMigration: Migrazione di \(emails.count) email in thread")

        var threadGroups: [String: [CachedEmail]] = [:]

        // Raggruppa email per thread
        for email in emails {
            let threadKey = generateThreadKey(for: email)
            threadGroups[threadKey, default: []].append(email)
        }

        // Crea thread per ogni gruppo
        for (threadKey, threadEmails) in threadGroups {
            let thread = EmailThread(context: context)
            thread.id = threadKey
            thread.subject = threadEmails.first?.subject ?? "Thread senza oggetto"
            thread.createdAt = threadEmails.map { $0.date ?? Date() }.min() ?? Date()
            thread.lastActivity = threadEmails.map { $0.date ?? Date() }.max() ?? Date()
            thread.providerId = "gmail" // Default per ora
            thread.unreadCount = Int64(threadEmails.filter { !($0.isRead) }.count)
            thread.totalCount = Int64(threadEmails.count)

            // Salva messageIds
            let messageIds = threadEmails.map { $0.id ?? "" }.joined(separator: ",")
            thread.messageIds = messageIds

            // Salva participants (semplificato)
            let participants = Set(threadEmails.compactMap { $0.fromEmail })
            thread.participants = try JSONEncoder().encode(participants)
        }

        try context.save()
        print("✅ MailCoreDataMigration: Creati \(threadGroups.count) thread")
    }

    private static func createDefaultLabels(context: NSManagedObjectContext) async throws {
        let defaultLabels = [
            ("INBOX", "Posta in arrivo", "inbox"),
            ("IMPORTANT", "Importante", "important"),
            ("SENT", "Inviata", "sent"),
            ("DRAFT", "Bozze", "drafts"),
            ("ARCHIVE", "Archivio", "archive"),
            ("TRASH", "Cestino", "trash"),
            ("SPAM", "Spam", "spam"),
            ("PERSONAL", "Personale", "personal"),
            ("WORK", "Lavoro", "work"),
            ("SOCIAL", "Social", "social"),
            ("PROMOTIONS", "Promozioni", "promotions"),
            ("UPDATES", "Aggiornamenti", "updates")
        ]

        for (id, name, type) in defaultLabels {
            let label = EmailLabel(context: context)
            label.id = id
            label.name = name
            label.type = type
            label.isVisible = true
            label.messageCount = 0
        }

        try context.save()
        print("✅ MailCoreDataMigration: Create \(defaultLabels.count) labels predefinite")
    }

    private static func createDefaultFilterRules(context: NSManagedObjectContext) async throws {
        // Creiamo alcune regole di filtro di base
        let rules = [
            ("Email Importanti", ["urgent", "important"], "IMPORTANT", 100),
            ("Promozioni", ["offer@", "promo@"], "PROMOTIONS", 50),
            ("Notifiche", ["noreply@", "notification@"], "UPDATES", 30)
        ]

        for (name, keywords, label, priority) in rules {
            let rule = EmailFilterRule(context: context)
            rule.id = UUID().uuidString
            rule.name = name
            rule.priority = Int64(priority)
            rule.isEnabled = true
            rule.createdAt = Date()
            rule.triggerCount = 0

            // Salva conditions semplificate come JSON
            let conditions = keywords.map { keyword in
                ["type": "subject", "value": keyword, "operator": "contains"]
            }
            rule.conditions = try JSONEncoder().encode(conditions)

            // Salva actions semplificate come JSON
            let actions = [["type": "applyLabel", "value": label]]
            rule.actions = try JSONEncoder().encode(actions)
        }

        try context.save()
        print("✅ MailCoreDataMigration: Create \(rules.count) regole di filtro predefinite")
    }

    private static func generateThreadKey(for email: CachedEmail) -> String {
        // Genera una chiave thread basata su subject e partecipanti
        let normalizedSubject = normalizeSubject(email.subject ?? "")
        let participants = [email.fromEmail ?? ""].joined(separator: ",")
        return "\(normalizedSubject)|\(participants)".lowercased()
    }

    private static func normalizeSubject(_ subject: String) -> String {
        var normalized = subject.trimmingCharacters(in: .whitespacesAndNewlines)

        // Rimuovi prefissi comuni
        let prefixesToRemove = ["Re:", "RE:", "Fwd:", "FWD:", "Fw:", "FW:"]
        for prefix in prefixesToRemove {
            while normalized.lowercased().hasPrefix(prefix.lowercased()) {
                normalized = String(normalized.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return normalized.isEmpty ? "Nessun oggetto" : normalized
    }
}

// MARK: - Utility Functions

func createMailSystemEntitiesIfNeeded(context: NSManagedObjectContext) {
    // Questa funzione viene chiamata durante l'avvio dell'app
    // per assicurarsi che tutte le entità necessarie esistano

    Task {
        do {
            try await MailCoreDataMigration.migrateExistingData(context: context)
        } catch {
            print("❌ Errore durante la migrazione del sistema email: \(error)")
        }
    }
}
