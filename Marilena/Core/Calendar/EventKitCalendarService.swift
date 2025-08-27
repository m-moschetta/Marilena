import Foundation
import EventKit
#if canImport(EventKitUI)
import EventKitUI
#endif

// MARK: - EventKit Calendar Service
// Implementazione del servizio calendario usando EventKit nativo di Apple

public class EventKitCalendarService: CalendarServiceProtocol {
    
    // MARK: - Properties
    
    private let eventStore = EKEventStore()
    
    public var isAuthenticated: Bool {
        return EKEventStore.authorizationStatus(for: .event) == .fullAccess ||
               EKEventStore.authorizationStatus(for: .event) == .writeOnly
    }
    
    public var providerName: String {
        return "Apple EventKit"
    }
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Authentication
    
    public func authenticate() async throws {
        if #available(iOS 17.0, *) {
            // iOS 17+: Richiede accesso completo per leggere e scrivere
            let granted = try await eventStore.requestFullAccessToEvents()
            if !granted {
                throw CalendarServiceError.permissionDenied
            }
        } else {
            // iOS precedenti: Metodo legacy
            let granted = try await eventStore.requestAccess(to: .event)
            if !granted {
                throw CalendarServiceError.permissionDenied
            }
        }
    }
    
    // MARK: - Event Operations
    
    public func fetchEvents(from startDate: Date, to endDate: Date) async throws -> [CalendarEvent] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let predicate = self.eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
                    let ekEvents = self.eventStore.events(matching: predicate)
                    
                    let calendarEvents = ekEvents.map { ekEvent in
                        self.convertEKEventToCalendarEvent(ekEvent)
                    }
                    
                    continuation.resume(returning: calendarEvents)
                } catch {
                    continuation.resume(throwing: CalendarServiceError.networkError(error))
                }
            }
        }
    }
    
    public func createEvent(_ event: CalendarEvent) async throws -> String {
        let ekEvent = EKEvent(eventStore: eventStore)
        ekEvent.title = event.title
        ekEvent.notes = event.description
        ekEvent.startDate = event.startDate
        ekEvent.endDate = event.endDate
        ekEvent.location = event.location
        ekEvent.isAllDay = event.isAllDay
        
        // Assegna al calendario predefinito se non specificato
        if let calendarId = event.calendarId,
           let calendar = eventStore.calendar(withIdentifier: calendarId) {
            ekEvent.calendar = calendar
        } else {
            ekEvent.calendar = eventStore.defaultCalendarForNewEvents
        }
        
        // Nota: EventKit non supporta l'aggiunta programmatica di partecipanti
        // I partecipanti devono essere aggiunti tramite l'interfaccia nativa di EventKit
        
        do {
            try eventStore.save(ekEvent, span: .thisEvent)
            return ekEvent.eventIdentifier ?? UUID().uuidString
        } catch {
            throw CalendarServiceError.invalidEventData
        }
    }
    
    public func updateEvent(_ event: CalendarEvent) async throws {
        guard let eventId = event.id,
              let ekEvent = eventStore.event(withIdentifier: eventId) else {
            throw CalendarServiceError.eventNotFound
        }
        
        ekEvent.title = event.title
        ekEvent.notes = event.description
        ekEvent.startDate = event.startDate
        ekEvent.endDate = event.endDate
        ekEvent.location = event.location
        ekEvent.isAllDay = event.isAllDay
        
        do {
            try eventStore.save(ekEvent, span: .thisEvent)
        } catch {
            throw CalendarServiceError.invalidEventData
        }
    }
    
    public func deleteEvent(eventId: String) async throws {
        guard let ekEvent = eventStore.event(withIdentifier: eventId) else {
            throw CalendarServiceError.eventNotFound
        }
        
        do {
            try eventStore.remove(ekEvent, span: .thisEvent)
        } catch {
            throw CalendarServiceError.invalidEventData
        }
    }
    
    // MARK: - Calendar Management
    
    public func fetchCalendars() async throws -> [CalendarInfo] {
        let calendars = eventStore.calendars(for: .event)
        
        return calendars.map { calendar in
            CalendarInfo(
                id: calendar.calendarIdentifier,
                name: calendar.title,
                description: nil, // EKCalendar non ha proprietà notes
                color: calendar.cgColor?.hexString,
                isReadOnly: !calendar.allowsContentModifications,
                isPrimary: calendar == eventStore.defaultCalendarForNewEvents,
                providerType: .eventKit
            )
        }
    }
    
    // MARK: - Smart Assistant Features
    
    public func createEventFromNaturalLanguage(_ naturalLanguageInput: String) async throws -> String {
        // Per ora, implementazione semplice senza SwiftyChrono
        // TODO: Integrare SwiftyChrono per parsing del linguaggio naturale
        
        let event = CalendarEvent(
            title: naturalLanguageInput,
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600), // 1 ora
            providerType: .eventKit
        )
        
        return try await createEvent(event)
    }
    
    // MARK: - Helper Methods
    
    private func convertEKEventToCalendarEvent(_ ekEvent: EKEvent) -> CalendarEvent {
        let attendees: [CalendarAttendee] = ekEvent.attendees?.compactMap { participant in
            // Per EventKit, l'email è nell'URL con scheme mailto:
            let email = participant.url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
            guard !email.isEmpty else { return nil }
            
            return CalendarAttendee(
                email: email,
                name: participant.name,
                status: convertParticipantStatus(participant.participantStatus)
            )
        } ?? []
        
        return CalendarEvent(
            id: ekEvent.eventIdentifier,
            title: ekEvent.title ?? "Senza titolo",
            description: ekEvent.notes,
            startDate: ekEvent.startDate,
            endDate: ekEvent.endDate,
            location: ekEvent.location,
            isAllDay: ekEvent.isAllDay,
            recurrenceRule: ekEvent.recurrenceRules?.first?.description,
            attendees: attendees,
            calendarId: ekEvent.calendar?.calendarIdentifier,
            url: ekEvent.url?.absoluteString,
            providerId: ekEvent.eventIdentifier,
            providerType: .eventKit,
            lastModified: ekEvent.lastModifiedDate
        )
    }
    
    private func convertParticipantStatus(_ status: EKParticipantStatus) -> AttendeeStatus {
        switch status {
        case .accepted:
            return .accepted
        case .declined:
            return .declined
        case .tentative:
            return .tentative
        default:
            return .needsAction
        }
    }
}

// MARK: - CGColor Extension for Hex String

extension CGColor {
    var hexString: String? {
        guard let components = components, components.count >= 3 else { return nil }
        
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}