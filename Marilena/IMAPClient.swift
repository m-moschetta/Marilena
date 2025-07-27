import Foundation
import Network

// MARK: - IMAP Client
// Client IMAP per la gestione delle connessioni email e sincronizzazione

public class IMAPClient {
    
    // MARK: - Properties
    private let host: String
    private let port: Int
    private let accessToken: String
    private var connection: NWConnection?
    
    // MARK: - Initialization
    
    public init(host: String, port: Int, accessToken: String) {
        self.host = host
        self.port = port
        self.accessToken = accessToken
    }
    
    // MARK: - Public Methods
    
    /// Connette al server IMAP
    public func connect() async throws {
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: UInt16(port)))
        
        connection = NWConnection(to: endpoint, using: .tls)
        
        return try await withCheckedThrowingContinuation { continuation in
            connection?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    continuation.resume()
                case .failed(let error):
                    continuation.resume(throwing: IMAPError.connectionFailed(error))
                case .cancelled:
                    continuation.resume(throwing: IMAPError.connectionCancelled)
                default:
                    break
                }
            }
            
            connection?.start(queue: .global())
        }
    }
    
    /// Autentica con il server IMAP usando OAuth
    public func authenticate() async throws {
        let authCommand = "A001 AUTHENTICATE XOAUTH2 \(accessToken)\r\n"
        try await sendCommand(authCommand)
        
        // Leggi la risposta
        let response = try await readResponse()
        
        if !response.contains("OK") {
            throw IMAPError.authenticationFailed
        }
    }
    
    /// Seleziona una cartella email
    public func selectFolder(_ folder: String) async throws {
        let selectCommand = "A002 SELECT \(folder)\r\n"
        try await sendCommand(selectCommand)
        
        let response = try await readResponse()
        
        if !response.contains("OK") {
            throw IMAPError.folderSelectionFailed
        }
    }
    
    /// Recupera i messaggi dalla cartella selezionata
    public func fetchMessages(folder: String, limit: Int = 50) async throws -> [EmailMessage] {
        try await connect()
        try await authenticate()
        try await selectFolder(folder)
        
        // Recupera gli UID dei messaggi
        let uidCommand = "A003 UID SEARCH ALL\r\n"
        try await sendCommand(uidCommand)
        
        let searchResponse = try await readResponse()
        let uids = parseUIDs(from: searchResponse)
        
        // Limita il numero di messaggi
        let limitedUIDs = Array(uids.prefix(limit))
        
        var messages: [EmailMessage] = []
        
        for uid in limitedUIDs {
            if let message = try await fetchMessage(uid: uid) {
                messages.append(message)
            }
        }
        
        try await disconnect()
        
        return messages.sorted { $0.date > $1.date }
    }
    
    /// Recupera un singolo messaggio per UID
    public func fetchMessage(uid: String) async throws -> EmailMessage? {
        let fetchCommand = "A004 UID FETCH \(uid) (BODY[HEADER.FIELDS (FROM TO SUBJECT DATE)] BODY[TEXT])\r\n"
        try await sendCommand(fetchCommand)
        
        let response = try await readResponse()
        
        return parseMessage(from: response, uid: uid)
    }
    
    /// Disconnetti dal server
    public func disconnect() async throws {
        let logoutCommand = "A005 LOGOUT\r\n"
        try await sendCommand(logoutCommand)
        
        connection?.cancel()
        connection = nil
    }
    
    // MARK: - Private Methods
    
    private func sendCommand(_ command: String) async throws {
        guard let connection = connection else {
            throw IMAPError.notConnected
        }
        
        guard let data = command.data(using: .utf8) else {
            throw IMAPError.invalidCommand
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: IMAPError.sendFailed(error))
                } else {
                    continuation.resume()
                }
            })
        }
    }
    
    private func readResponse() async throws -> String {
        guard let connection = connection else {
            throw IMAPError.notConnected
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                if let error = error {
                    continuation.resume(throwing: IMAPError.receiveFailed(error))
                } else if let data = data, let response = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: response)
                } else {
                    continuation.resume(throwing: IMAPError.invalidResponse)
                }
            }
        }
    }
    
    private func parseUIDs(from response: String) -> [String] {
        let lines = response.components(separatedBy: .newlines)
        var uids: [String] = []
        
        for line in lines {
            if line.contains("SEARCH") {
                let components = line.components(separatedBy: " ")
                for component in components {
                    if let uid = Int(component) {
                        uids.append(String(uid))
                    }
                }
                break
            }
        }
        
        return uids
    }
    
    private func parseMessage(from response: String, uid: String) -> EmailMessage? {
        let lines = response.components(separatedBy: .newlines)
        
        var from = ""
        var to: [String] = []
        var subject = ""
        var date = Date()
        var body = ""
        
        var inBody = false
        
        for line in lines {
            if line.hasPrefix("From: ") {
                from = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("To: ") {
                let toLine = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                to = toLine.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            } else if line.hasPrefix("Subject: ") {
                subject = String(line.dropFirst(9)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("Date: ") {
                let dateString = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                date = parseDate(dateString) ?? Date()
            } else if line.isEmpty && !inBody {
                inBody = true
            } else if inBody {
                body += line + "\n"
            }
        }
        
        return EmailMessage(
            id: uid,
            from: from,
            to: to,
            subject: subject,
            body: body.trimmingCharacters(in: .whitespacesAndNewlines),
            date: date,
            isRead: false,
            hasAttachments: false
        )
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        // Prova diversi formati di data
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm Z",
            "dd MMM yyyy HH:mm Z"
        ]
        
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
}

// MARK: - IMAP Errors

public enum IMAPError: LocalizedError {
    case notConnected
    case connectionFailed(Error)
    case connectionCancelled
    case authenticationFailed
    case folderSelectionFailed
    case invalidCommand
    case sendFailed(Error)
    case receiveFailed(Error)
    case invalidResponse
    
    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Non connesso al server IMAP"
        case .connectionFailed(let error):
            return "Errore di connessione: \(error.localizedDescription)"
        case .connectionCancelled:
            return "Connessione annullata"
        case .authenticationFailed:
            return "Autenticazione fallita"
        case .folderSelectionFailed:
            return "Impossibile selezionare la cartella"
        case .invalidCommand:
            return "Comando IMAP non valido"
        case .sendFailed(let error):
            return "Errore invio comando: \(error.localizedDescription)"
        case .receiveFailed(let error):
            return "Errore ricezione risposta: \(error.localizedDescription)"
        case .invalidResponse:
            return "Risposta IMAP non valida"
        }
    }
} 