import Foundation
import Combine
import SwiftUI
import CoreData

// MARK: - Calendar Manager
// Classe principale per gestire tutte le operazioni del calendario nell'app

@MainActor
public class CalendarManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var events: [CalendarEvent] = []
    @Published public var calendars: [CalendarInfo] = []
    @Published public var isLoading = false
    @Published public var error: String?
    @Published public var currentService: CalendarServiceProtocol?
    @Published public var availableServices: [CalendarServiceProtocol] = []
    @Published public var completedEventKeys: Set<String> = []
    private let migrationFlagKey = "CalendarCompletedEventsMigratedV1"
    
    // MARK: - Private Properties
    
    private let serviceFactory: CalendarServiceFactory
    private var cancellables = Set<AnyCancellable>()
    private let completedDefaultsKey = "CalendarCompletedEvents"
    private let completionStore = CalendarCompletionStore(context: PersistenceController.shared.container.viewContext)
    
    // MARK: - Configuration
    
    /// Numero di giorni da caricare nel futuro per gli eventi
    public var daysToLoad: Int = 30
    
    /// Indica se il manager deve sincronizzare automaticamente
    public var autoSync: Bool = true
    
    // MARK: - Initialization
    
    public init(serviceFactory: CalendarServiceFactory? = nil) {
        self.serviceFactory = serviceFactory ?? CalendarServiceFactory.shared
        setupInitialService()
        setupAutoSync()
        loadCompletedState()
    }
    
    // MARK: - Service Management
    
    /// Imposta il servizio calendario da utilizzare
    /// - Parameter serviceType: Tipo di servizio da attivare
    public func setService(_ serviceType: CalendarServiceType) async {
        isLoading = true
        error = nil
        
        do {
            let service = serviceFactory.createService(for: serviceType)
            
            // Tenta l'autenticazione se necessario
            if !service.isAuthenticated {
                try await service.authenticate()
            }
            
            currentService = service
            serviceFactory.setPreferredService(serviceType)
            
            // Carica i dati del nuovo servizio
            await loadInitialData()
            
        } catch {
            self.error = "Errore configurazione servizio: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Inizializza il servizio preferito dell'utente
    private func setupInitialService() {
        Task {
            let preferredService = serviceFactory.getPreferredService()
            currentService = preferredService
            availableServices = serviceFactory.createAllServices()
            
            // Carica i dati solo se il servizio è già autenticato
            if preferredService.isAuthenticated {
                await loadInitialData()
            }
        }
    }
    
    // MARK: - Data Loading
    
    /// Carica gli eventi e i calendari
    public func loadInitialData() async {
        await loadEvents()
        await loadCalendars()
        await migrateCompletedStateIfNeeded()
    }
    
    /// Carica gli eventi in un intervallo di date
    /// - Parameters:
    ///   - startDate: Data di inizio (default: oggi)
    ///   - endDate: Data di fine (default: oggi + daysToLoad)
    public func loadEvents(from startDate: Date = Date(), to endDate: Date? = nil) async {
        guard let service = currentService else {
            error = "Nessun servizio calendario configurato"
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            let end = endDate ?? Calendar.current.date(byAdding: .day, value: daysToLoad, to: startDate) ?? startDate
            let fetchedEvents = try await service.fetchEvents(from: startDate, to: end)
            
            await MainActor.run {
                self.events = fetchedEvents.sorted { $0.startDate < $1.startDate }
            }
            
        } catch {
            await MainActor.run {
                self.error = "Errore caricamento eventi: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
    
    /// Carica i calendari disponibili
    public func loadCalendars() async {
        guard let service = currentService else { return }
        
        do {
            let fetchedCalendars = try await service.fetchCalendars()
            
            await MainActor.run {
                self.calendars = fetchedCalendars
            }
            
        } catch {
            await MainActor.run {
                self.error = "Errore caricamento calendari: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Event Operations
    
    /// Crea un nuovo evento
    /// - Parameter eventRequest: Richiesta per la creazione dell'evento
    /// - Returns: ID dell'evento creato
    @discardableResult
    public func createEvent(_ eventRequest: CalendarEventRequest) async throws -> String {
        guard let service = currentService else {
            throw CalendarServiceError.notAuthenticated
        }
        
        let event = CalendarEvent(
            title: eventRequest.title,
            description: eventRequest.description,
            startDate: eventRequest.startDate,
            endDate: eventRequest.endDate,
            location: eventRequest.location,
            isAllDay: eventRequest.isAllDay,
            attendees: eventRequest.attendeeEmails.map { 
                CalendarAttendee(email: $0, status: .needsAction) 
            },
            calendarId: eventRequest.calendarId,
            providerType: service.serviceType
        )
        
        let eventId = try await service.createEvent(event)
        
        // Ricarica gli eventi per aggiornare la UI
        await loadEvents()
        
        return eventId
    }
    
    /// Crea un evento dal linguaggio naturale (funzionalità AI)
    /// - Parameter input: Testo in linguaggio naturale
    /// - Returns: ID dell'evento creato
    @discardableResult
    public func createEventFromText(_ input: String) async throws -> String {
        guard let service = currentService else {
            throw CalendarServiceError.notAuthenticated
        }
        
        let eventId = try await service.createEventFromNaturalLanguage(input)
        
        // Ricarica gli eventi per aggiornare la UI
        await loadEvents()
        
        return eventId
    }
    
    /// Elimina un evento
    /// - Parameter eventId: ID dell'evento da eliminare
    public func deleteEvent(_ eventId: String) async throws {
        guard let service = currentService else {
            throw CalendarServiceError.notAuthenticated
        }
        
        try await service.deleteEvent(eventId: eventId)
        
        // Ricarica gli eventi per aggiornare la UI
        await loadEvents()
    }

    /// Aggiorna un evento esistente
    @discardableResult
    public func updateEvent(_ event: CalendarEvent) async throws {
        guard let service = currentService else {
            throw CalendarServiceError.notAuthenticated
        }
        try await service.updateEvent(event)

        // Refresh solo il giorno impattato per efficienza
        let dayStart = Calendar.current.startOfDay(for: event.startDate)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? event.endDate
        await loadEvents(from: dayStart, to: dayEnd)
    }
    
    // MARK: - Auto Sync
    
    /// Configura la sincronizzazione automatica
    private func setupAutoSync() {
        guard autoSync else { return }
        
        // Sincronizza ogni 5 minuti se l'app è attiva
        Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.loadEvents()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Utility Methods
    
    /// Ottiene gli eventi di oggi
    public var todayEvents: [CalendarEvent] {
        let today = Date()
        return events.filter { Calendar.current.isDate($0.startDate, inSameDayAs: today) }
    }
    
    /// Ottiene gli eventi futuri
    public var upcomingEvents: [CalendarEvent] {
        let now = Date()
        return events.filter { $0.startDate > now }
    }
    
    /// Ottiene gli eventi in corso
    public var currentEvents: [CalendarEvent] {
        events.filter { $0.isHappening }
    }

    /// Eventi non completati (promemoria da fare)
    public var incompleteEvents: [CalendarEvent] {
        events.filter { !isCompleted($0) }
    }

    /// Eventi completati (promemoria completati)
    public var completedEvents: [CalendarEvent] {
        events.filter { isCompleted($0) }
    }

    // MARK: - Completion State Management

    /// Genera una chiave stabile per identificare un evento ai fini dello stato completato
    public func eventKey(for event: CalendarEvent) -> String {
        if let providerId = event.providerId, !providerId.isEmpty {
            return "\(event.providerType.rawValue)|pid|\(providerId)"
        }
        if let id = event.id, !id.isEmpty {
            return "\(event.providerType.rawValue)|id|\(id)"
        }
        let timestamp = Int(event.startDate.timeIntervalSince1970)
        return "\(event.providerType.rawValue)|fallback|\(event.title)|\(timestamp)"
    }

    /// Restituisce true se l'evento è marcato come completato
    public func isCompleted(_ event: CalendarEvent) -> Bool {
        // Prefer remote metadata when present; fallback to local persisted state
        if let state = CalendarCompletionMetadata.parse(from: event.description) {
            return state.isCompleted
        }
        return completedEventKeys.contains(eventKey(for: event))
    }

    /// Trova un evento a partire dalla sua chiave
    public func eventForKey(_ key: String) -> CalendarEvent? {
        events.first { eventKey(for: $0) == key }
    }

    /// Marca o smarca un evento come completato e persiste lo stato
    public func markCompleted(_ event: CalendarEvent, completed: Bool) {
        let key = eventKey(for: event)
        if completed {
            completedEventKeys.insert(key)
            completionStore.upsert(key: key)
        } else {
            completedEventKeys.remove(key)
            completionStore.remove(key: key)
        }
        persistCompletedState()
        objectWillChange.send()
    }

    /// Inverte lo stato di completamento di un evento
    public func toggleCompleted(_ event: CalendarEvent) {
        let target = !isCompleted(event)
        // Optimistic local update for snappy UI
        markCompleted(event, completed: target)
        Task { [weak self] in
            await self?.setCompletedOnProvider(event, completed: target)
        }
    }

    private func loadCompletedState() {
        var keys = Set<String>()
        if let saved = UserDefaults.standard.array(forKey: completedDefaultsKey) as? [String] {
            keys.formUnion(saved)
        }
        // Merge with Core Data store if available
        let coreDataKeys = completionStore.loadAllKeys()
        keys.formUnion(coreDataKeys)
        completedEventKeys = keys
    }

    private func persistCompletedState() {
        UserDefaults.standard.set(Array(completedEventKeys), forKey: completedDefaultsKey)
    }

    // MARK: - Remote Sync of Completion State

    /// Writes the completion state into the event's notes/description via the active provider
    private func setCompletedOnProvider(_ event: CalendarEvent, completed: Bool) async {
        guard let service = currentService else { return }
        do {
            // Rebuild the event with updated description notes
            let newNotes = CalendarCompletionMetadata.write(to: event.description, completed: completed)
            let updated = CalendarEvent(
                id: event.id,
                title: event.title,
                description: newNotes,
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location,
                isAllDay: event.isAllDay,
                recurrenceRule: event.recurrenceRule,
                attendees: event.attendees,
                calendarId: event.calendarId,
                url: event.url,
                providerId: event.providerId,
                providerType: event.providerType,
                lastModified: Date()
            )
            try await service.updateEvent(updated)

            // Success: rely on remote metadata; clear local key for this event
            let key = eventKey(for: event)
            if completedEventKeys.contains(key) {
                completedEventKeys.remove(key)
                persistCompletedState()
            }
            // Refresh a narrow window (same day) to reflect updated notes
            let dayStart = Calendar.current.startOfDay(for: event.startDate)
            let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? event.endDate
            await loadEvents(from: dayStart, to: dayEnd)
        } catch {
            await MainActor.run {
                self.error = "Errore aggiornamento stato evento: \(error.localizedDescription)"
            }
            // Keep local fallback already set by optimistic update
        }
    }

    // MARK: - Migration from local keys to remote metadata
    private func migrateCompletedStateIfNeeded() async {
        let already = UserDefaults.standard.bool(forKey: migrationFlagKey)
        guard !already else { return }
        guard let service = currentService else { return }

        // Work on currently loaded events only (configurable window)
        let candidates = events

        for ev in candidates {
            let key = eventKey(for: ev)
            let hasLocal = completedEventKeys.contains(key)
            let remote = CalendarCompletionMetadata.parse(from: ev.description)?.isCompleted ?? false

            if hasLocal && !remote {
                // Attempt to push remote metadata; failure will leave local state as fallback
                do {
                    let newNotes = CalendarCompletionMetadata.write(to: ev.description, completed: true)
                    let updated = CalendarEvent(
                        id: ev.id,
                        title: ev.title,
                        description: newNotes,
                        startDate: ev.startDate,
                        endDate: ev.endDate,
                        location: ev.location,
                        isAllDay: ev.isAllDay,
                        recurrenceRule: ev.recurrenceRule,
                        attendees: ev.attendees,
                        calendarId: ev.calendarId,
                        url: ev.url,
                        providerId: ev.providerId,
                        providerType: ev.providerType,
                        lastModified: Date()
                    )
                    try await service.updateEvent(updated)
                    // On success, remove local marker
                    completedEventKeys.remove(key)
                } catch {
                    // Ignore; keep local fallback
                }
            } else if remote && hasLocal {
                // Remote already authoritative; clean local
                completedEventKeys.remove(key)
            }
        }

        persistCompletedState()
        UserDefaults.standard.set(true, forKey: migrationFlagKey)
    }
}

// MARK: - CalendarManager Extension per SwiftUI Environment

extension CalendarManager {
    /// Chiave per l'environment di SwiftUI
    public static let environmentKey = "CalendarManager"
}

// MARK: - CalendarServiceProtocol Extension Helper

extension CalendarServiceProtocol {
    var serviceType: CalendarServiceType {
        switch self.providerName {
        case "Google Calendar":
            return .googleCalendar
        case "Apple EventKit":
            return .eventKit
        case "Microsoft Outlook":
            return .microsoftGraph
        default:
            return .eventKit
        }
    }
}
