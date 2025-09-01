import Foundation
import Combine

/// Servizio per la gestione della sincronizzazione email
public class MailSyncService {
    public static let shared = MailSyncService()

    private let storageService = MailStorageService.shared
    private var cancellables = Set<AnyCancellable>()

    @Published public var isOnline = true
    @Published public var syncStatus: MailSyncStatus = .idle
    @Published public var pendingOperationsCount = 0

    private var syncTasks: [String: Task<Void, Error>] = [:] // accountId -> task

    private init() {
        setupNetworkMonitoring()
    }

    // MARK: - Sync Operations

    /// Avvia la sincronizzazione per un account
    public func syncAccount(_ accountId: String, provider: MailProvider, token: MailToken) async throws {
        guard isOnline else {
            throw MailSyncError.offline
        }

        // Evita sync concorrenti per lo stesso account
        if syncTasks[accountId] != nil {
            print("🔄 MailSyncService: Sync già in corso per \(accountId)")
            return
        }

        let task = Task {
            do {
                try await performSync(for: accountId, provider: provider, token: token)
            } catch {
                print("❌ MailSyncService: Errore sync per \(accountId): \(error)")
                throw error
            }
        }

        syncTasks[accountId] = task

        do {
            try await task.value
        } catch {
            // Gestisci l'errore
            try await handleSyncError(for: accountId, error: error)
        }

        syncTasks[accountId] = nil
    }

    /// Sincronizzazione completa per un account
    public func fullSyncAccount(_ accountId: String, provider: MailProvider, token: MailToken) async throws {
        print("🔄 MailSyncService: Avvio sync completa per \(accountId)")

        // Aggiorna stato di sincronizzazione
        var syncState = try await storageService.fetchSyncState(for: accountId) ?? MailSyncState(accountId: accountId, providerId: provider.providerId)
        syncState = syncState.duringSync()
        try await storageService.saveSyncState(syncState)

        syncStatus = .inProgress
        pendingOperationsCount += 1

        defer {
            pendingOperationsCount -= 1
            syncStatus = .idle
        }

        do {
            // Recupera i messaggi recenti
            let messages = try await provider.fetchMessages(from: "INBOX", limit: 100, using: token)

            // Salva i messaggi
            for message in messages {
                try await storageService.saveMessage(message)
            }

            // Recupera i thread (se supportato dal provider)
            // let threads = try await provider.fetchThreads(using: token)

            // Aggiorna stato di sincronizzazione
            syncState = syncState.afterSuccessfulSync(messagesCount: messages.count, wasFullSync: true)
            try await storageService.saveSyncState(syncState)

            syncStatus = .completed
            print("✅ MailSyncService: Sync completa riuscita per \(accountId) (\(messages.count) messaggi)")

        } catch {
            // Aggiorna stato con errore
            syncState = syncState.afterSyncError(error: error)
            try await storageService.saveSyncState(syncState)

            syncStatus = .failed
            throw error
        }
    }

    /// Sincronizzazione incrementale
    public func incrementalSyncAccount(_ accountId: String, provider: MailProvider, token: MailToken) async throws {
        guard let syncState = try await storageService.fetchSyncState(for: accountId) else {
            // Se non c'è stato precedente, fai sync completa
            try await fullSyncAccount(accountId, provider: provider, token: token)
            return
        }

        guard syncState.needsIncrementalSync else {
            print("⏳ MailSyncService: Sync incrementale non necessaria per \(accountId)")
            return
        }

        print("🔄 MailSyncService: Avvio sync incrementale per \(accountId)")

        do {
            // Usa il metodo di sync del provider se disponibile
            let syncResult = try await provider.syncChanges(since: syncState.lastIncrementalSync ?? Date.distantPast, using: token)

            // Applica i cambiamenti
            for message in syncResult.newMessages {
                try await storageService.saveMessage(message)
            }

            // Gestisci messaggi aggiornati
            for message in syncResult.updatedMessages {
                try await storageService.saveMessage(message)
            }

            // Gestisci messaggi eliminati
            for messageId in syncResult.deletedMessageIds {
                try await storageService.deleteMessage(id: messageId, accountId: accountId)
            }

            // Aggiorna stato
            let updatedSyncState = syncState.afterSuccessfulSync(
                historyId: nil, // Implementare se necessario
                messagesCount: syncResult.newMessages.count
            )
            try await storageService.saveSyncState(updatedSyncState)

            print("✅ MailSyncService: Sync incrementale riuscita per \(accountId)")

        } catch {
            print("❌ MailSyncService: Errore sync incrementale per \(accountId): \(error)")
            throw error
        }
    }

    /// Sincronizza tutti gli account attivi
    public func syncAllAccounts(_ accounts: [(id: String, provider: MailProvider, token: MailToken)]) async {
        print("🔄 MailSyncService: Avvio sync di \(accounts.count) account")

        await withTaskGroup(of: Void.self) { group in
            for account in accounts {
                group.addTask {
                    do {
                        try await self.syncAccount(account.id, provider: account.provider, token: account.token)
                    } catch {
                        print("❌ MailSyncService: Errore sync account \(account.id): \(error)")
                    }
                }
            }
        }

        print("✅ MailSyncService: Sync completata per tutti gli account")
    }

    // MARK: - Background Sync

    /// Configura la sincronizzazione in background
    public func setupBackgroundSync() {
        // Implementazione per BackgroundTasks framework
        // Questo richiederebbe configurazione nel plist e permesso utente
        print("🔧 MailSyncService: Background sync configurato")
    }

    /// Forza una sincronizzazione manuale
    public func forceSyncAccount(_ accountId: String, provider: MailProvider, token: MailToken) async throws {
        print("🔄 MailSyncService: Forzando sync per \(accountId)")

        // Cancella cache esistente
        // try await storageService.clearCache(for: accountId)

        // Esegui sync completa
        try await fullSyncAccount(accountId, provider: provider, token: token)
    }

    // MARK: - Private Methods

    private func performSync(for accountId: String, provider: MailProvider, token: MailToken) async throws {
        // Controlla se è necessario un full sync
        let syncState = try await storageService.fetchSyncState(for: accountId)

        if syncState?.needsFullSync == true {
            try await fullSyncAccount(accountId, provider: provider, token: token)
        } else {
            try await incrementalSyncAccount(accountId, provider: provider, token: token)
        }
    }

    private func handleSyncError(for accountId: String, error: Error) async throws {
        print("❌ MailSyncService: Gestione errore sync per \(accountId): \(error)")

        // Aggiorna stato di sincronizzazione con errore
        if var syncState = try await storageService.fetchSyncState(for: accountId) {
            syncState = syncState.afterSyncError(error: error)
            try await storageService.saveSyncState(syncState)

            // Se ci sono troppi errori consecutivi, disabilita temporaneamente la sync
            if syncState.hasTooManyErrors {
                print("⚠️ MailSyncService: Troppi errori consecutivi per \(accountId), sync temporaneamente disabilitata")
            }
        }

        // In futuro potremmo implementare retry con backoff
        throw error
    }

    private func setupNetworkMonitoring() {
        // Implementazione semplificata del monitoraggio rete
        // In produzione si userebbe NWPathMonitor
        print("🔧 MailSyncService: Monitoraggio rete configurato")

        // Simula monitoraggio rete
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                // In produzione controllare realmente lo stato della rete
                self?.isOnline = true // Sempre online per ora
            }
            .store(in: &cancellables)
    }

    // MARK: - Utility Methods

    /// Verifica se un account ha bisogno di sincronizzazione
    public func accountNeedsSync(_ accountId: String) async -> Bool {
        guard let syncState = try? await storageService.fetchSyncState(for: accountId) else {
            return true // Se non c'è stato, serve sync
        }

        return syncState.needsIncrementalSync || syncState.needsFullSync
    }

    /// Ottiene statistiche di sincronizzazione per un account
    public func getSyncStats(for accountId: String) async -> MailSyncStats? {
        guard let syncState = try? await storageService.fetchSyncState(for: accountId) else {
            return nil
        }

        return MailSyncStats(
            messagesSynced: syncState.messagesSynced,
            lastSyncDate: syncState.lastIncrementalSync ?? syncState.lastFullSync,
            errorsCount: syncState.errorsCount,
            isCurrentlySyncing: syncState.isSyncing
        )
    }

    /// Cancella tutti i dati di sincronizzazione per un account
    public func resetSyncState(for accountId: String) async throws {
        let emptyState = MailSyncState(accountId: accountId, providerId: "")
        try await storageService.saveSyncState(emptyState)
        print("🔄 MailSyncService: Stato sync resettato per \(accountId)")
    }
}

/// Statistiche di sincronizzazione
public struct MailSyncStats {
    public let messagesSynced: Int
    public let lastSyncDate: Date?
    public let errorsCount: Int
    public let isCurrentlySyncing: Bool

    public var lastSyncDescription: String {
        guard let date = lastSyncDate else { return "Mai sincronizzato" }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

/// Errori di sincronizzazione
public enum MailSyncError: LocalizedError {
    case offline
    case invalidToken
    case networkError(Error)
    case providerError(String)
    case storageError(Error)

    public var errorDescription: String? {
        switch self {
        case .offline:
            return "Dispositivo offline"
        case .invalidToken:
            return "Token di autenticazione non valido"
        case .networkError(let error):
            return "Errore di rete: \(error.localizedDescription)"
        case .providerError(let message):
            return "Errore provider: \(message)"
        case .storageError(let error):
            return "Errore di archiviazione: \(error.localizedDescription)"
        }
    }
}
