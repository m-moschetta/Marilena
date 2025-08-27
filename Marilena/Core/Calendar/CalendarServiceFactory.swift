import Foundation

// MARK: - Calendar Service Factory
// Factory per creare istanze dei servizi calendario in base al tipo

public class CalendarServiceFactory {
    
    // MARK: - Singleton
    public static let shared = CalendarServiceFactory()
    
    private init() {}
    
    // MARK: - Factory Methods
    
    /// Crea un servizio calendario del tipo specificato
    /// - Parameter type: Tipo di servizio calendario da creare
    /// - Returns: Istanza del servizio calendario
    public func createService(for type: CalendarServiceType) -> CalendarServiceProtocol {
        switch type {
        case .eventKit:
            return EventKitCalendarService()
        case .googleCalendar:
            return GoogleCalendarService()
        case .microsoftGraph:
            return MicrosoftGraphCalendarService()
        }
    }
    
    /// Crea tutti i servizi disponibili
    /// - Returns: Array di tutti i servizi calendario supportati
    public func createAllServices() -> [CalendarServiceProtocol] {
        return CalendarServiceType.allCases.map { createService(for: $0) }
    }
    
    /// Ottiene il servizio preferito dall'utente (salvato nelle UserDefaults)
    /// - Returns: Servizio calendario preferito o EventKit come fallback
    public func getPreferredService() -> CalendarServiceProtocol {
        let savedType = UserDefaults.standard.string(forKey: "preferred_calendar_service")
        
        if let savedType = savedType,
           let type = CalendarServiceType(rawValue: savedType) {
            return createService(for: type)
        }
        
        // Fallback: se l'utente ha già fatto login con Google, usa Google Calendar
        // altrimenti usa EventKit
        if isGoogleAuthenticated() {
            return createService(for: .googleCalendar)
        } else {
            return createService(for: .eventKit)
        }
    }
    
    /// Salva la preferenza dell'utente per il servizio calendario
    /// - Parameter type: Tipo di servizio da salvare come preferito
    public func setPreferredService(_ type: CalendarServiceType) {
        UserDefaults.standard.set(type.rawValue, forKey: "preferred_calendar_service")
    }
    
    // MARK: - Helper Methods
    
    /// Verifica se l'utente è già autenticato con Google
    /// - Returns: true se l'utente ha una sessione Google valida
    private func isGoogleAuthenticated() -> Bool {
        // Questa logica dovrebbe essere sincronizzata con la tua implementazione OAuth esistente
        // Per ora uso una verifica semplice
        return UserDefaults.standard.object(forKey: "google_access_token") != nil
    }
}

// MARK: - Calendar Service Factory Extension per SwiftUI

@available(iOS 13.0, *)
extension CalendarServiceFactory {
    
    /// Crea un servizio calendario configurato per SwiftUI
    /// - Parameter type: Tipo di servizio calendario
    /// - Returns: Servizio configurato e pronto all'uso
    @MainActor
    public func createServiceForSwiftUI(for type: CalendarServiceType) -> CalendarServiceProtocol {
        let service = createService(for: type)
        
        // Eventuale configurazione aggiuntiva per SwiftUI
        return service
    }
}