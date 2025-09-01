import Foundation

/// Protocollo base per tutti i provider email
/// Implementa l'astrazione per Gmail, Microsoft Graph, IMAP standard
public protocol MailProvider {
    /// Identificatore univoco del provider
    var providerId: String { get }

    /// Nome visualizzato del provider
    var displayName: String { get }

    /// Icona del provider
    var iconName: String { get }

    /// Autentica il provider con le credenziali fornite
    /// - Parameter credentials: Credenziali di autenticazione
    /// - Returns: Token di accesso valido
    func authenticate(with credentials: MailCredentials) async throws -> MailToken

    /// Verifica se il token è ancora valido
    /// - Parameter token: Token da verificare
    /// - Returns: true se valido, false altrimenti
    func validateToken(_ token: MailToken) async throws -> Bool

    /// Rinnova il token di accesso
    /// - Parameter refreshToken: Token di refresh
    /// - Returns: Nuovo token di accesso
    func refreshToken(_ refreshToken: String) async throws -> MailToken

    /// Recupera i messaggi dalla casella specificata
    /// - Parameters:
    ///   - folder: Cartella da cui recuperare i messaggi
    ///   - limit: Numero massimo di messaggi da recuperare
    ///   - token: Token di accesso
    /// - Returns: Array di messaggi
    func fetchMessages(from folder: String, limit: Int, using token: MailToken) async throws -> [MailMessage]

    /// Recupera un messaggio specifico per ID
    /// - Parameters:
    ///   - messageId: ID del messaggio
    ///   - token: Token di accesso
    /// - Returns: Messaggio completo
    func fetchMessage(id messageId: String, using token: MailToken) async throws -> MailMessage

    /// Invia un messaggio
    /// - Parameters:
    ///   - message: Messaggio da inviare
    ///   - token: Token di accesso
    /// - Returns: ID del messaggio inviato
    func sendMessage(_ message: MailDraft, using token: MailToken) async throws -> String

    /// Marca un messaggio come letto/non letto
    /// - Parameters:
    ///   - messageId: ID del messaggio
    ///   - isRead: Stato di lettura
    ///   - token: Token di accesso
    func markMessageAsRead(_ messageId: String, isRead: Bool, using token: MailToken) async throws

    /// Elimina un messaggio
    /// - Parameters:
    ///   - messageId: ID del messaggio
    ///   - token: Token di accesso
    func deleteMessage(_ messageId: String, using token: MailToken) async throws

    /// Archivia un messaggio
    /// - Parameters:
    ///   - messageId: ID del messaggio
    ///   - token: Token di accesso
    func archiveMessage(_ messageId: String, using token: MailToken) async throws

    /// Sposta un messaggio in una cartella
    /// - Parameters:
    ///   - messageId: ID del messaggio
    ///   - toFolder: Cartella di destinazione
    ///   - token: Token di accesso
    func moveMessage(_ messageId: String, toFolder: String, using token: MailToken) async throws

    /// Recupera la lista delle cartelle/label disponibili
    /// - Parameter token: Token di accesso
    /// - Returns: Array di cartelle
    func fetchFolders(using token: MailToken) async throws -> [MailFolder]

    /// Sincronizza i cambiamenti dalla data specificata
    /// - Parameters:
    ///   - since: Data dall'ultima sincronizzazione
    ///   - token: Token di accesso
    /// - Returns: Cambiamenti da applicare
    func syncChanges(since: Date, using token: MailToken) async throws -> MailSyncResult
}

/// Risultato della sincronizzazione
public struct MailSyncResult {
    /// Nuovi messaggi da aggiungere
    public let newMessages: [MailMessage]

    /// Messaggi modificati
    public let updatedMessages: [MailMessage]

    /// ID messaggi eliminati
    public let deletedMessageIds: [String]

    /// Nuove cartelle/label
    public let newFolders: [MailFolder]

    /// Timestamp dell'ultima sincronizzazione
    public let lastSyncTimestamp: Date

    public init(
        newMessages: [MailMessage] = [],
        updatedMessages: [MailMessage] = [],
        deletedMessageIds: [String] = [],
        newFolders: [MailFolder] = [],
        lastSyncTimestamp: Date = Date()
    ) {
        self.newMessages = newMessages
        self.updatedMessages = updatedMessages
        self.deletedMessageIds = deletedMessageIds
        self.newFolders = newFolders
        self.lastSyncTimestamp = lastSyncTimestamp
    }
}

/// Credenziali per l'autenticazione
public struct MailCredentials {
    public let username: String
    public let password: String?
    public let accessToken: String?
    public let refreshToken: String?
    public let clientId: String
    public let clientSecret: String

    public init(
        username: String,
        password: String? = nil,
        accessToken: String? = nil,
        refreshToken: String? = nil,
        clientId: String,
        clientSecret: String
    ) {
        self.username = username
        self.password = password
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.clientId = clientId
        self.clientSecret = clientSecret
    }
}

/// Token di accesso
public struct MailToken {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresAt: Date?
    public let tokenType: String

    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() >= expiresAt
    }

    public init(
        accessToken: String,
        refreshToken: String? = nil,
        expiresAt: Date? = nil,
        tokenType: String = "Bearer"
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.tokenType = tokenType
    }
}

/// Cartella email
public struct MailFolder {
    public let id: String
    public let name: String
    public let type: MailFolderType
    public let path: String
    public let messageCount: Int
    public let unreadCount: Int

    public init(
        id: String,
        name: String,
        type: MailFolderType,
        path: String,
        messageCount: Int = 0,
        unreadCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.path = path
        self.messageCount = messageCount
        self.unreadCount = unreadCount
    }
}

/// Tipo di cartella
public enum MailFolderType {
    case inbox
    case sent
    case drafts
    case trash
    case archive
    case spam
    case custom(String)
}

/// Bozza di messaggio email
public struct MailDraft {
    public let to: [String]
    public let cc: [String]
    public let bcc: [String]
    public let subject: String
    public let body: String
    public let isHtml: Bool
    public let attachments: [MailAttachment]

    public init(
        to: [String],
        cc: [String] = [],
        bcc: [String] = [],
        subject: String,
        body: String,
        isHtml: Bool = false,
        attachments: [MailAttachment] = []
    ) {
        self.to = to
        self.cc = cc
        self.bcc = bcc
        self.subject = subject
        self.body = body
        self.isHtml = isHtml
        self.attachments = attachments
    }
}

/// Allegato email
public struct MailAttachment {
    public let filename: String
    public let mimeType: String
    public let data: Data
    public let size: Int

    public init(filename: String, mimeType: String, data: Data) {
        self.filename = filename
        self.mimeType = mimeType
        self.data = data
        self.size = data.count
    }
}
