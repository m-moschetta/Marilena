import Foundation
import CoreData
import Combine

// MARK: - Service Protocols for Email System Refactoring

/// Protocolli dei servizi per garantire compatibilità durante il refactoring
/// Ogni protocollo definisce l'interfaccia che i servizi esistenti devono mantenere

// MARK: - Email Service Protocol

/// Protocollo per il servizio principale di gestione email
@MainActor
public protocol EmailServiceProtocol: AnyObject, ObservableObject {
    
    // MARK: - Properties
    
    /// Lista delle email correnti
    var emails: [EmailMessage] { get }
    
    /// Account email corrente
    var currentAccount: EmailAccount? { get }
    
    /// Stato di caricamento
    var isLoading: Bool { get }
    
    /// Stato di sincronizzazione
    var isSyncing: Bool { get }
    
    /// Errore corrente
    var errorMessage: String? { get }
    
    // MARK: - Core Email Methods
    
    /// Carica email dall'account corrente
    func loadEmails() async
    
    /// Sincronizza email con il server
    func syncEmails() async
    
    /// Invia una email
    func sendEmail(to: String, subject: String, body: String, cc: [String]?, bcc: [String]?) async throws
    
    /// Inoltra una email
    func forwardEmail(_ email: EmailMessage, to: String, body: String) async throws
    
    /// Risponde a una email
    func replyToEmail(_ email: EmailMessage, body: String, replyAll: Bool) async throws
    
    // MARK: - Account Management
    
    /// Configura account email
    func setupAccount(_ account: EmailAccount) async throws
    
    /// Rimuove account
    func removeAccount(_ account: EmailAccount) async throws
    
    /// Lista degli account configurati
    func getConfiguredAccounts() -> [EmailAccount]
    
    // MARK: - Search & Filter
    
    /// Cerca email per testo
    func searchEmails(query: String) async -> [EmailMessage]
    
    /// Filtra email per categoria
    func filterEmails(by category: EmailCategory) -> [EmailMessage]
    
    /// Filtra email per mittente
    func filterEmails(from sender: String) -> [EmailMessage]
}

// MARK: - AI Service Protocol

/// Note: AIServiceProtocol è già definito in Core/AI/AIServiceProtocol.swift
/// Utilizziamo quello esistente per evitare duplicazioni

// MARK: - Email AI Service Protocol

/// Protocollo specifico per AI applicata alle email
@MainActor
public protocol EmailAIServiceProtocol: AnyObject {
    
    // MARK: - Email Analysis
    
    /// Analizza email e determina categoria
    func categorizeEmail(_ email: EmailMessage) async -> EmailCategory
    
    /// Analizza urgenza email
    func analyzeUrgency(_ email: EmailMessage) async -> EmailUrgency
    
    /// Analizza tono email
    func analyzeTone(_ email: EmailMessage) async -> EmailTone
    
    /// Riassume contenuto email
    func summarizeEmail(_ email: EmailMessage) async -> String
    
    // MARK: - Response Generation
    
    /// Genera risposta automatica
    func generateResponse(for email: EmailMessage, tone: EmailTone?) async -> String
    
    /// Genera risposta con contesto personalizzato
    func generateResponse(for email: EmailMessage, context: String, tone: EmailTone?) async -> String
    
    /// Migliora testo di risposta
    func improveResponseText(_ text: String, tone: EmailTone) async -> String
}

// MARK: - Cache Service Protocol

/// Protocollo per servizi di cache
@MainActor
public protocol CacheServiceProtocol: AnyObject {
    
    // MARK: - Basic Cache Operations
    
    /// Salva oggetto in cache
    func set<T: Codable>(_ object: T, forKey key: String) async
    
    /// Recupera oggetto dalla cache
    func get<T: Codable>(_ type: T.Type, forKey key: String) async -> T?
    
    /// Rimuove oggetto dalla cache
    func remove(forKey key: String) async
    
    /// Pulisce tutta la cache
    func clear() async
    
    // MARK: - Cache Management
    
    /// Verifica se esiste una chiave
    func exists(forKey key: String) async -> Bool
    
    /// Ottiene dimensione cache
    func getCacheSize() async -> Int
    
    /// Ottiene scadenza per chiave
    func getExpiration(forKey key: String) async -> Date?
    
    /// Imposta scadenza per chiave
    func setExpiration(forKey key: String, expiration: Date) async
}

// MARK: - Repository Protocols

/// Protocollo base per tutti i repository
public protocol RepositoryProtocol {
    associatedtype Entity
    associatedtype Identifier
    
    /// Trova entità per ID
    func findById(_ id: Identifier) async -> Entity?
    
    /// Trova tutte le entità
    func findAll() async -> [Entity]
    
    /// Salva entità
    func save(_ entity: Entity) async throws
    
    /// Elimina entità
    func delete(_ entity: Entity) async throws
    
    /// Elimina per ID
    func deleteById(_ id: Identifier) async throws
}

/// Protocollo per repository delle email
@MainActor
public protocol EmailRepositoryProtocol: RepositoryProtocol where Entity == EmailMessage, Identifier == String {
    
    /// Trova email per mittente
    func findBySender(_ sender: String) async -> [EmailMessage]
    
    /// Trova email per categoria
    func findByCategory(_ category: EmailCategory) async -> [EmailMessage]
    
    /// Trova email in intervallo di date
    func findByDateRange(from: Date, to: Date) async -> [EmailMessage]
    
    /// Cerca email per testo
    func search(query: String) async -> [EmailMessage]
    
    /// Conta email per categoria
    func countByCategory(_ category: EmailCategory) async -> Int
}

/// Protocollo per repository delle chat
@MainActor
public protocol ChatRepositoryProtocol: RepositoryProtocol where Entity == ChatMarilena, Identifier == UUID {
    
    /// Trova chat per tipo
    func findByType(_ type: String) async -> [ChatMarilena]
    
    /// Trova chat email per mittente
    func findEmailChatBySender(_ sender: String) async -> ChatMarilena?
    
    /// Trova chat recenti
    func findRecent(limit: Int) async -> [ChatMarilena]
    
    /// Conta messaggi per chat
    func countMessages(for chat: ChatMarilena) async -> Int
}

// MARK: - Configuration Service Protocol

/// Protocollo per gestione configurazione
@MainActor
public protocol ConfigurationServiceProtocol: AnyObject {
    
    // MARK: - Environment Configuration
    
    /// Ottiene configurazione per ambiente corrente
    func getCurrentEnvironment() -> String
    
    /// Cambia ambiente
    func setEnvironment(_ environment: String)
    
    // MARK: - API Configuration
    
    /// Ottiene endpoint API
    func getAPIEndpoint(for service: String) -> String?
    
    /// Ottiene chiave API
    func getAPIKey(for service: String) -> String?
    
    /// Imposta endpoint API
    func setAPIEndpoint(_ endpoint: String, for service: String)
    
    /// Imposta chiave API (salvata in Keychain)
    func setAPIKey(_ key: String, for service: String)
    
    // MARK: - Email Configuration
    
    /// Configurazione email corrente
    func getEmailConfiguration() -> EmailConfiguration
    
    /// Aggiorna configurazione email
    func updateEmailConfiguration(_ config: EmailConfiguration)
    
    // MARK: - AI Configuration
    
    /// Configurazione AI corrente
    func getAIConfiguration() -> AIConfiguration
    
    /// Aggiorna configurazione AI
    func updateAIConfiguration(_ config: AIConfiguration)
}

// MARK: - Token Manager Protocol

/// Protocollo per gestione token e credenziali
@MainActor
public protocol TokenManagerProtocol: AnyObject {
    
    // MARK: - Token Operations
    
    /// Salva token in modo sicuro
    func saveToken(_ token: String, for service: String) async throws
    
    /// Recupera token
    func getToken(for service: String) async -> String?
    
    /// Rimuove token
    func removeToken(for service: String) async throws
    
    /// Verifica se token esiste
    func hasToken(for service: String) async -> Bool
    
    // MARK: - Token Validation
    
    /// Verifica validità token
    func isTokenValid(for service: String) async -> Bool
    
    /// Refresh token se necessario
    func refreshTokenIfNeeded(for service: String) async throws -> String?
    
    /// Ottieni scadenza token
    func getTokenExpiration(for service: String) async -> Date?
    
    // MARK: - OAuth Management
    
    /// Gestisce flusso OAuth
    func handleOAuthFlow(for service: String, authCode: String) async throws -> String
    
    /// Revoca token OAuth
    func revokeOAuthToken(for service: String) async throws
}

// MARK: - Configuration Models

// Configuration models moved to Core/Configuration/ConfigurationTypes.swift
// for better organization and to avoid duplication

// MARK: - Supporting Enums

/// Note: EmailUrgency è già definito in EmailAIService.swift
/// Utilizziamo quello esistente per evitare duplicazioni

/// Tono email
public enum EmailTone: String, Codable, CaseIterable {
    case formal = "formal"
    case casual = "casual"
    case friendly = "friendly"
    case professional = "professional"
    case concise = "concise"
    case detailed = "detailed"
    
    public var displayName: String {
        switch self {
        case .formal: return "Formale"
        case .casual: return "Informale"
        case .friendly: return "Amichevole"
        case .professional: return "Professionale"
        case .concise: return "Conciso"
        case .detailed: return "Dettagliato"
        }
    }
}

// MARK: - Service Registration Extensions

public extension ServiceContainer {
    
    /// Registra tutti i protocolli di servizio nel container
    func registerAllServiceProtocols() {
        print("📦 ServiceContainer: Registering all service protocols...")
        
        // I servizi specifici verranno registrati durante la migrazione graduale
        // Questo metodo servirà per la configurazione finale
        
        print("✅ ServiceContainer: Service protocols registration completed")
    }
    
    /// Helper per registrare servizio con protocollo
    func registerProtocol<P>(_ protocolType: P.Type, implementation: P) {
        let key = String(describing: protocolType)
        register(protocolType, service: implementation)
        print("📦 ServiceContainer: Registered \(type(of: implementation)) for protocol \(key)")
    }
}