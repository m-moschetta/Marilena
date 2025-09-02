//
//  MailStorageProtocol.swift
//  Marilena
//
//  Created by Marilena on 2024
//
//  Protocollo per il layer di storage email
//  Definisce l'interfaccia per salvare/caricare messaggi, thread, labels, ecc.
//

import Foundation
import Combine

/// Protocollo per il storage dei dati email
public protocol MailStorageProtocol {

    // MARK: - Messages

    /// Salva messaggi nel storage
    func saveMessages(_ messages: [MailMessage], for accountId: String) async throws

    /// Aggiorna messaggi esistenti
    func updateMessages(_ messages: [MailMessage], for accountId: String) async throws

    /// Elimina messaggi
    func deleteMessages(_ messageIds: [String], for accountId: String) async throws

    /// Carica messaggi con filtri
    func loadMessages(for accountId: String, filter: MailMessageFilter?) async throws -> [MailMessage]

    /// Ottiene un messaggio specifico
    func getMessage(_ messageId: String, for accountId: String) async throws -> MailMessage?

    // MARK: - Threads

    /// Salva un thread
    func saveThread(_ thread: MailThread, for accountId: String) async throws

    /// Carica thread con filtri
    func loadThreads(for accountId: String, filter: MailThreadFilter?) async throws -> [MailThread]

    /// Ottiene un thread specifico
    func getThread(_ threadId: String, for accountId: String) async throws -> MailThread?

    /// Elimina un thread
    func deleteThread(_ threadId: String, for accountId: String) async throws

    // MARK: - Labels

    /// Salva labels
    func saveLabels(_ labels: [MailLabel], for accountId: String) async throws

    /// Carica labels
    func loadLabels(for accountId: String) async throws -> [MailLabel]

    /// Ottiene una label specifica
    func getLabel(_ labelId: String, for accountId: String) async throws -> MailLabel?

    /// Elimina una label
    func deleteLabel(_ labelId: String, for accountId: String) async throws

    // MARK: - Filter Rules

    /// Salva regole di filtro
    func saveFilterRules(_ rules: [MailFilterRule], for accountId: String) async throws

    /// Carica regole di filtro
    func loadFilterRules(for accountId: String) async throws -> [MailFilterRule]

    /// Elimina una regola di filtro
    func deleteFilterRule(_ ruleId: String, for accountId: String) async throws

    // MARK: - Sync State

    /// Salva lo stato di sincronizzazione
    func saveSyncState(_ state: MailSyncStateEntity, for accountId: String) async throws

    /// Carica lo stato di sincronizzazione
    func loadSyncState(for accountId: String) async throws -> MailSyncStateEntity?

    // MARK: - Search

    /// Cerca messaggi
    func searchMessages(_ query: MailSearchQuery, for accountId: String) async throws -> [MailMessage]

    // MARK: - Maintenance

    /// Pulisce dati vecchi
    func cleanupOldData(olderThan days: Int, for accountId: String) async throws

    /// Ottimizza il database
    func optimizeStorage() async throws
}

/// Filtro per messaggi
public struct MailMessageFilter {
    public let threadId: String?
    public let labels: [String]?
    public let dateFrom: Date?
    public let dateTo: Date?
    public let isRead: Bool?
    public let hasAttachments: Bool?
    public let limit: Int?
    public let offset: Int?

    public init(
        threadId: String? = nil,
        labels: [String]? = nil,
        dateFrom: Date? = nil,
        dateTo: Date? = nil,
        isRead: Bool? = nil,
        hasAttachments: Bool? = nil,
        limit: Int? = nil,
        offset: Int? = nil
    ) {
        self.threadId = threadId
        self.labels = labels
        self.dateFrom = dateFrom
        self.dateTo = dateTo
        self.isRead = isRead
        self.hasAttachments = hasAttachments
        self.limit = limit
        self.offset = offset
    }
}

/// Filtro per thread
public struct MailThreadFilter {
    public let hasUnreadMessages: Bool?
    public let labels: [String]?
    public let participants: [String]?
    public let dateFrom: Date?
    public let dateTo: Date?
    public let isArchived: Bool?
    public let limit: Int?
    public let offset: Int?

    public init(
        hasUnreadMessages: Bool? = nil,
        labels: [String]? = nil,
        participants: [String]? = nil,
        dateFrom: Date? = nil,
        dateTo: Date? = nil,
        isArchived: Bool? = nil,
        limit: Int? = nil,
        offset: Int? = nil
    ) {
        self.hasUnreadMessages = hasUnreadMessages
        self.labels = labels
        self.participants = participants
        self.dateFrom = dateFrom
        self.dateTo = dateTo
        self.isArchived = isArchived
        self.limit = limit
        self.offset = offset
    }
}

/// Entità per lo stato di sincronizzazione
public struct MailSyncStateEntity {
    public let accountId: String
    public let lastSyncDate: Date?
    public let lastMessageId: String?
    public let etag: String?
    public let historyId: String?
    public let errorCount: Int
    public let lastError: String?

    public init(
        accountId: String,
        lastSyncDate: Date? = nil,
        lastMessageId: String? = nil,
        etag: String? = nil,
        historyId: String? = nil,
        errorCount: Int = 0,
        lastError: String? = nil
    ) {
        self.accountId = accountId
        self.lastSyncDate = lastSyncDate
        self.lastMessageId = lastMessageId
        self.etag = etag
        self.historyId = historyId
        self.errorCount = errorCount
        self.lastError = lastError
    }
}

/// Errori di storage
public enum MailStorageError: LocalizedError {
    case saveFailed(String)
    case loadFailed(String)
    case deleteFailed(String)
    case notFound(String)

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let message):
            return "Salvataggio fallito: \(message)"
        case .loadFailed(let message):
            return "Caricamento fallito: \(message)"
        case .deleteFailed(let message):
            return "Eliminazione fallita: \(message)"
        case .notFound(let message):
            return "Elemento non trovato: \(message)"
        }
    }
}
