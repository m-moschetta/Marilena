import Foundation

/// Modello principale per un messaggio email
public struct MailMessage: Identifiable, Codable, Hashable {
    public let id: String
    public let threadId: String?
    public let subject: String
    public let bodyPlain: String?
    public let bodyHTML: String?
    public let snippet: String
    public let from: MailParticipant
    public let to: [MailParticipant]
    public let cc: [MailParticipant]
    public let bcc: [MailParticipant]
    public let date: Date
    public let labels: [String]
    public let flags: MailMessageFlags
    public let attachments: [MailAttachmentInfo]
    public let providerId: String
    public let providerThreadKey: String?
    public let size: Int

    public init(
        id: String,
        threadId: String? = nil,
        subject: String,
        bodyPlain: String? = nil,
        bodyHTML: String? = nil,
        snippet: String,
        from: MailParticipant,
        to: [MailParticipant] = [],
        cc: [MailParticipant] = [],
        bcc: [MailParticipant] = [],
        date: Date,
        labels: [String] = [],
        flags: MailMessageFlags = MailMessageFlags(),
        attachments: [MailAttachmentInfo] = [],
        providerId: String,
        providerThreadKey: String? = nil,
        size: Int = 0
    ) {
        self.id = id
        self.threadId = threadId
        self.subject = subject
        self.bodyPlain = bodyPlain
        self.bodyHTML = bodyHTML
        self.snippet = snippet
        self.from = from
        self.to = to
        self.cc = cc
        self.bcc = bcc
        self.date = date
        self.labels = labels
        self.flags = flags
        self.attachments = attachments
        self.providerId = providerId
        self.providerThreadKey = providerThreadKey
        self.size = size
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(providerId)
    }

    public static func == (lhs: MailMessage, rhs: MailMessage) -> Bool {
        lhs.id == rhs.id && lhs.providerId == rhs.providerId
    }
}

/// Partecipante a un messaggio email
public struct MailParticipant: Codable, Hashable {
    public let email: String
    public let name: String?

    public var displayName: String {
        name ?? email
    }

    public init(email: String, name: String? = nil) {
        self.email = email
        self.name = name
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(email)
    }

    public static func == (lhs: MailParticipant, rhs: MailParticipant) -> Bool {
        lhs.email == rhs.email
    }
}

/// Flag di un messaggio email
public struct MailMessageFlags: Codable, Hashable {
    public let isRead: Bool
    public let isStarred: Bool
    public let isDeleted: Bool
    public let isDraft: Bool
    public let isAnswered: Bool
    public let isForwarded: Bool

    public init(
        isRead: Bool = false,
        isStarred: Bool = false,
        isDeleted: Bool = false,
        isDraft: Bool = false,
        isAnswered: Bool = false,
        isForwarded: Bool = false
    ) {
        self.isRead = isRead
        self.isStarred = isStarred
        self.isDeleted = isDeleted
        self.isDraft = isDraft
        self.isAnswered = isAnswered
        self.isForwarded = isForwarded
    }
}

/// Informazioni su un allegato
public struct MailAttachmentInfo: Codable, Identifiable {
    public let id: String
    public let filename: String
    public let mimeType: String
    public let size: Int

    public init(id: String, filename: String, mimeType: String, size: Int) {
        self.id = id
        self.filename = filename
        self.mimeType = mimeType
        self.size = size
    }
}
