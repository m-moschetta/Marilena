//
//  MailModels.swift
//  Marilena
//
//  Created by Marilena on 2024
//
//  Modelli dati comuni per il sistema email
//

import Foundation

/// Account email
public struct MailAccount: Identifiable, Codable, Equatable {
    public let id: String
    public let email: String
    public let provider: MailProviderType
    public let displayName: String?
    public let accessToken: String
    public let refreshToken: String?
    public let tokenExpiresAt: Date?
    public let scopes: [String]

    public init(
        id: String = UUID().uuidString,
        email: String,
        provider: MailProviderType,
        displayName: String? = nil,
        accessToken: String,
        refreshToken: String? = nil,
        tokenExpiresAt: Date? = nil,
        scopes: [String] = []
    ) {
        self.id = id
        self.email = email
        self.provider = provider
        self.displayName = displayName
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenExpiresAt = tokenExpiresAt
        self.scopes = scopes
    }

    public var isTokenExpired: Bool {
        guard let expiresAt = tokenExpiresAt else { return false }
        return Date() > expiresAt.addingTimeInterval(-300) // 5 minuti di margine
    }

    public static func == (lhs: MailAccount, rhs: MailAccount) -> Bool {
        lhs.id == rhs.id
    }
}

/// Messaggio email
public struct MailMessage: Identifiable, Codable {
    public let id: String
    public let threadId: String?
    public let subject: String
    public let body: MailBody
    public let from: MailParticipant
    public let to: [MailParticipant]
    public let cc: [MailParticipant]
    public let bcc: [MailParticipant]
    public let date: Date
    public let labels: [String]
    public let flags: MailFlags
    public let attachments: [MailAttachment]
    public let size: Int? // in bytes
    public let providerMessageId: String?
    public let inReplyTo: String?
    public let references: [String]

    public init(
        id: String,
        threadId: String? = nil,
        subject: String,
        body: MailBody,
        from: MailParticipant,
        to: [MailParticipant] = [],
        cc: [MailParticipant] = [],
        bcc: [MailParticipant] = [],
        date: Date,
        labels: [String] = [],
        flags: MailFlags = .init(),
        attachments: [MailAttachment] = [],
        size: Int? = nil,
        providerMessageId: String? = nil,
        inReplyTo: String? = nil,
        references: [String] = []
    ) {
        self.id = id
        self.threadId = threadId
        self.subject = subject
        self.body = body
        self.from = from
        self.to = to
        self.cc = cc
        self.bcc = bcc
        self.date = date
        self.labels = labels
        self.flags = flags
        self.attachments = attachments
        self.size = size
        self.providerMessageId = providerMessageId
        self.inReplyTo = inReplyTo
        self.references = references
    }
}

/// Corpo del messaggio
public struct MailBody: Codable {
    public let plainText: String?
    public let htmlText: String?
    public let contentType: MailContentType

    public init(
        plainText: String? = nil,
        htmlText: String? = nil,
        contentType: MailContentType = .plain
    ) {
        self.plainText = plainText
        self.htmlText = htmlText
        self.contentType = contentType
    }

    public var displayText: String {
        if contentType == .html, let html = htmlText {
            return html
        }
        return plainText ?? ""
    }
}

/// Tipo di contenuto
public enum MailContentType: String, Codable {
    case plain = "text/plain"
    case html = "text/html"
}

/// Partecipante email
public struct MailParticipant: Codable, Equatable {
    public let email: String
    public let name: String?

    public init(email: String, name: String? = nil) {
        self.email = email
        self.name = name
    }

    public var displayName: String {
        name ?? email
    }

    public static func == (lhs: MailParticipant, rhs: MailParticipant) -> Bool {
        lhs.email.lowercased() == rhs.email.lowercased()
    }
}

/// Flag del messaggio
public struct MailFlags: Codable, OptionSet {
    public let rawValue: Int

    public init(rawValue: Int = 0) {
        self.rawValue = rawValue
    }

    public static let seen = MailFlags(rawValue: 1 << 0)
    public static let flagged = MailFlags(rawValue: 1 << 1)
    public static let deleted = MailFlags(rawValue: 1 << 2)
    public static let draft = MailFlags(rawValue: 1 << 3)
    public static let answered = MailFlags(rawValue: 1 << 4)

    public var isRead: Bool {
        contains(.seen)
    }

    public var isFlagged: Bool {
        contains(.flagged)
    }

    public var isDeleted: Bool {
        contains(.deleted)
    }

    public var isDraft: Bool {
        contains(.draft)
    }

    public var isAnswered: Bool {
        contains(.answered)
    }
}

/// Allegato
public struct MailAttachment: Identifiable, Codable {
    public let id: String
    public let filename: String
    public let mimeType: String
    public let size: Int
    public let contentId: String?
    public let isInline: Bool

    public init(
        id: String,
        filename: String,
        mimeType: String,
        size: Int,
        contentId: String? = nil,
        isInline: Bool = false
    ) {
        self.id = id
        self.filename = filename
        self.mimeType = mimeType
        self.size = size
        self.contentId = contentId
        self.isInline = isInline
    }
}

/// Thread/Conversazione
public struct MailThread: Identifiable, Codable {
    public let id: String
    public let subject: String
    public var messages: [String] // IDs dei messaggi
    public var participants: Set<String>
    public var labels: Set<String>
    public let createdAt: Date
    public var updatedAt: Date
    public let isArchived: Bool

    public init(
        id: String,
        subject: String,
        messages: [String] = [],
        participants: Set<String> = [],
        labels: Set<String> = [],
        createdAt: Date,
        updatedAt: Date,
        isArchived: Bool = false
    ) {
        self.id = id
        self.subject = subject
        self.messages = messages
        self.participants = participants
        self.labels = labels
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
    }

    public var messageCount: Int {
        messages.count
    }

    public var hasUnreadMessages: Bool {
        // Questa informazione dovrebbe essere calcolata dal servizio
        // per ora restituiamo false
        false
    }
}

/// Label/Categoria
public struct MailLabel: Identifiable, Codable, Equatable {
    public let id: String
    public let name: String
    public let type: MailLabelType
    public let color: String?
    public let parentId: String?
    public let providerMapping: [String: String] // Mappatura provider-specifica

    public init(
        id: String,
        name: String,
        type: MailLabelType = .user,
        color: String? = nil,
        parentId: String? = nil,
        providerMapping: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.color = color
        self.parentId = parentId
        self.providerMapping = providerMapping
    }

    public static func == (lhs: MailLabel, rhs: MailLabel) -> Bool {
        lhs.id == rhs.id
    }
}

/// Tipo di label
public enum MailLabelType: String, Codable {
    case system = "system"
    case user = "user"
}





/// Opzioni di sincronizzazione
public struct MailSyncOptions: Codable {
    public let maxMessages: Int
    public let includeAttachments: Bool
    public let fullSync: Bool
    public let labelFilter: [String]?

    public init(
        maxMessages: Int = 100,
        includeAttachments: Bool = false,
        fullSync: Bool = false,
        labelFilter: [String]? = nil
    ) {
        self.maxMessages = maxMessages
        self.includeAttachments = includeAttachments
        self.fullSync = fullSync
        self.labelFilter = labelFilter
    }
}

/// Query di ricerca
public struct MailSearchQuery: Codable {
    public let text: String?
    public let from: String?
    public let to: String?
    public let subject: String?
    public let hasAttachments: Bool?
    public let dateFrom: Date?
    public let dateTo: Date?
    public let labels: [String]?
    public let maxResults: Int

    public init(
        text: String? = nil,
        from: String? = nil,
        to: String? = nil,
        subject: String? = nil,
        hasAttachments: Bool? = nil,
        dateFrom: Date? = nil,
        dateTo: Date? = nil,
        labels: [String]? = nil,
        maxResults: Int = 50
    ) {
        self.text = text
        self.from = from
        self.to = to
        self.subject = subject
        self.hasAttachments = hasAttachments
        self.dateFrom = dateFrom
        self.dateTo = dateTo
        self.labels = labels
        self.maxResults = maxResults
    }
}

/// Paginazione per richieste
public struct MailPagination {
    public let pageSize: Int
    public let pageToken: String?

    public init(pageSize: Int = 50, pageToken: String? = nil) {
        self.pageSize = pageSize
        self.pageToken = pageToken
    }
}

/// Batch di messaggi con paginazione
public struct MailMessageBatch {
    public let messages: [MailMessage]
    public let nextPageToken: String?
    public let hasMore: Bool

    public init(messages: [MailMessage], nextPageToken: String? = nil, hasMore: Bool = false) {
        self.messages = messages
        self.nextPageToken = nextPageToken
        self.hasMore = hasMore
    }
}

/// Alias per compatibilità
public typealias MailContact = MailParticipant




