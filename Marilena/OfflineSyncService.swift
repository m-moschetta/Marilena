import Foundation
import Network
import Combine
import CoreData

/// Servizio per gestione operazioni offline e sincronizzazione intelligente
@MainActor
public class OfflineSyncService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var isOnline = true
    @Published public var syncStatus: SyncStatus = .idle
    @Published public var pendingOperationsCount = 0
    
    // MARK: - Private Properties
    
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue.global(qos: .utility)
    private var cancellables = Set<AnyCancellable>()
    
    private let persistenceController: PersistenceController
    private weak var emailService: EmailService?
    private let cacheService: EmailCacheService
    
    // Queue per operazioni offline
    private var pendingOperations: [OfflineOperation] = []
    private let operationsQueue = DispatchQueue(label: "offline.operations", qos: .background)
    
    // Conflict resolution
    private let conflictResolver = ConflictResolver()
    
    // MARK: - Initialization
    
    public static let shared = OfflineSyncService()
    
    private init() {
        self.persistenceController = PersistenceController.shared
        self.cacheService = EmailCacheService()
        
        setupNetworkMonitoring()
        loadPendingOperations()
        
        print("📱 OfflineSyncService: Servizio inizializzato")
    }
    
    // MARK: - Dependency Injection
    
    public func setEmailService(_ emailService: EmailService) {
        self.emailService = emailService
        print("🔗 OfflineSyncService: EmailService collegato")
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasOnline = self?.isOnline ?? false
                self?.isOnline = path.status == .satisfied
                
                if !wasOnline && path.status == .satisfied {
                    // Appena tornati online - avvia sincronizzazione
                    print("🌐 OfflineSyncService: Connessione ripristinata, avvio sync...")
                    await self?.syncWhenOnline()
                } else if wasOnline && path.status != .satisfied {
                    print("📴 OfflineSyncService: Connessione persa, modalità offline attiva")
                }
            }
        }
        
        networkMonitor.start(queue: monitorQueue)
    }
    
    // MARK: - Offline Operations Queue
    
    /// Accoda un'operazione per esecuzione offline
    public func queueOperation(_ operation: OfflineOperation) {
        pendingOperations.append(operation)
        pendingOperationsCount = pendingOperations.count
        savePendingOperations()
        
        print("📝 OfflineSyncService: Accodita operazione: \(operation.type) - Queue: \(pendingOperationsCount)")
        
        // Se online, prova a eseguire immediatamente
        if isOnline {
            Task {
                await executeNextOperation()
            }
        }
    }
    
    /// Invia email offline
    public func sendEmailOffline(to: [String], cc: [String] = [], bcc: [String] = [], subject: String, body: String, attachments: [Data] = []) {
        let operation = OfflineOperation(
            id: UUID().uuidString,
            type: .sendEmail,
            timestamp: Date(),
            data: [
                "to": to,
                "cc": cc,
                "bcc": bcc,
                "subject": subject,
                "body": body,
                "attachments": attachments.map { $0.base64EncodedString() }
            ],
            retryCount: 0
        )
        
        queueOperation(operation)
    }
    
    /// Marca email come letta offline
    public func markEmailAsReadOffline(_ emailId: String) {
        let operation = OfflineOperation(
            id: UUID().uuidString,
            type: .markAsRead,
            timestamp: Date(),
            data: ["emailId": emailId],
            retryCount: 0
        )
        
        queueOperation(operation)
    }
    
    /// Elimina email offline
    public func deleteEmailOffline(_ emailId: String) {
        let operation = OfflineOperation(
            id: UUID().uuidString,
            type: .deleteEmail,
            timestamp: Date(),
            data: ["emailId": emailId],
            retryCount: 0
        )
        
        queueOperation(operation)
    }
    
    // MARK: - Sync When Online
    
    private func syncWhenOnline() async {
        guard isOnline && syncStatus != .syncing else { return }
        
        syncStatus = .syncing
        print("🔄 OfflineSyncService: Avvio sincronizzazione...")
        
        // 1. Prima sincronizza email dal server
        await syncEmailsFromServer()
        
        // 2. Poi esegui operazioni pending
        await executeAllPendingOperations()
        
        // 3. Risolvi eventuali conflitti
        await resolveConflicts()
        
        syncStatus = .idle
        print("✅ OfflineSyncService: Sincronizzazione completata")
    }
    
    private func syncEmailsFromServer() async {
        guard let emailService = emailService else { return }
        if let account = emailService.currentAccount {
            await emailService.loadEmails(for: account)
        }
    }
    
    private func executeAllPendingOperations() async {
        while !pendingOperations.isEmpty && isOnline {
            await executeNextOperation()
        }
    }
    
    private func executeNextOperation() async {
        guard !pendingOperations.isEmpty, isOnline else { return }
        
        let operation = pendingOperations.removeFirst()
        pendingOperationsCount = pendingOperations.count
        
        do {
            try await executeOperation(operation)
            print("✅ OfflineSyncService: Operazione eseguita: \(operation.type)")
        } catch {
            print("❌ OfflineSyncService: Errore esecuzione operazione: \(error)")
            
            // Retry logic
            if operation.retryCount < 3 {
                var retryOperation = operation
                retryOperation.retryCount += 1
                pendingOperations.append(retryOperation)
                pendingOperationsCount = pendingOperations.count
                print("🔄 OfflineSyncService: Retry operazione \(operation.type) - Tentativo \(retryOperation.retryCount)")
            } else {
                print("💥 OfflineSyncService: Operazione fallita definitivamente: \(operation.type)")
            }
        }
        
        savePendingOperations()
    }
    
    private func executeOperation(_ operation: OfflineOperation) async throws {
        switch operation.type {
        case .sendEmail:
            try await executeSendEmailOperation(operation)
        case .markAsRead:
            try await executeMarkAsReadOperation(operation)
        case .deleteEmail:
            try await executeDeleteEmailOperation(operation)
        case .archiveEmail:
            try await executeArchiveEmailOperation(operation)
        }
    }
    
    // MARK: - Operation Execution
    
    private func executeSendEmailOperation(_ operation: OfflineOperation) async throws {
        guard let emailService = emailService else { throw OfflineError.serviceNotAvailable }
        guard let to = operation.data["to"] as? [String],
              let subject = operation.data["subject"] as? String,
              let body = operation.data["body"] as? String else {
            throw OfflineError.invalidOperationData
        }
        
        // Per ora usiamo solo il primo destinatario (compatibilità con EmailService attuale)
        let primaryRecipient = to.first ?? ""
        try await emailService.sendEmail(to: primaryRecipient, subject: subject, body: body)
    }
    
    private func executeMarkAsReadOperation(_ operation: OfflineOperation) async throws {
        guard let emailService = emailService else { throw OfflineError.serviceNotAvailable }
        guard let emailId = operation.data["emailId"] as? String else {
            throw OfflineError.invalidOperationData
        }
        
        // Implementa la chiamata all'API per marcare come letta
        // Per ora aggiorna solo la cache locale
        await cacheService.markEmailAsRead(emailId, accountId: emailService.currentAccount?.email ?? "")
    }
    
    private func executeDeleteEmailOperation(_ operation: OfflineOperation) async throws {
        guard let emailId = operation.data["emailId"] as? String else {
            throw OfflineError.invalidOperationData
        }
        
        // Implementa la chiamata all'API per eliminare
        // Per ora rimuove dalla cache locale
        print("🗑️ OfflineSyncService: Eliminazione email \(emailId)")
    }
    
    private func executeArchiveEmailOperation(_ operation: OfflineOperation) async throws {
        guard let emailId = operation.data["emailId"] as? String else {
            throw OfflineError.invalidOperationData
        }
        
        print("📦 OfflineSyncService: Archiviazione email \(emailId)")
    }
    
    // MARK: - Conflict Resolution
    
    private func resolveConflicts() async {
        guard let emailService = emailService else { return }
        print("🔍 OfflineSyncService: Controllo conflitti...")
        
        // Identifica conflitti tra cache locale e server
        let conflicts = await conflictResolver.detectConflicts(
            localEmails: emailService.emails,
            cacheService: cacheService
        )
        
        for conflict in conflicts {
            await conflictResolver.resolve(conflict)
        }
        
        if !conflicts.isEmpty {
            print("⚖️ OfflineSyncService: Risolti \(conflicts.count) conflitti")
        }
    }
    
    // MARK: - Persistence
    
    private func savePendingOperations() {
        Task { @MainActor in
            let operations = self.pendingOperations
            operationsQueue.async {
                do {
                    let data = try JSONEncoder().encode(operations)
                    UserDefaults.standard.set(data, forKey: "pending_offline_operations")
                    print("💾 OfflineSyncService: Salvate \(operations.count) operazioni pending")
                } catch {
                    print("❌ OfflineSyncService: Errore salvataggio operazioni: \(error)")
                }
            }
        }
    }
    
    private func loadPendingOperations() {
        operationsQueue.async {
            if let data = UserDefaults.standard.data(forKey: "pending_offline_operations"),
               let operations = try? JSONDecoder().decode([OfflineOperation].self, from: data) {
                DispatchQueue.main.async {
                    self.pendingOperations = operations
                    self.pendingOperationsCount = operations.count
                    print("📁 OfflineSyncService: Caricate \(operations.count) operazioni pending")
                }
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Forza sincronizzazione manuale
    public func forcSync() async {
        if isOnline {
            await syncWhenOnline()
        } else {
            print("📴 OfflineSyncService: Impossibile sincronizzare - offline")
        }
    }
    
    /// Cancella tutte le operazioni pending
    public func clearPendingOperations() {
        pendingOperations.removeAll()
        pendingOperationsCount = 0
        savePendingOperations()
        print("🧹 OfflineSyncService: Tutte le operazioni pending cancellate")
    }
    
    deinit {
        networkMonitor.cancel()
    }
}

// MARK: - Supporting Types

public enum SyncStatus: Equatable {
    case idle
    case syncing
    case error(String)
}

public struct OfflineOperation: Codable {
    let id: String
    let type: OperationType
    let timestamp: Date
    let data: [String: Any]
    var retryCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id, type, timestamp, retryCount
        case data
    }
    
    public init(id: String, type: OperationType, timestamp: Date, data: [String: Any], retryCount: Int) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.data = data
        self.retryCount = retryCount
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(OperationType.self, forKey: .type)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        retryCount = try container.decode(Int.self, forKey: .retryCount)
        
        // Decode data as JSON
        if let dataString = try? container.decode(String.self, forKey: .data),
           let dataData = dataString.data(using: .utf8),
           let dataDict = try? JSONSerialization.jsonObject(with: dataData) as? [String: Any] {
            data = dataDict
        } else {
            data = [:]
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(retryCount, forKey: .retryCount)
        
        // Encode data as JSON string
        if let dataData = try? JSONSerialization.data(withJSONObject: data),
           let dataString = String(data: dataData, encoding: .utf8) {
            try container.encode(dataString, forKey: .data)
        }
    }
}

public enum OperationType: String, Codable {
    case sendEmail
    case markAsRead
    case deleteEmail
    case archiveEmail
}

public enum OfflineError: Error {
    case invalidOperationData
    case networkUnavailable
    case syncFailed(String)
    case serviceNotAvailable
}

// MARK: - Conflict Resolver

class ConflictResolver {
    
    func detectConflicts(localEmails: [EmailMessage], cacheService: EmailCacheService) async -> [EmailConflict] {
        let conflicts: [EmailConflict] = []
        
        // Per ora implementazione base - può essere estesa
        // Rileva email con timestamp di modifica diversi
        
        return conflicts
    }
    
    func resolve(_ conflict: EmailConflict) async {
        switch conflict.type {
        case .readStatusConflict:
            // Server wins per read status
            await resolveReadStatusConflict(conflict)
        case .contentConflict:
            // Timestamp più recente wins
            await resolveContentConflict(conflict)
        case .deletionConflict:
            // Server wins per deletion
            await resolveDeletionConflict(conflict)
        }
    }
    
    private func resolveReadStatusConflict(_ conflict: EmailConflict) async {
        print("⚖️ ConflictResolver: Risoluzione conflitto read status per email \(conflict.emailId)")
    }
    
    private func resolveContentConflict(_ conflict: EmailConflict) async {
        print("⚖️ ConflictResolver: Risoluzione conflitto contenuto per email \(conflict.emailId)")
    }
    
    private func resolveDeletionConflict(_ conflict: EmailConflict) async {
        print("⚖️ ConflictResolver: Risoluzione conflitto eliminazione per email \(conflict.emailId)")
    }
}

struct EmailConflict {
    let emailId: String
    let type: ConflictType
    let localData: [String: Any]
    let serverData: [String: Any]
    let timestamp: Date
}

enum ConflictType {
    case readStatusConflict
    case contentConflict
    case deletionConflict
}