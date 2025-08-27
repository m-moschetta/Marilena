import Foundation

// MARK: - Calendar Event Model
// Modello unificato per rappresentare eventi di calendario da qualsiasi provider

public struct CalendarEvent: Identifiable, Codable, Equatable {
    
    public let id: String?
    public let title: String
    public let description: String?
    public let startDate: Date
    public let endDate: Date
    public let location: String?
    public let isAllDay: Bool
    public let recurrenceRule: String?
    public let attendees: [CalendarAttendee]
    public let calendarId: String?
    public let url: String?
    
    // Metadati del provider
    public let providerId: String? // ID specifico del provider
    public let providerType: CalendarServiceType
    public let lastModified: Date?
    
    public init(
        id: String? = nil,
        title: String,
        description: String? = nil,
        startDate: Date,
        endDate: Date,
        location: String? = nil,
        isAllDay: Bool = false,
        recurrenceRule: String? = nil,
        attendees: [CalendarAttendee] = [],
        calendarId: String? = nil,
        url: String? = nil,
        providerId: String? = nil,
        providerType: CalendarServiceType,
        lastModified: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.isAllDay = isAllDay
        self.recurrenceRule = recurrenceRule
        self.attendees = attendees
        self.calendarId = calendarId
        self.url = url
        self.providerId = providerId
        self.providerType = providerType
        self.lastModified = lastModified
    }
    
    // MARK: - Computed Properties
    
    /// Durata dell'evento in minuti
    public var durationInMinutes: Int {
        Int(endDate.timeIntervalSince(startDate) / 60)
    }
    
    /// Indica se l'evento è oggi
    public var isToday: Bool {
        Calendar.current.isDate(startDate, inSameDayAs: Date())
    }
    
    /// Indica se l'evento è nel futuro
    public var isFuture: Bool {
        startDate > Date()
    }
    
    /// Indica se l'evento è attualmente in corso
    public var isHappening: Bool {
        let now = Date()
        return startDate <= now && endDate >= now
    }
}

// MARK: - Calendar Attendee

public struct CalendarAttendee: Codable, Equatable {
    public let email: String
    public let name: String?
    public let status: AttendeeStatus
    public let isOptional: Bool
    
    public init(email: String, name: String? = nil, status: AttendeeStatus = .needsAction, isOptional: Bool = false) {
        self.email = email
        self.name = name
        self.status = status
        self.isOptional = isOptional
    }
}

public enum AttendeeStatus: String, Codable, CaseIterable {
    case needsAction = "needsAction"
    case accepted = "accepted"
    case declined = "declined"
    case tentative = "tentative"
    
    public var displayName: String {
        switch self {
        case .needsAction:
            return "In attesa"
        case .accepted:
            return "Accettato"
        case .declined:
            return "Rifiutato"
        case .tentative:
            return "Tentativo"
        }
    }
}

// MARK: - Calendar Info

public struct CalendarInfo: Identifiable, Codable {
    public let id: String
    public let name: String
    public let description: String?
    public let color: String? // Hex color string
    public let isReadOnly: Bool
    public let isPrimary: Bool
    public let providerType: CalendarServiceType
    
    public init(
        id: String,
        name: String,
        description: String? = nil,
        color: String? = nil,
        isReadOnly: Bool = false,
        isPrimary: Bool = false,
        providerType: CalendarServiceType
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.color = color
        self.isReadOnly = isReadOnly
        self.isPrimary = isPrimary
        self.providerType = providerType
    }
}

// MARK: - Natural Language Parsing Result

public struct NaturalLanguageEventResult {
    public let title: String
    public let date: Date?
    public let duration: TimeInterval?
    public let location: String?
    public let confidence: Double // 0.0 - 1.0
    
    public init(
        title: String,
        date: Date? = nil,
        duration: TimeInterval? = nil,
        location: String? = nil,
        confidence: Double = 0.0
    ) {
        self.title = title
        self.date = date
        self.duration = duration
        self.location = location
        self.confidence = confidence
    }
}

// MARK: - Calendar Event Request
// Per creare eventi da input utente

public struct CalendarEventRequest {
    public let title: String
    public let description: String?
    public let startDate: Date
    public let endDate: Date
    public let location: String?
    public let isAllDay: Bool
    public let attendeeEmails: [String]
    public let calendarId: String?
    
    public init(
        title: String,
        description: String? = nil,
        startDate: Date,
        endDate: Date,
        location: String? = nil,
        isAllDay: Bool = false,
        attendeeEmails: [String] = [],
        calendarId: String? = nil
    ) {
        self.title = title
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.isAllDay = isAllDay
        self.attendeeEmails = attendeeEmails
        self.calendarId = calendarId
    }
}