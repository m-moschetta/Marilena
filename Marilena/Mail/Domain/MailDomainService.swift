//
//  MailDomainService.swift
//  Marilena
//
//  Created by Marilena on 2024
//
//  Servizio di dominio principale per il sistema email
//  Coordina tutti i componenti del sistema mail
//

import Foundation
import Combine

/// Servizio di dominio principale per la gestione email
public final class MailDomainService: ObservableObject {

    // MARK: - Published Properties

    @Published public var accounts: [MailAccount] = []
    @Published public var isLoading = false
    @Published public var syncStatus: MailSyncStatus = .idle
    @Published public var unreadCount: Int = 0

    // MARK: - Private Properties

    private let transportCoordinator: MailTransportCoordinator
    private let syncEngine: MailSyncEngine
    private let classificationEngine: MailClassificationEngine
    private let storage: MailStorageProtocol
    private let queue = DispatchQueue(label: "com.marilena.mail.domain", qos: .userInitiated)

    private var cancellables = Set<AnyCancellable>()
    private var activeSyncs: [String: AnyCancellable] = [:]

    // MARK: - Initialization

    public init(storage: MailStorageProtocol) {
        self.storage = storage
        self.transportCoordinator = MailTransportCoordinator()
        self.syncEngine = MailSyncEngine(
            transportCoordinator: transportCoordinator,
            storage: storage
        )
        self.classificationEngine = MailClassificationEngine(storage: storage)

        setupBindings()
        loadAccounts()
    }

    // MARK: - Public Methods

    /// Aggiunge un nuovo account email
    public func addAccount(_ account: MailAccount) async throws {
        // Connetti il provider
        let provider = MailTransportCoordinator.createProvider(for: account.provider)
        if let provider = provider {
            transportCoordinator.registerProvider(provider, for: account.provider)
        }

        // Salva l'account
        try await storage.saveAccount(account)

        // Aggiorna la lista
        await MainActor.run {
            accounts.append(account)
        }

        // Avvia la prima sincronizzazione
        try await syncAccount(account.id)
    }

    /// Rimuove un account
    public func removeAccount(_ accountId: String) async throws {
        // Ferma eventuali sync in corso
        stopSync(for: accountId)

        // Rimuovi dal storage
        try await storage.deleteAccount(accountId)

        // Rimuovi dalla lista
        await MainActor.run {
            accounts.removeAll { $0.id == accountId }
        }
    }

    /// Sincronizza un account specifico
    public func syncAccount(_ accountId: String) async throws {
        guard let account = accounts.first(where: { $0.id == accountId }) else {
            throw MailDomainError.accountNotFound
        }

        let options = MailSyncOptions(
            maxMessages: 50,
            includeAttachments: false,
            fullSync: false
        )

        let syncPublisher = syncEngine.startSync(for: account, options: options)

        let cancellable = syncPublisher
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }

                    self.queue.async {
                        self.activeSyncs[accountId] = nil
                    }

                    switch completion {
                    case .finished:
                        print("✅ Sync completata per account \(account.email)")
                    case .failure(let error):
                        print("❌ Errore sync per account \(account.email): \(error)")
                    }
                },
                receiveValue: { [weak self] progress in
                    guard let self = self else { return }

                    self.handleSyncProgress(progress, for: accountId)
                }
            )

        queue.async {
            self.activeSyncs[accountId] = cancellable
        }
    }

    /// Ferma la sincronizzazione per un account
    public func stopSync(for accountId: String) {
        syncEngine.stopSync(for: accountId)
        queue.async {
            self.activeSyncs[accountId] = nil
        }
    }

    /// Carica i messaggi per un account
    public func loadMessages(for accountId: String, filter: MailMessageFilter? = nil) async throws -> [MailMessage] {
        try await storage.loadMessages(for: accountId, filter: filter)
    }

    /// Carica i thread per un account
    public func loadThreads(for accountId: String, filter: MailThreadFilter? = nil) async throws -> [MailThread] {
        try await storage.loadThreads(for: accountId, filter: filter)
    }

    /// Invia un messaggio
    public func sendMessage(_ message: MailMessage, using accountId: String) async throws {
        guard let account = accounts.first(where: { $0.id == accountId }) else {
            throw MailDomainError.accountNotFound
        }

        _ = try await transportCoordinator.sendEmail(message, using: account)

        // Salva nel sent items localmente
        try await storage.saveMessages([message], for: accountId)
    }

    /// Marca messaggi come letti
    public func markMessagesAsRead(_ messageIds: [String], accountId: String, read: Bool = true) async throws {
        guard let account = accounts.first(where: { $0.id == accountId }) else {
            throw MailDomainError.accountNotFound
        }

        guard let provider = transportCoordinator.provider(for: account.provider) else {
            throw MailDomainError.providerNotAvailable
        }

        try await provider.markAsRead(messageIds, read: read).async()

        // Aggiorna localmente
        var messages = try await storage.loadMessages(for: accountId, filter: nil)
        for (index, message) in messages.enumerated() {
            if messageIds.contains(message.id) {
                var updatedMessage = message
                updatedMessage.flags = read ? updatedMessage.flags.union(.seen) : updatedMessage.flags.subtracting(.seen)
                messages[index] = updatedMessage
            }
        }

        try await storage.saveMessages(messages, for: accountId)
    }

    /// Classifica email automaticamente
    public func classifyMessages(_ messages: [MailMessage], for accountId: String) async throws -> [MailMessage] {
        try await classificationEngine.classifyEmails(messages, for: accountId)
    }

    /// Cerca messaggi
    public func searchMessages(_ query: MailSearchQuery, accountId: String) async throws -> [MailMessage] {
        try await storage.searchMessages(query, for: accountId)
    }

    /// Ottiene statistiche dell'account
    public func getAccountStats(_ accountId: String) async throws -> MailAccountStats {
        let messages = try await storage.loadMessages(for: accountId, filter: nil)
        let threads = try await storage.loadThreads(for: accountId, filter: nil)

        let unreadCount = messages.filter { !$0.flags.isRead }.count
        let totalSize = messages.compactMap { $0.size }.reduce(0, +)

        return MailAccountStats(
            totalMessages: messages.count,
            unreadMessages: unreadCount,
            totalThreads: threads.count,
            totalSize: totalSize,
            lastSyncDate: syncEngine.syncState(for: accountId)?.lastUpdate
        )
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Aggiorna il conteggio non letti quando cambiano gli account
        $accounts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] accounts in
                self?.updateUnreadCount()
            }
            .store(in: &cancellables)
    }

    private func loadAccounts() {
        Task {
            do {
                let loadedAccounts = try await storage.loadAccounts()
                await MainActor.run {
                    self.accounts = loadedAccounts
                }
            } catch {
                print("❌ Errore caricamento account: \(error)")
            }
        }
    }

    private func handleSyncProgress(_ progress: MailSyncProgress, for accountId: String) {
        switch progress {
        case .started:
            syncStatus = .syncing(accountId: accountId, progress: 0)
        case .progress(let current, let total):
            let percentage = total > 0 ? Double(current) / Double(total) : 0
            syncStatus = .syncing(accountId: accountId, progress: percentage)
        case .newMessages(let count):
            print("📧 \(count) nuovi messaggi ricevuti")
        case .updatedMessages(let count):
            print("📧 \(count) messaggi aggiornati")
        case .deletedMessages(let count):
            print("📧 \(count) messaggi eliminati")
        case .completed:
            syncStatus = .idle
            Task {
                await updateUnreadCount()
            }
        }
    }

    private func updateUnreadCount() {
        Task {
            var totalUnread = 0

            for account in accounts {
                do {
                    let messages = try await storage.loadMessages(for: account.id, filter: nil)
                    let unread = messages.filter { !$0.flags.isRead }.count
                    totalUnread += unread
                } catch {
                    print("❌ Errore calcolo non letti per account \(account.email): \(error)")
                }
            }

            await MainActor.run {
                self.unreadCount = totalUnread
            }
        }
    }
}

// MARK: - Supporting Types

/// Stato di sincronizzazione del dominio
public enum MailSyncStatus {
    case idle
    case syncing(accountId: String, progress: Double)
}

/// Statistiche dell'account
public struct MailAccountStats {
    public let totalMessages: Int
    public let unreadMessages: Int
    public let totalThreads: Int
    public let totalSize: Int64
    public let lastSyncDate: Date?
}

/// Errori del dominio
public enum MailDomainError: LocalizedError {
    case accountNotFound
    case providerNotAvailable
    case syncFailed(String)
    case sendFailed(String)

    public var errorDescription: String? {
        switch self {
        case .accountNotFound:
            return "Account non trovato"
        case .providerNotAvailable:
            return "Provider non disponibile"
        case .syncFailed(let message):
            return "Sincronizzazione fallita: \(message)"
        case .sendFailed(let message):
            return "Invio fallito: \(message)"
        }
    }
}

// MARK: - Extensions

private extension MailStorageProtocol {
    func saveAccount(_ account: MailAccount) async throws {
        // Placeholder - sarà implementato nel MailStorage
        throw MailStorageError.saveFailed("Not implemented")
    }

    func loadAccounts() async throws -> [MailAccount] {
        // Placeholder - sarà implementato nel MailStorage
        return []
    }

    func deleteAccount(_ accountId: String) async throws {
        // Placeholder - sarà implementato nel MailStorage
        throw MailStorageError.deleteFailed("Not implemented")
    }
}

private extension Publisher {
    func async() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?

            cancellable = self.sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break // Attende il valore
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                    cancellable?.cancel()
                },
                receiveValue: { value in
                    continuation.resume(returning: value)
                    cancellable?.cancel()
                }
            )
        }
    }
}
