//
//  MailProvider.swift
//  Marilena
//
//  Created by Marilena on 2024
//
//  Protocollo comune per tutti i provider di posta elettronica
//  Supporta Gmail API, Microsoft Graph API, e IMAP standard
//

import Foundation
import Combine

/// Protocollo comune per tutti i provider email
public protocol MailProvider {
    /// Tipo del provider (Gmail, Microsoft, IMAP)
    var providerType: MailProviderType { get }

    /// Account attualmente connesso
    var connectedAccount: MailAccount? { get }

    /// Stato di connessione del provider
    var connectionState: MailProviderState { get }

    /// Publisher per gli aggiornamenti di stato
    var statePublisher: AnyPublisher<MailProviderState, Never> { get }

    /// Connette il provider con le credenziali fornite
    /// - Parameter account: Account da utilizzare per la connessione
    /// - Returns: Publisher che emette il risultato della connessione
    func connect(with account: MailAccount) -> AnyPublisher<MailConnectionResult, MailProviderError>

    /// Disconnette il provider
    func disconnect() -> AnyPublisher<Void, MailProviderError>

    /// Sincronizza le email dal server
    /// - Parameter options: Opzioni di sincronizzazione
    /// - Returns: Publisher che emette gli aggiornamenti di sincronizzazione
    func syncEmails(options: MailSyncOptions) -> AnyPublisher<MailSyncUpdate, MailProviderError>

    /// Invia un'email
    /// - Parameter message: Messaggio da inviare
    /// - Returns: Publisher che emette il risultato dell'invio
    func sendEmail(_ message: MailMessage) -> AnyPublisher<MailSendResult, MailProviderError>

    /// Marca email come lette/non lette
    /// - Parameters:
    ///   - messageIds: ID dei messaggi
    ///   - read: Stato di lettura desiderato
    func markAsRead(_ messageIds: [String], read: Bool) -> AnyPublisher<Void, MailProviderError>

    /// Elimina messaggi
    /// - Parameter messageIds: ID dei messaggi da eliminare
    func deleteMessages(_ messageIds: [String]) -> AnyPublisher<Void, MailProviderError>

    /// Archivia messaggi
    /// - Parameter messageIds: ID dei messaggi da archiviare
    func archiveMessages(_ messageIds: [String]) -> AnyPublisher<Void, MailProviderError>

    /// Ottiene i dettagli completi di un messaggio
    /// - Parameter messageId: ID del messaggio
    func fetchMessageDetails(_ messageId: String) -> AnyPublisher<MailMessage, MailProviderError>

    /// Ricerca messaggi
    /// - Parameter query: Query di ricerca
    func searchMessages(_ query: MailSearchQuery) -> AnyPublisher<[MailMessage], MailProviderError>
}

/// Tipi di provider supportati
public enum MailProviderType: String, Codable {
    case gmail = "gmail"
    case microsoft = "microsoft"
    case imap = "imap"
}

/// Stati possibili del provider
public enum MailProviderState: Equatable {
    case disconnected
    case connecting
    case connected(account: MailAccount)
    case error(MailProviderError)

    public static func == (lhs: MailProviderState, rhs: MailProviderState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected):
            return true
        case (.connecting, .connecting):
            return true
        case (.connected(let lhsAccount), .connected(let rhsAccount)):
            return lhsAccount.id == rhsAccount.id
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

/// Risultato della connessione
public enum MailConnectionResult {
    case success(account: MailAccount)
    case requiresReauthentication
    case failed(error: MailProviderError)
}

/// Risultato dell'invio email
public enum MailSendResult {
    case success(messageId: String)
    case failed(error: MailProviderError)
}

/// Aggiornamenti di sincronizzazione
public enum MailSyncUpdate {
    case started
    case progress(current: Int, total: Int)
    case newMessages([MailMessage])
    case updatedMessages([MailMessage])
    case deletedMessages([String])
    case completed
    case error(MailProviderError)
}

/// Errori del provider
public enum MailProviderError: LocalizedError {
    case networkError(String)
    case authenticationError(String)
    case permissionDenied(String)
    case rateLimitExceeded(retryAfter: TimeInterval?)
    case serverError(String)
    case invalidRequest(String)
    case notConnected
    case tokenExpired

    public var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Errore di rete: \(message)"
        case .authenticationError(let message):
            return "Errore di autenticazione: \(message)"
        case .permissionDenied(let message):
            return "Permessi negati: \(message)"
        case .rateLimitExceeded(let retryAfter):
            if let retryAfter = retryAfter {
                return "Limite di richieste superato. Riprova tra \(Int(retryAfter)) secondi."
            }
            return "Limite di richieste superato."
        case .serverError(let message):
            return "Errore del server: \(message)"
        case .invalidRequest(let message):
            return "Richiesta non valida: \(message)"
        case .notConnected:
            return "Provider non connesso."
        case .tokenExpired:
            return "Token di accesso scaduto."
        }
    }
}
