import Foundation
import Combine

/// Servizio per la categorizzazione intelligente delle email
public class MailCategorizationService {
    public static let shared = MailCategorizationService()

    private let storageService = MailStorageService.shared
    private var cancellables = Set<AnyCancellable>()

    // Cache per evitare categorizzazioni duplicate
    private var categorizedMessageIds = Set<String>()
    private var messagesBeingCategorized = Set<String>()

    // Contatori per gestire i limiti AI
    private var accountAICounts: [String: Int] = [:]
    private var sessionCounters: [String: Int] = [:]

    // Limite AI per sessione (configurabile)
    private let maxAISuggestionsPerSession = 50
    private let maxAISuggestionsPerAccount = 100

    private init() {
        loadCachedCategorizations()
    }

    // MARK: - Public Methods

    /// Categorizza una singola email
    public func categorizeEmail(_ message: MailMessage) async -> MailMessage {
        // Controllo duplicati
        guard !categorizedMessageIds.contains(message.id) else {
            print("🤖 MailCategorizationService: Email già categorizzata: \(message.id)")
            return message
        }

        guard !messagesBeingCategorized.contains(message.id) else {
            print("⏳ MailCategorizationService: Email già in elaborazione: \(message.id)")
            return message
        }

        messagesBeingCategorized.insert(message.id)

        defer {
            messagesBeingCategorized.remove(message.id)
        }

        print("🤖 MailCategorizationService: Categorizzazione email: \(message.subject)")

        do {
            // Applica le regole di filtro
            var categorizedMessage = try await applyFilterRules(to: message)

            // Se non categorizzata dalle regole, prova con AI
            if categorizedMessage.category == nil {
                categorizedMessage = try await applyAICategorization(to: categorizedMessage)
            }

            // Salva in cache
            categorizedMessageIds.insert(message.id)

            // Salva nel database
            try await storageService.saveMessage(categorizedMessage)

            print("✅ MailCategorizationService: Email categorizzata come \(categorizedMessage.category?.displayName ?? "Non categorizzata")")

            return categorizedMessage

        } catch {
            print("❌ MailCategorizationService: Errore categorizzazione: \(error)")
            return message
        }
    }

    /// Categorizza multiple email in batch
    public func categorizeEmails(_ messages: [MailMessage]) async -> [MailMessage] {
        print("🤖 MailCategorizationService: Categorizzazione batch di \(messages.count) email")

        var categorizedMessages: [MailMessage] = []

        // Prima applica le regole a tutte le email (più efficiente)
        let messagesAfterRules = try? await applyFilterRulesBatch(to: messages)

        // Poi applica AI dove necessario
        for message in messagesAfterRules ?? messages {
            let categorizedMessage = await categorizeEmail(message)
            categorizedMessages.append(categorizedMessage)
        }

        print("✅ MailCategorizationService: Batch completato - \(categorizedMessages.filter { $0.category != nil }.count) categorizzate")

        return categorizedMessages
    }

    /// Categorizza con AI forzatamente (ignora limiti)
    public func categorizeWithAI(_ message: MailMessage) async -> MailCategory {
        print("🧠 MailCategorizationService: Categorizzazione AI forzata per: \(message.subject)")

        // Qui si integrerebbe con il servizio AI
        // Per ora restituiamo una categorizzazione di fallback intelligente
        return await intelligentFallbackCategorization(for: message)
    }

    /// Applica le regole di filtro a un messaggio
    public func applyFilterRules(to message: MailMessage) async throws -> MailMessage {
        let rules = try await storageService.fetchFilterRules()

        // Ordina per priorità (più alta prima)
        let sortedRules = rules.sorted { $0.priority > $1.priority }

        var updatedMessage = message

        for rule in sortedRules {
            if rule.matches(message: updatedMessage) {
                print("🎯 MailCategorizationService: Regola '\(rule.name)' corrisponde")
                updatedMessage = rule.applyActions(to: updatedMessage)

                // Salva la regola aggiornata con il trigger
                try await storageService.saveFilterRule(rule.triggered())

                // Se la regola ha categorizzato il messaggio, fermati
                if updatedMessage.category != nil {
                    break
                }
            }
        }

        return updatedMessage
    }

    /// Applica le regole di filtro a un batch di messaggi
    public func applyFilterRulesBatch(to messages: [MailMessage]) async throws -> [MailMessage] {
        let rules = try await storageService.fetchFilterRules()
        let sortedRules = rules.sorted { $0.priority > $1.priority }

        return messages.map { message in
            var updatedMessage = message

            for rule in sortedRules {
                if rule.matches(message: updatedMessage) {
                    updatedMessage = rule.applyActions(to: updatedMessage)
                    if updatedMessage.category != nil {
                        break
                    }
                }
            }

            return updatedMessage
        }
    }

    // MARK: - AI Integration

    private func applyAICategorization(to message: MailMessage) async -> MailMessage {
        // Controlla limiti AI
        guard canUseAI(for: message.providerId) else {
            print("⏳ MailCategorizationService: Limite AI raggiunto per \(message.providerId)")
            return message.addingCategory(.personal) // Fallback
        }

        let category = await intelligentFallbackCategorization(for: message)

        // Incrementa contatore AI
        incrementAccountAICount(for: message.providerId)

        return message.addingCategory(category)
    }

    /// Categorizzazione intelligente di fallback (basata su regole euristiche)
    private func intelligentFallbackCategorization(for message: MailMessage) async -> MailCategory {
        let subject = message.subject.lowercased()
        let body = (message.bodyPlain ?? message.bodyHTML ?? "").lowercased()
        let from = message.from.email.lowercased()

        // Regole euristiche per categorizzazione intelligente
        if from.contains("noreply") || from.contains("no-reply") || from.contains("notification") {
            return .updates
        }

        if subject.contains("invoice") || subject.contains("fattura") || subject.contains("payment") {
            return .work
        }

        if subject.contains("meeting") || subject.contains("riunione") || subject.contains("call") {
            return .work
        }

        if from.contains("amazon") || from.contains("ebay") || from.contains("shopping") {
            return .promotions
        }

        if subject.contains("newsletter") || subject.contains("news") {
            return .social
        }

        if subject.contains("ciao") || subject.contains("hello") || from.contains("gmail.com") || from.contains("outlook.com") {
            return .personal
        }

        // Default: personale
        return .personal
    }

    // MARK: - Cache Management

    /// Verifica se un messaggio è già stato categorizzato
    public func isEmailCategorized(_ messageId: String) -> Bool {
        return categorizedMessageIds.contains(messageId)
    }

    /// Verifica se un messaggio è attualmente in elaborazione
    public func isEmailBeingCategorized(_ messageId: String) -> Bool {
        return messagesBeingCategorized.contains(messageId)
    }

    /// Marca un messaggio come categorizzato
    public func markEmailAsCategorized(_ messageId: String) {
        categorizedMessageIds.insert(messageId)
    }

    // MARK: - AI Limits Management

    /// Verifica se si può usare l'AI per un account
    public func canUseAI(for accountId: String) -> Bool {
        let accountCount = accountAICounts[accountId] ?? 0
        let sessionCount = sessionCounters[accountId] ?? 0

        return accountCount < maxAISuggestionsPerAccount && sessionCount < maxAISuggestionsPerSession
    }

    /// Incrementa il contatore AI per un account
    public func incrementAccountAICount(for accountId: String) {
        accountAICounts[accountId, default: 0] += 1
        sessionCounters[accountId, default: 0] += 1
    }

    /// Reset contatori di sessione
    public func resetSessionCounters() {
        sessionCounters.removeAll()
        print("🔄 MailCategorizationService: Contatori sessione resettati")
    }

    /// Reset contatore AI per un account
    public func resetAccountAICount(for accountId: String) {
        accountAICounts[accountId] = 0
        sessionCounters[accountId] = 0
        print("🔄 MailCategorizationService: Contatori AI resettati per \(accountId)")
    }

    // MARK: - Rule Management

    /// Crea una regola di filtro predefinita
    public func createDefaultFilterRules() async throws {
        let defaultRules = [
            // Regola per email importanti
            MailFilterRule(
                name: "Email Importanti",
                conditions: [
                    MailFilterCondition(type: .subject, value: "urgent", operator: .contains),
                    MailFilterCondition(type: .subject, value: "important", operator: .contains)
                ],
                actions: [MailFilterAction(type: .applyLabel, value: "IMPORTANT")],
                priority: 100
            ),

            // Regola per promozioni
            MailFilterRule(
                name: "Promozioni",
                conditions: [
                    MailFilterCondition(type: .from, value: "offer@", operator: .contains),
                    MailFilterCondition(type: .from, value: "promo@", operator: .contains),
                    MailFilterCondition(type: .subject, value: "sale", operator: .contains)
                ],
                actions: [MailFilterAction(type: .applyLabel, value: "PROMOTIONS")],
                priority: 50
            ),

            // Regola per notifiche
            MailFilterRule(
                name: "Notifiche Sistema",
                conditions: [
                    MailFilterCondition(type: .from, value: "noreply@", operator: .contains),
                    MailFilterCondition(type: .from, value: "notification@", operator: .contains)
                ],
                actions: [MailFilterAction(type: .applyLabel, value: "UPDATES")],
                priority: 30
            )
        ]

        for rule in defaultRules {
            try await storageService.saveFilterRule(rule)
        }

        print("✅ MailCategorizationService: Regole di filtro predefinite create")
    }

    // MARK: - Statistics

    /// Ottiene statistiche di categorizzazione
    public func getCategorizationStats() -> MailCategorizationStats {
        return MailCategorizationStats(
            totalCategorized: categorizedMessageIds.count,
            currentlyProcessing: messagesBeingCategorized.count,
            aiUsageByAccount: accountAICounts,
            sessionUsageByAccount: sessionCounters
        )
    }

    // MARK: - Private Methods

    private func loadCachedCategorizations() {
        // In futuro, caricare dalla cache persistente
        print("🔧 MailCategorizationService: Cache categorizzazioni caricata")
    }

    private func saveCategorizationCache() {
        // In futuro, salvare nella cache persistente
        print("💾 MailCategorizationService: Cache categorizzazioni salvata")
    }
}

// MARK: - Supporting Types

/// Statistiche di categorizzazione
public struct MailCategorizationStats {
    public let totalCategorized: Int
    public let currentlyProcessing: Int
    public let aiUsageByAccount: [String: Int]
    public let sessionUsageByAccount: [String: Int]

    public var totalAIUsage: Int {
        aiUsageByAccount.values.reduce(0, +)
    }

    public var totalSessionUsage: Int {
        sessionUsageByAccount.values.reduce(0, +)
    }
}

// MARK: - MailMessage Extension

private extension MailMessage {
    func addingCategory(_ category: MailCategory) -> MailMessage {
        return MailMessage(
            id: id,
            threadId: threadId,
            subject: subject,
            bodyPlain: bodyPlain,
            bodyHTML: bodyHTML,
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
            providerThreadKey: providerThreadKey,
            size: size
        )
    }
}

// MARK: - MailCategory (placeholder - sarà definito altrove)

public enum MailCategory: String, Codable, CaseIterable {
    case inbox
    case important
    case sent
    case drafts
    case personal
    case work
    case social
    case promotions
    case updates
    case archive
    case trash
    case spam

    public var displayName: String {
        switch self {
        case .inbox: return "Posta in arrivo"
        case .important: return "Importante"
        case .sent: return "Inviata"
        case .drafts: return "Bozze"
        case .personal: return "Personale"
        case .work: return "Lavoro"
        case .social: return "Social"
        case .promotions: return "Promozioni"
        case .updates: return "Aggiornamenti"
        case .archive: return "Archivio"
        case .trash: return "Cestino"
        case .spam: return "Spam"
        }
    }
}
