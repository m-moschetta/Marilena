import Foundation
import Combine

/// Servizio principale per la gestione completa delle email
/// Coordina tutti i componenti del sistema email: storage, sync, categorizzazione, provider
public class MailService: ObservableObject {
    public static let shared = MailService()

    // MARK: - Services
    private let storageService = MailStorageService.shared
    private let syncService = MailSyncService.shared
    private let categorizationService = MailCategorizationService.shared

    // MARK: - Published Properties
    @Published public var isAuthenticated = false
    @Published public var currentAccount: MailAccount?
    @Published public var messages: [MailMessage] = []
    @Published public var threads: [MailThread] = []
    @Published public var labels: [MailLabel] = []
    @Published public var isLoading = false
    @Published public var error: String?

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var activeProvider: MailProvider?
    private var currentToken: MailToken?

    private init() {
        setupBindings()
    }

    // MARK: - Authentication

    /// Autentica un account email
    public func authenticate(account: MailAccount) async throws {
        print("🔐 MailService: Inizio autenticazione per \(account.email)")

        isLoading = true
        error = nil

        do {
            // Ottieni il provider appropriato
            let provider = try getProvider(for: account.provider)

            // Prepara le credenziali
            let credentials = MailCredentials(
                username: account.email,
                accessToken: account.accessToken,
                refreshToken: account.refreshToken,
                clientId: account.clientId,
                clientSecret: account.clientSecret
            )

            // Autentica con il provider
            let token = try await provider.authenticate(with: credentials)

            // Salva le informazioni di autenticazione
            self.activeProvider = provider
            self.currentToken = token
            self.currentAccount = account
            self.isAuthenticated = true

            print("✅ MailService: Autenticazione riuscita per \(account.email)")

            // Carica i dati iniziali
            try await loadInitialData()

        } catch {
            print("❌ MailService: Errore autenticazione: \(error)")
            self.error = error.localizedDescription
            throw error
        }

        isLoading = false
    }

    /// Disconnetti l'account corrente
    public func disconnect() {
        activeProvider = nil
        currentToken = nil
        currentAccount = nil
        isAuthenticated = false
        messages.removeAll()
        threads.removeAll()
        labels.removeAll()

        print("🔌 MailService: Account disconnesso")
    }

    // MARK: - Data Loading

    /// Carica i dati iniziali dopo l'autenticazione
    private func loadInitialData() async throws {
        guard let account = currentAccount,
              let provider = activeProvider,
              let token = currentToken else {
            throw MailServiceError.notAuthenticated
        }

        print("📥 MailService: Caricamento dati iniziali per \(account.email)")

        // Carica messaggi dalla cache locale
        messages = try await storageService.fetchMessages(for: account.id, limit: 100)

        // Se non ci sono messaggi in cache, sincronizza dal server
        if messages.isEmpty {
            try await syncService.fullSyncAccount(account.id, provider: provider, token: token)
            messages = try await storageService.fetchMessages(for: account.id, limit: 100)
        }

        // Carica thread
        threads = try await storageService.fetchThreads(for: account.id, limit: 50)

        // Carica labels
        labels = try await storageService.fetchLabels()

        // Avvia categorizzazione in background
        Task {
            await categorizeMessagesInBackground()
        }

        print("✅ MailService: Dati iniziali caricati (\(messages.count) messaggi, \(threads.count) thread)")
    }

    /// Ricarica i dati dal server
    public func refreshData() async throws {
        guard let account = currentAccount,
              let provider = activeProvider,
              let token = currentToken else {
            throw MailServiceError.notAuthenticated
        }

        print("🔄 MailService: Refresh dati per \(account.email)")

        isLoading = true

        do {
            // Sincronizza con il server
            try await syncService.incrementalSyncAccount(account.id, provider: provider, token: token)

            // Ricarica i dati locali
            messages = try await storageService.fetchMessages(for: account.id, limit: 100)
            threads = try await storageService.fetchThreads(for: account.id, limit: 50)

            print("✅ MailService: Dati refreshati")

        } catch {
            print("❌ MailService: Errore refresh: \(error)")
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Message Operations

    /// Invia un messaggio
    public func sendMessage(_ draft: MailDraft) async throws -> String {
        guard let provider = activeProvider,
              let token = currentToken,
              let account = currentAccount else {
            throw MailServiceError.notAuthenticated
        }

        print("📤 MailService: Invio messaggio a \(draft.to.joined(separator: ", "))")

        do {
            let messageId = try await provider.sendMessage(draft, using: token)

            // Aggiorna la cartella "Sent" se necessario
            try await refreshData()

            print("✅ MailService: Messaggio inviato con ID: \(messageId)")
            return messageId

        } catch {
            print("❌ MailService: Errore invio messaggio: \(error)")
            throw error
        }
    }

    /// Marca un messaggio come letto/non letto
    public func markMessageAsRead(_ messageId: String, isRead: Bool) async throws {
        guard let account = currentAccount else {
            throw MailServiceError.notAuthenticated
        }

        try await storageService.markMessageAsRead(messageId, accountId: account.id, isRead: isRead)

        // Aggiorna la lista locale
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            var updatedMessage = messages[index]
            let newFlags = MailMessageFlags(
                isRead: isRead,
                isStarred: updatedMessage.flags.isStarred,
                isDeleted: updatedMessage.flags.isDeleted,
                isDraft: updatedMessage.flags.isDraft,
                isAnswered: updatedMessage.flags.isAnswered,
                isForwarded: updatedMessage.flags.isForwarded
            )

            updatedMessage = MailMessage(
                id: updatedMessage.id,
                threadId: updatedMessage.threadId,
                subject: updatedMessage.subject,
                bodyPlain: updatedMessage.bodyPlain,
                bodyHTML: updatedMessage.bodyHTML,
                snippet: updatedMessage.snippet,
                from: updatedMessage.from,
                to: updatedMessage.to,
                cc: updatedMessage.cc,
                bcc: updatedMessage.bcc,
                date: updatedMessage.date,
                labels: updatedMessage.labels,
                flags: newFlags,
                attachments: updatedMessage.attachments,
                providerId: updatedMessage.providerId,
                providerThreadKey: updatedMessage.providerThreadKey,
                size: updatedMessage.size
            )

            messages[index] = updatedMessage
        }

        print("✅ MailService: Messaggio \(messageId) marcato come \(isRead ? "letto" : "non letto")")
    }

    /// Elimina un messaggio
    public func deleteMessage(_ messageId: String) async throws {
        guard let account = currentAccount,
              let provider = activeProvider,
              let token = currentToken else {
            throw MailServiceError.notAuthenticated
        }

        // Elimina dal server
        try await provider.deleteMessage(messageId, using: token)

        // Elimina dal storage locale
        try await storageService.deleteMessage(messageId, accountId: account.id)

        // Aggiorna la lista locale
        messages.removeAll { $0.id == messageId }

        print("🗑️ MailService: Messaggio \(messageId) eliminato")
    }

    /// Archivia un messaggio
    public func archiveMessage(_ messageId: String) async throws {
        guard let account = currentAccount,
              let provider = activeProvider,
              let token = currentToken else {
            throw MailServiceError.notAuthenticated
        }

        // Archivia sul server
        try await provider.archiveMessage(messageId, using: token)

        // Rimuovi dalla lista locale (poiché è archiviato)
        messages.removeAll { $0.id == messageId }

        print("📦 MailService: Messaggio \(messageId) archiviato")
    }

    // MARK: - Thread Operations

    /// Ottieni messaggi di un thread
    public func messagesForThread(_ threadId: String) async throws -> [MailMessage] {
        guard let account = currentAccount else {
            throw MailServiceError.notAuthenticated
        }

        // Trova il thread
        guard let thread = threads.first(where: { $0.id == threadId }) else {
            throw MailServiceError.threadNotFound
        }

        // Recupera i messaggi del thread
        var threadMessages: [MailMessage] = []
        for messageId in thread.messageIds {
            if let message = try await storageService.fetchMessage(id: messageId, accountId: account.id) {
                threadMessages.append(message)
            }
        }

        return threadMessages.sorted { $0.date < $1.date }
    }

    /// Marca tutto il thread come letto
    public func markThreadAsRead(_ threadId: String) async throws {
        let threadMessages = try await messagesForThread(threadId)

        for message in threadMessages where !message.flags.isRead {
            try await markMessageAsRead(message.id, isRead: true)
        }

        print("✅ MailService: Thread \(threadId) marcato come letto")
    }

    // MARK: - Categorization

    /// Categorizza un singolo messaggio
    public func categorizeMessage(_ messageId: String) async throws {
        guard let message = messages.first(where: { $0.id == messageId }) else {
            throw MailServiceError.messageNotFound
        }

        let categorizedMessage = await categorizationService.categorizeEmail(message)

        // Aggiorna nella lista locale
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index] = categorizedMessage
        }

        print("🤖 MailService: Messaggio \(messageId) categorizzato come \(categorizedMessage.category?.displayName ?? "Non categorizzato")")
    }

    /// Categorizza tutti i messaggi non categorizzati
    public func categorizeAllUncategorizedMessages() async {
        let uncategorizedMessages = messages.filter { $0.category == nil }

        if uncategorizedMessages.isEmpty {
            print("🤖 MailService: Tutti i messaggi sono già categorizzati")
            return
        }

        print("🤖 MailService: Categorizzazione di \(uncategorizedMessages.count) messaggi")

        let categorizedMessages = await categorizationService.categorizeEmails(uncategorizedMessages)

        // Aggiorna la lista locale
        for categorizedMessage in categorizedMessages {
            if let index = messages.firstIndex(where: { $0.id == categorizedMessage.id }) {
                messages[index] = categorizedMessage
            }
        }

        print("✅ MailService: Categorizzazione completata")
    }

    // MARK: - Filtering and Search

    /// Filtra messaggi per categoria
    public func messagesForCategory(_ category: MailCategory) -> [MailMessage] {
        return messages.filter { $0.category == category }
    }

    /// Filtra messaggi per label
    public func messagesForLabel(_ labelId: String) -> [MailMessage] {
        return messages.filter { $0.labels.contains(labelId) }
    }

    /// Cerca messaggi
    public func searchMessages(query: String, in field: SearchField = .all) -> [MailMessage] {
        let searchQuery = query.lowercased()

        return messages.filter { message in
            switch field {
            case .all:
                return message.subject.lowercased().contains(searchQuery) ||
                       message.from.displayName.lowercased().contains(searchQuery) ||
                       (message.bodyPlain ?? "").lowercased().contains(searchQuery) ||
                       (message.bodyHTML ?? "").lowercased().contains(searchQuery)
            case .subject:
                return message.subject.lowercased().contains(searchQuery)
            case .from:
                return message.from.displayName.lowercased().contains(searchQuery)
            case .body:
                return (message.bodyPlain ?? "").lowercased().contains(searchQuery) ||
                       (message.bodyHTML ?? "").lowercased().contains(searchQuery)
            }
        }
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Sincronizza lo stato del sync service
        syncService.$isOnline
            .receive(on: DispatchQueue.main)
            .assign(to: &$isOnline)

        syncService.$syncStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$syncStatus)

        syncService.$pendingOperationsCount
            .receive(on: DispatchQueue.main)
            .assign(to: &$pendingOperationsCount)
    }

    private func getProvider(for providerType: MailProviderType) throws -> MailProvider {
        switch providerType {
        case .gmail:
            return GmailProvider()
        case .microsoft:
            // return MicrosoftProvider() // Implementare quando necessario
            throw MailServiceError.providerNotImplemented
        }
    }

    private func categorizeMessagesInBackground() async {
        await categorizationService.categorizeEmails(messages)
    }

    // MARK: - Statistics

    /// Ottiene statistiche del sistema email
    public func getStatistics() -> MailStatistics {
        let categorizedCount = messages.filter { $0.category != nil }.count
        let readCount = messages.filter { $0.flags.isRead }.count
        let totalSize = messages.reduce(0) { $0 + $1.size }

        return MailStatistics(
            totalMessages: messages.count,
            categorizedMessages: categorizedCount,
            readMessages: readCount,
            totalSize: totalSize,
            threadsCount: threads.count,
            labelsCount: labels.count
        )
    }
}

// MARK: - Supporting Types

/// Account email
public struct MailAccount: Identifiable {
    public let id: String
    public let email: String
    public let provider: MailProviderType
    public let accessToken: String
    public let refreshToken: String?
    public let clientId: String
    public let clientSecret: String

    public init(
        id: String = UUID().uuidString,
        email: String,
        provider: MailProviderType,
        accessToken: String,
        refreshToken: String? = nil,
        clientId: String,
        clientSecret: String
    ) {
        self.id = id
        self.email = email
        self.provider = provider
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.clientId = clientId
        self.clientSecret = clientSecret
    }
}

/// Tipo di provider email
public enum MailProviderType: String, Codable {
    case gmail
    case microsoft
}

/// Campo di ricerca
public enum SearchField {
    case all
    case subject
    case from
    case body
}

/// Statistiche del sistema email
public struct MailStatistics {
    public let totalMessages: Int
    public let categorizedMessages: Int
    public let readMessages: Int
    public let totalSize: Int
    public let threadsCount: Int
    public let labelsCount: Int

    public var categorizationRate: Double {
        guard totalMessages > 0 else { return 0 }
        return Double(categorizedMessages) / Double(totalMessages)
    }

    public var readRate: Double {
        guard totalMessages > 0 else { return 0 }
        return Double(readMessages) / Double(totalMessages)
    }

    public var averageMessageSize: Int {
        guard totalMessages > 0 else { return 0 }
        return totalSize / totalMessages
    }
}

// MARK: - Published Properties for UI
extension MailService {
    @Published public var isOnline = true
    @Published public var syncStatus: MailSyncStatus = .idle
    @Published public var pendingOperationsCount = 0
}

/// Errori del servizio email
public enum MailServiceError: LocalizedError {
    case notAuthenticated
    case providerNotImplemented
    case messageNotFound
    case threadNotFound
    case invalidCredentials

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Utente non autenticato"
        case .providerNotImplemented:
            return "Provider non ancora implementato"
        case .messageNotFound:
            return "Messaggio non trovato"
        case .threadNotFound:
            return "Thread non trovato"
        case .invalidCredentials:
            return "Credenziali non valide"
        }
    }
}
