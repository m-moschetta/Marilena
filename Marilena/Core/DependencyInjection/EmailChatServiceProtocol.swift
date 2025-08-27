import Foundation
import CoreData
import Combine

// MARK: - Email Chat Service Protocol

/// Protocollo per il servizio chat-email - garantisce compatibilità con sistema esistente
/// Questo protocollo definisce l'interfaccia che EmailChatService deve mantenere
/// per preservare la funzionalità durante il refactoring
@MainActor
public protocol EmailChatServiceProtocol: AnyObject, ObservableObject {
    
    // MARK: - Published Properties (da mantenere)
    
    /// Lista delle chat email
    var emailChats: [ChatMarilena] { get }
    
    /// Stato di caricamento
    var isLoading: Bool { get }
    
    /// Errore corrente
    var error: String? { get }
    
    /// Chat email corrente
    var currentEmailChat: ChatMarilena? { get }
    
    // MARK: - Core Methods (da preservare)
    
    /// Crea una nuova chat per un'email - METODO CRITICO
    func createEmailChat(for email: EmailMessage) async -> ChatMarilena?
    
    /// Aggiorna una chat esistente con nuova email
    func updateExistingEmailChat(_ chat: ChatMarilena, with email: EmailMessage) async
    
    /// Trova chat esistente per mittente
    func findExistingEmailChat(for sender: String) async -> ChatMarilena?
    
    /// Invia risposta email dal canvas - METODO CRITICO PER CANVAS
    func sendEmailResponse(from chat: ChatMarilena, response: String, originalEmailId: String?) async throws
    
    /// Carica tutte le chat email
    func loadEmailChats()
    
    /// Genera analisi AI e crea i 2 messaggi (context + draft) - CORE FEATURE
    func analyzeEmailAndGenerateResponse(for email: EmailMessage, in chat: ChatMarilena) async
    
    // MARK: - Thread Management (preservare gestione thread)
    
    /// Genera ID thread per email
    func generateThreadId(for email: EmailMessage) -> String
    
    /// Verifica se email appartiene a thread esistente
    func belongsToExistingThread(_ email: EmailMessage, chat: ChatMarilena) -> Bool
    
    // MARK: - Utility Methods (mantenere helper)
    
    /// Configura osservatori
    func setupObservers()
    
    /// Determina se email dovrebbe creare chat
    func shouldCreateChatForEmail(_ email: EmailMessage) -> Bool
}

// MARK: - Default Implementation (per compatibilità)

public extension EmailChatServiceProtocol {
    
    /// Implementazione di default per shouldCreateChatForEmail
    func shouldCreateChatForEmail(_ email: EmailMessage) -> Bool {
        // Criteri di default per creare chat:
        // 1. Email ricevute (non inviate)
        // 2. Non sono notifiche automatiche
        // 3. Non sono spam/promo
        
        guard email.emailType == .received else { return false }
        
        // Escludi email automatiche/notifiche
        let automaticSenders = ["noreply", "no-reply", "notification", "automated"]
        let isAutomatic = automaticSenders.contains { email.from.lowercased().contains($0) }
        
        if isAutomatic { return false }
        
        // Escludi categorie spam/promo se categorizzate
        if let category = email.category {
            return category != .promotional && category != .notifications
        }
        
        return true
    }
    
    /// Implementazione di default per generateThreadId
    func generateThreadId(for email: EmailMessage) -> String {
        // Genera thread ID basato su subject (pulito) + sender
        let cleanSubject = email.subject
            .replacingOccurrences(of: "Re: ", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Fwd: ", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let threadBase = "\(email.from)-\(cleanSubject)"
        return threadBase.data(using: .utf8)?.base64EncodedString() ?? UUID().uuidString
    }
}

// MARK: - Enhanced Protocol (per futuro)

/// Protocollo esteso per funzionalità avanzate (da implementare nel refactoring)
@MainActor
public protocol EnhancedEmailChatServiceProtocol: EmailChatServiceProtocol {
    
    // MARK: - Advanced Features (per Phase 2+)
    
    /// Analisi thread avanzata
    func analyzeEmailThread(_ chat: ChatMarilena) async -> EmailThreadAnalysis?
    
    /// Generazione risposte contestuali
    func generateContextualResponse(for email: EmailMessage, context: String) async -> String?
    
    /// Gestione priorità email
    func calculateEmailPriority(_ email: EmailMessage) -> Int
    
    /// Auto-categorization integration
    func categorizeAndCreateChat(for email: EmailMessage) async -> ChatMarilena?
}

// MARK: - Service Registration Helper

public extension ServiceContainer {
    
    /// Registra EmailChatService nel container
    func registerEmailChatService(_ service: any EmailChatServiceProtocol) {
        self.register((any EmailChatServiceProtocol).self, singleton: service)
        print("📧 ServiceContainer: EmailChatService registered as protocol")
    }
    
    /// Risolve EmailChatService dal container
    func resolveEmailChatService() -> any EmailChatServiceProtocol {
        return self.resolve((any EmailChatServiceProtocol).self)
    }
}

// MARK: - Migration Helper

/// Helper per la migrazione graduale del servizio esistente
public struct EmailChatServiceMigration {
    
    /// Verifica che il servizio esistente implementi il protocollo correttamente
    @MainActor
    public static func validateService(_ service: any EmailChatServiceProtocol) -> Bool {
        // Verifica che tutti i metodi critici siano implementati
        // Questo sarà utile durante la migrazione
        
        print("🔍 EmailChatServiceMigration: Validating service implementation...")
        
        // Test basic properties exist (accessing them validates protocol compliance)
        _ = service.emailChats
        _ = service.isLoading
        _ = service.error
        _ = service.currentEmailChat
        
        print("✅ EmailChatServiceMigration: Service validation completed")
        return true
    }
    
    /// Migra servizio esistente al nuovo container
    @MainActor
    public static func migrateToContainer(_ service: any EmailChatServiceProtocol) {
        ServiceContainer.shared.registerEmailChatService(service)
        print("🔄 EmailChatServiceMigration: Service migrated to container")
    }
}