import Foundation

// MARK: - Calendar Service Protocol
// Protocollo unificato per tutti i servizi di calendario (EventKit, Google Calendar, etc.)

public protocol CalendarServiceProtocol {
    
    // MARK: - Authentication & Setup
    
    /// Verifica se il servizio è attualmente autenticato e pronto per l'uso
    var isAuthenticated: Bool { get }
    
    /// Nome del provider (es. "Google Calendar", "Apple EventKit", "Microsoft Outlook")
    var providerName: String { get }
    
    /// Richiede l'autenticazione necessaria per accedere al calendario
    func authenticate() async throws
    
    // MARK: - Event Operations
    
    /// Recupera gli eventi in un intervallo di date
    /// - Parameters:
    ///   - startDate: Data di inizio
    ///   - endDate: Data di fine
    /// - Returns: Array di eventi del calendario
    func fetchEvents(from startDate: Date, to endDate: Date) async throws -> [CalendarEvent]
    
    /// Crea un nuovo evento
    /// - Parameter event: L'evento da creare
    /// - Returns: ID dell'evento creato
    func createEvent(_ event: CalendarEvent) async throws -> String
    
    /// Aggiorna un evento esistente
    /// - Parameter event: L'evento con le modifiche (deve avere un ID valido)
    func updateEvent(_ event: CalendarEvent) async throws
    
    /// Elimina un evento
    /// - Parameter eventId: ID dell'evento da eliminare
    func deleteEvent(eventId: String) async throws
    
    // MARK: - Calendar Management
    
    /// Recupera la lista dei calendari disponibili
    func fetchCalendars() async throws -> [CalendarInfo]
    
    // MARK: - Smart Assistant Features
    
    /// Crea un evento dal linguaggio naturale (per la funzionalità assistente)
    /// - Parameter naturalLanguageInput: Testo in linguaggio naturale (es. "riunione domani alle 15")
    /// - Returns: ID dell'evento creato
    func createEventFromNaturalLanguage(_ naturalLanguageInput: String) async throws -> String
}

// MARK: - Calendar Service Errors

public enum CalendarServiceError: LocalizedError {
    case notAuthenticated
    case permissionDenied
    case networkError(Error)
    case invalidEventData
    case eventNotFound
    case rateLimited
    case parseError(String)
    
    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Servizio calendario non autenticato"
        case .permissionDenied:
            return "Permesso negato per accedere al calendario"
        case .networkError(let error):
            return "Errore di rete: \(error.localizedDescription)"
        case .invalidEventData:
            return "Dati evento non validi"
        case .eventNotFound:
            return "Evento non trovato"
        case .rateLimited:
            return "Troppi tentativi. Riprova più tardi"
        case .parseError(let message):
            return "Errore parsing linguaggio naturale: \(message)"
        }
    }
}

// MARK: - Calendar Service Type

public enum CalendarServiceType: String, Codable, CaseIterable {
    case eventKit = "eventKit"
    case googleCalendar = "googleCalendar"
    case microsoftGraph = "microsoftGraph"
    
    public var displayName: String {
        switch self {
        case .eventKit:
            return "Calendari del Dispositivo"
        case .googleCalendar:
            return "Google Calendar"
        case .microsoftGraph:
            return "Microsoft Outlook"
        }
    }
}