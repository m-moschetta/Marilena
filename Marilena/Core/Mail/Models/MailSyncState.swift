import Foundation

/// Stato di sincronizzazione per un account email
public struct MailSyncState: Codable, Identifiable {
    public let id: String
    public let accountId: String
    public let providerId: String

    // Cursori/tokens per la sincronizzazione incrementale
    public let historyId: String?
    public let etag: String?
    public let lastMessageId: String?

    // Timestamp delle operazioni
    public let lastFullSync: Date?
    public let lastIncrementalSync: Date?
    public let lastErrorAt: Date?

    // Statistiche di sincronizzazione
    public let messagesSynced: Int
    public let errorsCount: Int
    public let consecutiveErrors: Int

    // Stato corrente
    public let isSyncing: Bool
    public let syncStatus: MailSyncStatus

    /// Verifica se è necessario fare una sincronizzazione completa
    public var needsFullSync: Bool {
        guard let lastFull = lastFullSync else { return true }

        // Sincronizzazione completa ogni 24 ore
        let fullSyncInterval: TimeInterval = 24 * 60 * 60
        return Date().timeIntervalSince(lastFull) > fullSyncInterval
    }

    /// Verifica se è necessario fare una sincronizzazione incrementale
    public var needsIncrementalSync: Bool {
        guard let lastIncremental = lastIncrementalSync else { return true }

        // Sincronizzazione incrementale ogni 5 minuti
        let incrementalInterval: TimeInterval = 5 * 60
        return Date().timeIntervalSince(lastIncremental) > incrementalInterval
    }

    /// Verifica se ci sono troppi errori consecutivi
    public var hasTooManyErrors: Bool {
        consecutiveErrors >= 5
    }

    public init(
        id: String = UUID().uuidString,
        accountId: String,
        providerId: String,
        historyId: String? = nil,
        etag: String? = nil,
        lastMessageId: String? = nil,
        lastFullSync: Date? = nil,
        lastIncrementalSync: Date? = nil,
        lastErrorAt: Date? = nil,
        messagesSynced: Int = 0,
        errorsCount: Int = 0,
        consecutiveErrors: Int = 0,
        isSyncing: Bool = false,
        syncStatus: MailSyncStatus = .idle
    ) {
        self.id = id
        self.accountId = accountId
        self.providerId = providerId
        self.historyId = historyId
        self.etag = etag
        self.lastMessageId = lastMessageId
        self.lastFullSync = lastFullSync
        self.lastIncrementalSync = lastIncrementalSync
        self.lastErrorAt = lastErrorAt
        self.messagesSynced = messagesSynced
        self.errorsCount = errorsCount
        self.consecutiveErrors = consecutiveErrors
        self.isSyncing = isSyncing
        self.syncStatus = syncStatus
    }

    /// Crea un nuovo stato dopo una sincronizzazione riuscita
    public func afterSuccessfulSync(
        historyId: String? = nil,
        etag: String? = nil,
        lastMessageId: String? = nil,
        messagesCount: Int,
        wasFullSync: Bool = false
    ) -> MailSyncState {
        MailSyncState(
            id: id,
            accountId: accountId,
            providerId: providerId,
            historyId: historyId ?? self.historyId,
            etag: etag ?? self.etag,
            lastMessageId: lastMessageId ?? self.lastMessageId,
            lastFullSync: wasFullSync ? Date() : lastFullSync,
            lastIncrementalSync: Date(),
            lastErrorAt: lastErrorAt,
            messagesSynced: messagesSynced + messagesCount,
            errorsCount: errorsCount,
            consecutiveErrors: 0, // Reset errori consecutivi
            isSyncing: false,
            syncStatus: .completed
        )
    }

    /// Crea un nuovo stato dopo un errore di sincronizzazione
    public func afterSyncError(error: Error) -> MailSyncState {
        MailSyncState(
            id: id,
            accountId: accountId,
            providerId: providerId,
            historyId: historyId,
            etag: etag,
            lastMessageId: lastMessageId,
            lastFullSync: lastFullSync,
            lastIncrementalSync: lastIncrementalSync,
            lastErrorAt: Date(),
            messagesSynced: messagesSynced,
            errorsCount: errorsCount + 1,
            consecutiveErrors: consecutiveErrors + 1,
            isSyncing: false,
            syncStatus: .failed
        )
    }

    /// Crea un nuovo stato durante la sincronizzazione
    public func duringSync() -> MailSyncState {
        MailSyncState(
            id: id,
            accountId: accountId,
            providerId: providerId,
            historyId: historyId,
            etag: etag,
            lastMessageId: lastMessageId,
            lastFullSync: lastFullSync,
            lastIncrementalSync: lastIncrementalSync,
            lastErrorAt: lastErrorAt,
            messagesSynced: messagesSynced,
            errorsCount: errorsCount,
            consecutiveErrors: consecutiveErrors,
            isSyncing: true,
            syncStatus: .inProgress
        )
    }
}

/// Stato della sincronizzazione
public enum MailSyncStatus: String, Codable {
    case idle
    case inProgress
    case completed
    case failed
    case cancelled
}

/// Interazione calendario per un contatto
public struct MailCalendarInteraction: Codable, Identifiable {
    public let id: String
    public let participantEmail: String
    public let events: [MailCalendarEvent]
    public let recordings: [MailRecordingInfo]
    public let lastContactedAt: Date
    public let totalInteractions: Int

    /// Eventi futuri con questo contatto
    public var upcomingEvents: [MailCalendarEvent] {
        events.filter { $0.startDate > Date() }
    }

    /// Registrazioni recenti
    public var recentRecordings: [MailRecordingInfo] {
        recordings
            .filter { $0.createdAt > Date().addingTimeInterval(-30 * 24 * 60 * 60) } // Ultimi 30 giorni
            .sorted { $0.createdAt > $1.createdAt }
    }

    public init(
        id: String = UUID().uuidString,
        participantEmail: String,
        events: [MailCalendarEvent] = [],
        recordings: [MailRecordingInfo] = [],
        lastContactedAt: Date,
        totalInteractions: Int = 0
    ) {
        self.id = id
        self.participantEmail = participantEmail
        self.events = events
        self.recordings = recordings
        self.lastContactedAt = lastContactedAt
        self.totalInteractions = totalInteractions
    }
}

/// Evento calendario
public struct MailCalendarEvent: Codable, Identifiable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let location: String?
    public let description: String?
    public let isAllDay: Bool

    public init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        location: String? = nil,
        description: String? = nil,
        isAllDay: Bool = false
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.description = description
        self.isAllDay = isAllDay
    }
}

/// Informazioni su una registrazione
public struct MailRecordingInfo: Codable, Identifiable {
    public let id: String
    public let title: String
    public let createdAt: Date
    public let duration: TimeInterval?
    public let transcription: String?

    public init(
        id: String,
        title: String,
        createdAt: Date,
        duration: TimeInterval? = nil,
        transcription: String? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.duration = duration
        self.transcription = transcription
    }
}
