import Foundation
import SwiftUI

// MARK: - Email Account

public struct EmailAccount: Codable, Identifiable, Hashable {
    public let id: String // UUID unico per account
    public let provider: EmailProvider
    public let email: String
    public let displayName: String? // Nome utente da Google/Microsoft
    public let photoURL: String? // URL foto profilo
    public let addedAt: Date // Data aggiunta account

    // Tokens NON in Codable (solo Keychain)
    public var accessToken: String {
        KeychainManager.shared.getAPIKey(for: "email_access_token_\(id)") ?? ""
    }

    public var refreshToken: String? {
        KeychainManager.shared.getAPIKey(for: "email_refresh_token_\(id)")
    }

    public var expiresAt: Date? {
        // Salvato in UserDefaults separatamente se necessario
        let key = "email_token_expires_at_\(id)"
        let timestamp = UserDefaults.standard.double(forKey: key)
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }

    public var isTokenExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }

    // Coding keys escludono i computed properties
    enum CodingKeys: String, CodingKey {
        case id, provider, email, displayName, photoURL, addedAt
    }

    public init(
        id: String = UUID().uuidString,
        provider: EmailProvider,
        email: String,
        displayName: String? = nil,
        photoURL: String? = nil,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.provider = provider
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.addedAt = addedAt
    }

    // Codable conformance manuale
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        provider = try container.decode(EmailProvider.self, forKey: .provider)
        email = try container.decode(String.self, forKey: .email)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        photoURL = try container.decodeIfPresent(String.self, forKey: .photoURL)
        addedAt = try container.decode(Date.self, forKey: .addedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(provider, forKey: .provider)
        try container.encode(email, forKey: .email)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encodeIfPresent(photoURL, forKey: .photoURL)
        try container.encode(addedAt, forKey: .addedAt)
    }

    // Hashable conformance
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: EmailAccount, rhs: EmailAccount) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Email Provider

public enum EmailProvider: String, CaseIterable, Codable {
    case google = "google"
    case microsoft = "microsoft"

    public var displayName: String {
        switch self {
        case .google:
            return "Gmail"
        case .microsoft:
            return "Outlook"
        }
    }

    public var iconName: String {
        switch self {
        case .google:
            return "envelope.circle.fill"
        case .microsoft:
            return "envelope.badge.fill"
        }
    }
}

// MARK: - Email Message

public struct EmailMessage: Identifiable, Codable {
    public let id: String
    public let accountId: String // ID account associato (multi-account support)
    public let from: String
    public let to: [String]
    public let subject: String
    public let body: String
    public let date: Date
    public let isRead: Bool
    public let hasAttachments: Bool
    public let emailType: EmailType
    public var category: EmailCategory?
    public let threadingInfo: ThreadingInfo? // Proprietà per threading

    public init(
        id: String,
        accountId: String,
        from: String,
        to: [String],
        subject: String,
        body: String,
        date: Date,
        isRead: Bool = false,
        hasAttachments: Bool = false,
        emailType: EmailType = .received,
        category: EmailCategory? = nil,
        threadingInfo: ThreadingInfo? = nil
    ) {
        self.id = id
        self.accountId = accountId
        self.from = from
        self.to = to
        self.subject = subject
        self.body = body
        self.date = date
        self.isRead = isRead
        self.hasAttachments = hasAttachments
        self.emailType = emailType
        self.category = category
        self.threadingInfo = threadingInfo
    }
}

// MARK: - Email Type

public enum EmailType: String, Codable, CaseIterable {
    case received = "received"
    case sent = "sent"

    var displayName: String {
        switch self {
        case .received: return "Ricevuta"
        case .sent: return "Inviata"
        }
    }

    var icon: String {
        switch self {
        case .received: return "envelope"
        case .sent: return "envelope.fill"
        }
    }

    var color: Color {
        switch self {
        case .received: return .blue
        case .sent: return .green
        }
    }
}

// MARK: - Email Error

public enum EmailError: LocalizedError {
    case oauthNotImplemented
    case invalidCredentials
    case networkError(String)
    case imapConnectionFailed
    case tokenExpired
    case notAuthenticated
    case sendFailed
    case permissionDenied
    case invalidEmailAddress
    case serverError
    case deleteFailed
    case emailNotFound

    public var errorDescription: String? {
        switch self {
        case .oauthNotImplemented:
            return "Autenticazione OAuth non ancora implementata"
        case .invalidCredentials:
            return "Credenziali non valide"
        case .networkError(let message):
            return "Errore di rete: \(message)"
        case .imapConnectionFailed:
            return "Impossibile connettersi al server IMAP"
        case .tokenExpired:
            return "Token di accesso scaduto. Effettua nuovamente l'accesso."
        case .notAuthenticated:
            return "Non sei autenticato. Effettua l'accesso prima di inviare email."
        case .sendFailed:
            return "Invio email non riuscito. Verifica la connessione e riprova."
        case .permissionDenied:
            return "Permessi insufficienti per inviare email. Verifica le impostazioni dell'account."
        case .invalidEmailAddress:
            return "Indirizzo email non valido. Verifica il destinatario."
        case .serverError:
            return "Errore nella comunicazione con il server per marcare l'email come letta."
        case .deleteFailed:
            return "Eliminazione email non riuscita."
        case .emailNotFound:
            return "Email non trovata."
        }
    }
}

// MARK: - Email Threading Models

/// Rappresenta una conversazione di email (thread)
public struct EmailConversation: Identifiable, Codable {
    public let id: String
    public let subject: String // Subject normalizzato (senza "Re:", "Fwd:", etc.)
    public var messages: [EmailMessage]
    public let participants: Set<String> // Tutti i partecipanti alla conversazione
    public let createdAt: Date // Data del primo messaggio
    public var lastActivity: Date // Data dell'ultimo messaggio
    public var messageCount: Int { messages.count }
    public var hasUnread: Bool { messages.contains { !$0.isRead } }
    public var isStarred: Bool = false

    /// Messaggio più recente nella conversazione
    public var latestMessage: EmailMessage? {
        messages.sorted { $0.date > $1.date }.first
    }

    /// Partecipanti come stringa formattata
    public var participantsDisplay: String {
        Array(participants).prefix(3).joined(separator: ", ") +
        (participants.count > 3 ? " e \(participants.count - 3) altri" : "")
    }

    public init(
        id: String,
        subject: String,
        messages: [EmailMessage],
        participants: Set<String>,
        createdAt: Date,
        lastActivity: Date,
        isStarred: Bool = false
    ) {
        self.id = id
        self.subject = subject
        self.messages = messages.sorted { $0.date < $1.date } // Ordina cronologicamente
        self.participants = participants
        self.createdAt = createdAt
        self.lastActivity = lastActivity
        self.isStarred = isStarred
    }

    /// Aggiunge un messaggio alla conversazione
    public mutating func addMessage(_ message: EmailMessage) {
        guard !messages.contains(where: { $0.id == message.id }) else { return }
        messages.append(message)
        messages.sort { $0.date < $1.date }
        lastActivity = max(lastActivity, message.date)
    }

    /// Rimuove un messaggio dalla conversazione
    public mutating func removeMessage(withId messageId: String) {
        messages.removeAll { $0.id == messageId }
        if let latestDate = messages.max(by: { $0.date < $1.date })?.date {
            lastActivity = latestDate
        }
    }
}

/// Informazioni per il threading delle email
public struct ThreadingInfo: Codable {
    public let threadId: String?
    public let references: [String] // Message-IDs referenced
    public let inReplyTo: String? // Message-ID this is replying to
    public let messageId: String? // Unique Message-ID

    public init(
        threadId: String? = nil,
        references: [String] = [],
        inReplyTo: String? = nil,
        messageId: String? = nil
    ) {
        self.threadId = threadId
        self.references = references
        self.inReplyTo = inReplyTo
        self.messageId = messageId
    }
}
