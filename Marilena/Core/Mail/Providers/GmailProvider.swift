import Foundation

/// Provider per Gmail API
public class GmailProvider: MailProvider {
    public let providerId = "gmail"
    public let displayName = "Gmail"
    public let iconName = "envelope.circle.fill"

    private let baseURL = "https://gmail.googleapis.com/gmail/v1/users/me"
    private let session: URLSession

    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    // MARK: - MailProvider Implementation

    public func authenticate(with credentials: MailCredentials) async throws -> MailToken {
        // Per Gmail, l'autenticazione avviene tramite OAuth esterno
        // Questo metodo assume che il token sia già stato ottenuto
        guard let accessToken = credentials.accessToken else {
            throw GmailProviderError.invalidCredentials
        }

        let token = MailToken(
            accessToken: accessToken,
            refreshToken: credentials.refreshToken,
            expiresAt: nil, // Gmail tokens hanno durata variabile
            tokenType: "Bearer"
        )

        // Verifica che il token sia valido
        try await validateToken(token)

        return token
    }

    public func validateToken(_ token: MailToken) async throws -> Bool {
        let url = URL(string: "\(baseURL)/profile")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }

        return httpResponse.statusCode == 200
    }

    public func refreshToken(_ refreshToken: String) async throws -> MailToken {
        // L'implementazione del refresh token richiede configurazione OAuth
        // Per ora, assumiamo che il token sia ancora valido
        throw GmailProviderError.notImplemented
    }

    public func fetchMessages(from folder: String, limit: Int, using token: MailToken) async throws -> [MailMessage] {
        // Prima ottieni la lista dei messaggi
        let messageIds = try await fetchMessageIds(from: folder, limit: limit, using: token)

        // Poi recupera i dettagli per ogni messaggio
        var messages: [MailMessage] = []

        for messageId in messageIds {
            if let message = try await fetchMessage(id: messageId, using: token) {
                messages.append(message)
            }
        }

        return messages
    }

    public func fetchMessage(id messageId: String, using token: MailToken) async throws -> MailMessage {
        let url = URL(string: "\(baseURL)/messages/\(messageId)?format=full")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GmailProviderError.apiError("Failed to fetch message")
        }

        let gmailMessage = try JSONDecoder().decode(GmailMessage.self, from: data)
        return try convertGmailMessageToMailMessage(gmailMessage)
    }

    public func sendMessage(_ draft: MailDraft, using token: MailToken) async throws -> String {
        let url = URL(string: "\(baseURL)/messages/send")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Crea il messaggio RFC 2822
        let rawMessage = createRFC2822Message(from: draft)
        let encodedMessage = rawMessage.data(using: .utf8)?.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        let emailData: [String: Any] = [
            "raw": encodedMessage ?? ""
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: emailData)
        request.httpBody = jsonData

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GmailProviderError.apiError("Failed to send message")
        }

        let responseData = try JSONDecoder().decode(GmailSendResponse.self, from: data)
        return responseData.id
    }

    public func markMessageAsRead(_ messageId: String, isRead: Bool, using token: MailToken) async throws {
        let url = URL(string: "\(baseURL)/messages/\(messageId)/modify")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let modifyData: [String: Any] = [
            isRead ? "removeLabelIds" : "addLabelIds": ["UNREAD"]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: modifyData)
        request.httpBody = jsonData

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GmailProviderError.apiError("Failed to modify message")
        }
    }

    public func deleteMessage(_ messageId: String, using token: MailToken) async throws {
        let url = URL(string: "\(baseURL)/messages/\(messageId)/trash")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GmailProviderError.apiError("Failed to delete message")
        }
    }

    public func archiveMessage(_ messageId: String, using token: MailToken) async throws {
        let url = URL(string: "\(baseURL)/messages/\(messageId)/modify")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let modifyData: [String: Any] = [
            "removeLabelIds": ["INBOX"]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: modifyData)
        request.httpBody = jsonData

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GmailProviderError.apiError("Failed to archive message")
        }
    }

    public func moveMessage(_ messageId: String, toFolder folderId: String, using token: MailToken) async throws {
        let url = URL(string: "\(baseURL)/messages/\(messageId)/modify")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let modifyData: [String: Any] = [
            "addLabelIds": [folderId]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: modifyData)
        request.httpBody = jsonData

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GmailProviderError.apiError("Failed to move message")
        }
    }

    public func fetchFolders(using token: MailToken) async throws -> [MailFolder] {
        let url = URL(string: "\(baseURL)/labels")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GmailProviderError.apiError("Failed to fetch labels")
        }

        let labelsResponse = try JSONDecoder().decode(GmailLabelsResponse.self, from: data)
        return labelsResponse.labels.map { convertGmailLabelToMailFolder($0) }
    }

    public func syncChanges(since: Date, using token: MailToken) async throws -> MailSyncResult {
        // Per Gmail, possiamo usare la History API per sync incrementale
        // Implementazione semplificata
        return MailSyncResult()
    }

    // MARK: - Private Methods

    private func fetchMessageIds(from folder: String, limit: Int, using token: MailToken) async throws -> [String] {
        let labelId = convertFolderNameToLabelId(folder)
        let url = URL(string: "\(baseURL)/messages?labelIds=\(labelId)&maxResults=\(limit)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GmailProviderError.apiError("Failed to fetch message list")
        }

        let messagesList = try JSONDecoder().decode(GmailMessagesList.self, from: data)
        return messagesList.messages.map { $0.id }
    }

    private func convertFolderNameToLabelId(_ folderName: String) -> String {
        switch folderName.uppercased() {
        case "INBOX": return "INBOX"
        case "SENT": return "SENT"
        case "DRAFTS": return "DRAFT"
        case "TRASH": return "TRASH"
        case "SPAM": return "SPAM"
        default: return folderName.uppercased()
        }
    }

    private func convertGmailMessageToMailMessage(_ gmailMessage: GmailMessage) throws -> MailMessage {
        // Estrai informazioni dall'header
        let headers = gmailMessage.payload?.headers ?? []
        let from = extractHeaderValue("From", from: headers) ?? "Unknown"
        let subject = extractHeaderValue("Subject", from: headers) ?? "No Subject"
        let dateString = extractHeaderValue("Date", from: headers)

        // Converti partecipanti
        let fromParticipant = try parseEmailAddress(from)
        let toAddresses = extractHeaderValue("To", from: headers) ?? ""
        let toParticipants = try parseEmailAddresses(toAddresses)

        // Converti data
        let date = parseGmailDate(dateString)

        // Estrai body
        let bodyPlain = extractBody(from: gmailMessage.payload, mimeType: "text/plain")
        let bodyHTML = extractBody(from: gmailMessage.payload, mimeType: "text/html")
        let snippet = gmailMessage.snippet ?? ""

        // Converti labels
        let labels = gmailMessage.labelIds ?? []

        // Converti flags
        let isRead = !labels.contains("UNREAD")
        let isStarred = labels.contains("STARRED")
        let isDeleted = labels.contains("TRASH")
        let isDraft = labels.contains("DRAFT")
        let isAnswered = labels.contains("ANSWERED")
        let isForwarded = labels.contains("FORWARDED")

        let flags = MailMessageFlags(
            isRead: isRead,
            isStarred: isStarred,
            isDeleted: isDeleted,
            isDraft: isDraft,
            isAnswered: isAnswered,
            isForwarded: isForwarded
        )

        return MailMessage(
            id: gmailMessage.id,
            threadId: gmailMessage.threadId,
            subject: subject,
            bodyPlain: bodyPlain,
            bodyHTML: bodyHTML,
            snippet: snippet,
            from: fromParticipant,
            to: toParticipants,
            cc: [], // Implementare se necessario
            bcc: [], // Implementare se necessario
            date: date,
            labels: labels,
            flags: flags,
            attachments: [], // Implementare estrazione allegati
            providerId: providerId,
            providerThreadKey: gmailMessage.threadId,
            size: gmailMessage.sizeEstimate
        )
    }

    private func convertGmailLabelToMailFolder(_ label: GmailLabel) -> MailFolder {
        let type = convertGmailLabelType(label.type)

        return MailFolder(
            id: label.id,
            name: label.name,
            type: type,
            path: label.id,
            messageCount: label.messagesTotal ?? 0,
            unreadCount: label.messagesUnread ?? 0
        )
    }

    private func convertGmailLabelType(_ type: String) -> MailFolderType {
        switch type {
        case "system":
            switch type {
            case "INBOX": return .inbox
            case "SENT": return .sent
            case "DRAFT": return .drafts
            case "TRASH": return .trash
            case "SPAM": return .spam
            default: return .custom(type)
            }
        default:
            return .custom(type)
        }
    }

    private func createRFC2822Message(from draft: MailDraft) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        dateFormatter.locale = Locale(identifier: "en_US")
        let date = dateFormatter.string(from: Date())

        let toAddresses = draft.to.joined(separator: ", ")
        let ccAddresses = draft.cc.isEmpty ? "" : "\nCc: \(draft.cc.joined(separator: ", "))"

        return """
        From: user@gmail.com
        To: \(toAddresses)\(ccAddresses)
        Subject: \(draft.subject)
        Date: \(date)
        MIME-Version: 1.0
        Content-Type: \(draft.isHtml ? "text/html" : "text/plain"); charset=UTF-8

        \(draft.body)
        """
    }

    // MARK: - Helper Methods

    private func extractHeaderValue(_ name: String, from headers: [GmailHeader]) -> String? {
        return headers.first { $0.name.lowercased() == name.lowercased() }?.value
    }

    private func parseEmailAddress(_ address: String) throws -> MailParticipant {
        // Parsing semplificato di indirizzo email
        let components = address.components(separatedBy: " <")
        if components.count == 2 {
            let name = components[0].trimmingCharacters(in: .whitespaces)
            let email = components[1].trimmingCharacters(in: ["<", ">"])
            return MailParticipant(email: email, name: name.isEmpty ? nil : name)
        } else {
            return MailParticipant(email: address.trimmingCharacters(in: .whitespaces))
        }
    }

    private func parseEmailAddresses(_ addresses: String) throws -> [MailParticipant] {
        let addressList = addresses.components(separatedBy: ",")
        return try addressList.map { try parseEmailAddress($0) }
    }

    private func parseGmailDate(_ dateString: String?) -> Date {
        guard let dateString = dateString else { return Date() }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"

        return formatter.date(from: dateString) ?? Date()
    }

    private func extractBody(from payload: GmailMessagePayload?, mimeType: String) -> String? {
        guard let payload = payload else { return nil }

        if payload.mimeType == mimeType {
            return decodeBase64(payload.body?.data)
        }

        // Cerca nelle parti
        if let parts = payload.parts {
            for part in parts {
                if part.mimeType == mimeType {
                    return decodeBase64(part.body?.data)
                }
            }
        }

        return nil
    }

    private func decodeBase64(_ data: String?) -> String? {
        guard let data = data else { return nil }
        let cleanData = data
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        guard let decodedData = Data(base64Encoded: cleanData) else { return nil }
        return String(data: decodedData, encoding: .utf8)
    }
}

// MARK: - Gmail API Response Types

private struct GmailMessagesList: Codable {
    let messages: [GmailMessageRef]
}

private struct GmailMessageRef: Codable {
    let id: String
    let threadId: String
}

private struct GmailMessage: Codable {
    let id: String
    let threadId: String
    let labelIds: [String]?
    let snippet: String?
    let sizeEstimate: Int
    let payload: GmailMessagePayload?
}

private struct GmailMessagePayload: Codable {
    let headers: [GmailHeader]?
    let body: GmailBody?
    let parts: [GmailPart]?
    let mimeType: String
}

private struct GmailHeader: Codable {
    let name: String
    let value: String
}

private struct GmailBody: Codable {
    let data: String?
}

private struct GmailPart: Codable {
    let mimeType: String
    let body: GmailBody?
}

private struct GmailLabelsResponse: Codable {
    let labels: [GmailLabel]
}

private struct GmailLabel: Codable {
    let id: String
    let name: String
    let type: String
    let messagesTotal: Int?
    let messagesUnread: Int?
}

private struct GmailSendResponse: Codable {
    let id: String
    let threadId: String
}

/// Errori specifici del provider Gmail
public enum GmailProviderError: LocalizedError {
    case invalidCredentials
    case apiError(String)
    case notImplemented

    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Credenziali Gmail non valide"
        case .apiError(let message):
            return "Errore Gmail API: \(message)"
        case .notImplemented:
            return "Funzionalità non ancora implementata"
        }
    }
}
