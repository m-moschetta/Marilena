//
//  MailSyncEngine.swift
//  Marilena
//
//  Created by Marilena on 2024
//
//  Engine di sincronizzazione per gestire sync incrementali,
//  retry logic, deduplicazione e reconciliation
//

import Foundation
import Combine

/// Engine principale per la sincronizzazione email
public final class MailSyncEngine {

    // MARK: - Properties

    private let transportCoordinator: MailTransportCoordinator
    private let storage: MailStorageProtocol
    private let retryPolicy: MailRetryPolicy
    private let queue = DispatchQueue(label: "com.marilena.mail.sync", qos: .background)

    private var activeSyncs: [String: AnyCancellable] = [:] // accountId -> cancellable
    private var syncStates: [String: MailSyncState] = [:] // accountId -> state

    // MARK: - Initialization

    public init(
        transportCoordinator: MailTransportCoordinator,
        storage: MailStorageProtocol,
        retryPolicy: MailRetryPolicy = .default
    ) {
        self.transportCoordinator = transportCoordinator
        self.storage = storage
        self.retryPolicy = retryPolicy
    }

    // MARK: - Public Methods

    /// Avvia la sincronizzazione per un account
    public func startSync(for account: MailAccount, options: MailSyncOptions = .init()) -> AnyPublisher<MailSyncProgress, MailSyncError> {
        let accountId = account.id

        return Future { [weak self] promise in
            guard let self = self else { return }

            self.queue.async {
                // Controlla se c'è già una sync in corso
                if self.activeSyncs[accountId] != nil {
                    promise(.failure(.syncAlreadyInProgress))
                    return
                }

                // Inizializza lo stato di sync
                let syncState = MailSyncState(accountId: accountId, startTime: Date(), lastUpdate: Date())
                self.syncStates[accountId] = syncState

                // Avvia la sync
                let cancellable = self.performSync(for: account, options: options)
                    .sink(
                        receiveCompletion: { [weak self] completion in
                            guard let self = self else { return }

                            self.queue.async {
                                // Pulisci lo stato
                                self.activeSyncs[accountId] = nil
                                self.syncStates[accountId] = nil

                                switch completion {
                                case .finished:
                                    promise(.success(.completed))
                                case .failure(let error):
                                    promise(.failure(error))
                                }
                            }
                        },
                        receiveValue: { [weak self] progress in
                            guard let self = self else { return }

                            self.queue.async {
                                // Aggiorna lo stato
                                if var state = self.syncStates[accountId] {
                                    state.lastUpdate = Date()
                                    self.syncStates[accountId] = state
                                }

                                // Inoltra il progresso
                                promise(.success(progress))
                            }
                        }
                    )

                self.activeSyncs[accountId] = cancellable
            }
        }
        .eraseToAnyPublisher()
    }

    /// Ferma la sincronizzazione per un account
    public func stopSync(for accountId: String) {
        queue.async {
            self.activeSyncs[accountId]?.cancel()
            self.activeSyncs[accountId] = nil
            self.syncStates[accountId] = nil
        }
    }

    /// Ottiene lo stato di sincronizzazione per un account
    public func syncState(for accountId: String) -> MailSyncState? {
        queue.sync {
            syncStates[accountId]
        }
    }

    // MARK: - Private Methods

    private func performSync(for account: MailAccount, options: MailSyncOptions) -> AnyPublisher<MailSyncProgress, MailSyncError> {
        let accountId = account.id

        return transportCoordinator.syncEmails(for: account, options: options)
            .mapError { MailSyncError.transportError($0) }
            .flatMap { [weak self] update -> AnyPublisher<MailSyncProgress, MailSyncError> in
                guard let self = self else {
                    return Empty().eraseToAnyPublisher()
                }

                return self.processSyncUpdate(update, for: accountId)
            }
            .retryWithPolicy(retryPolicy)
            .eraseToAnyPublisher()
    }

    private func processSyncUpdate(_ update: MailSyncUpdate, for accountId: String) -> AnyPublisher<MailSyncProgress, MailSyncError> {
        switch update {
        case .started:
            return Just(.started).setFailureType(to: MailSyncError.self).eraseToAnyPublisher()

        case .progress(let current, let total):
            let progress = MailSyncProgress.progress(current: current, total: total)
            return Just(progress).setFailureType(to: MailSyncError.self).eraseToAnyPublisher()

        case .newMessages(let messages):
            return processNewMessages(messages, for: accountId)

        case .updatedMessages(let messages):
            return processUpdatedMessages(messages, for: accountId)

        case .deletedMessages(let messageIds):
            return processDeletedMessages(messageIds, for: accountId)

        case .completed:
            return Just(.completed).setFailureType(to: MailSyncError.self).eraseToAnyPublisher()

        case .error(let error):
            return Fail(error: .transportError(error)).eraseToAnyPublisher()
        }
    }

    private func processNewMessages(_ messages: [MailMessage], for accountId: String) -> AnyPublisher<MailSyncProgress, MailSyncError> {
        Future { [weak self] promise in
            guard let self = self else { return }

            Task {
                do {
                    // Salva i nuovi messaggi
                    try await self.storage.saveMessages(messages, for: accountId)

                    // Aggiorna i thread se necessario
                    try await self.updateThreads(for: messages, accountId: accountId)

                    // Calcola il progresso
                    let progress = MailSyncProgress.newMessages(count: messages.count)
                    promise(.success(progress))

                } catch {
                    promise(.failure(.storageError(error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    private func processUpdatedMessages(_ messages: [MailMessage], for accountId: String) -> AnyPublisher<MailSyncProgress, MailSyncError> {
        Future { [weak self] promise in
            guard let self = self else { return }

            Task {
                do {
                    try await self.storage.updateMessages(messages, for: accountId)
                    let progress = MailSyncProgress.updatedMessages(count: messages.count)
                    promise(.success(progress))

                } catch {
                    promise(.failure(.storageError(error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    private func processDeletedMessages(_ messageIds: [String], for accountId: String) -> AnyPublisher<MailSyncProgress, MailSyncError> {
        Future { [weak self] promise in
            guard let self = self else { return }

            Task {
                do {
                    try await self.storage.deleteMessages(messageIds, for: accountId)
                    let progress = MailSyncProgress.deletedMessages(count: messageIds.count)
                    promise(.success(progress))

                } catch {
                    promise(.failure(.storageError(error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    private func updateThreads(for messages: [MailMessage], accountId: String) async throws {
        // Raggruppa messaggi per thread
        let threadGroups = Dictionary(grouping: messages) { $0.threadId ?? $0.id }

        for (threadId, threadMessages) in threadGroups {
            var thread = try await storage.getThread(threadId, for: accountId)

            if thread == nil {
                // Crea nuovo thread
                let firstMessage = threadMessages.first!
                thread = MailThread(
                    id: threadId,
                    subject: firstMessage.subject,
                    messages: threadMessages.map { $0.id },
                    participants: Set(threadMessages.flatMap { [$0.from.email] + $0.to.map { $0.email } + $0.cc.map { $0.email } }),
                    labels: Set(threadMessages.flatMap { $0.labels }),
                    createdAt: firstMessage.date,
                    updatedAt: firstMessage.date
                )
            } else {
                // Aggiorna thread esistente
                thread!.messages.append(contentsOf: threadMessages.map { $0.id })
                thread!.participants.formUnion(threadMessages.flatMap { [$0.from.email] + $0.to.map { $0.email } + $0.cc.map { $0.email } })
                thread!.labels.formUnion(threadMessages.flatMap { $0.labels })
                thread!.updatedAt = Date()
            }

            if let thread = thread {
                try await storage.saveThread(thread, for: accountId)
            }
        }
    }
}

// MARK: - Supporting Types

/// Stato di sincronizzazione
public struct MailSyncState {
    public let accountId: String
    public let startTime: Date
    public var lastUpdate: Date
    public var messagesProcessed: Int = 0
    public var errors: [Error] = []
}

/// Progresso della sincronizzazione
public enum MailSyncProgress {
    case started
    case progress(current: Int, total: Int)
    case newMessages(count: Int)
    case updatedMessages(count: Int)
    case deletedMessages(count: Int)
    case completed
}

/// Policy di retry
public struct MailRetryPolicy {
    public let maxAttempts: Int
    public let initialDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let backoffMultiplier: Double

    public static let `default` = MailRetryPolicy(
        maxAttempts: 3,
        initialDelay: 1.0,
        maxDelay: 30.0,
        backoffMultiplier: 2.0
    )
}

/// Errori di sincronizzazione
public enum MailSyncError: LocalizedError {
    case syncAlreadyInProgress
    case transportError(MailProviderError)
    case storageError(Error)
    case networkError(String)

    public var errorDescription: String? {
        switch self {
        case .syncAlreadyInProgress:
            return "Sincronizzazione già in corso"
        case .transportError(let error):
            return "Errore di trasporto: \(error.localizedDescription)"
        case .storageError(let error):
            return "Errore di archiviazione: \(error.localizedDescription)"
        case .networkError(let message):
            return "Errore di rete: \(message)"
        }
    }
}

// MARK: - Extensions

private extension Publisher {
    func retryWithPolicy(_ policy: MailRetryPolicy) -> AnyPublisher<Output, Failure> {
        self.retry(policy.maxAttempts)
            .eraseToAnyPublisher()
    }
}
