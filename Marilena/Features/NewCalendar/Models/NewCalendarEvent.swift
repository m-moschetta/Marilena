//
//  NewCalendarEvent.swift
//  Marilena
//
//  Created by AI Assistant
//  Copyright © 2024. All rights reserved.
//

import Foundation
import SwiftUI

/// Modello principale per gli eventi del nuovo calendario ispirato a Fantastical
public struct NewCalendarEvent: Identifiable, Codable, Hashable {
    public let id: String
    public var title: String
    public var notes: String?
    public var startDate: Date
    public var endDate: Date
    public var isAllDay: Bool
    public var location: String?
    public var attendees: [Attendee]
    public var calendarId: String?
    public var color: CodableColor
    public var recurrenceRule: NewRecurrenceRule?
    public var reminders: [NewReminder]
    public var url: URL?
    public var priority: NewPriority
    public var status: NewEventStatus
    public var created: Date
    public var modified: Date

    // Proprietà calcolate per Fantastical-style
    public var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    public var isMultiDay: Bool {
        !Calendar.current.isDate(startDate, inSameDayAs: endDate)
    }

    public var formattedTimeRange: String {
        if isAllDay {
            return "All day"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        let startTime = formatter.string(from: startDate)
        let endTime = formatter.string(from: endDate)

        return "\(startTime) - \(endTime)"
    }

    public var daySpan: Int {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)
        let components = calendar.dateComponents([.day], from: startDay, to: endDay)
        return components.day ?? 0
    }

    public init(
        id: String = UUID().uuidString,
        title: String,
        notes: String? = nil,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        location: String? = nil,
        attendees: [Attendee] = [],
        calendarId: String? = nil,
        color: Color = .blue,
        recurrenceRule: NewRecurrenceRule? = nil,
        reminders: [NewReminder] = [],
        url: URL? = nil,
        priority: NewPriority = .none,
        status: NewEventStatus = .confirmed
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
        self.attendees = attendees
        self.calendarId = calendarId
        self.color = CodableColor(color)
        self.recurrenceRule = recurrenceRule
        self.reminders = reminders
        self.url = url
        self.priority = priority
        self.status = status
        self.created = Date()
        self.modified = Date()
    }

    // Proprietà calcolata per accedere facilmente al Color
    public var uiColor: Color {
        get { color.color }
        set { color = CodableColor(newValue) }
    }
}

// MARK: - Supporting Types

public struct Attendee: Codable, Hashable {
    public let name: String
    public let email: String
    public let status: NewAttendeeStatus

    public init(name: String, email: String, status: NewAttendeeStatus = .pending) {
        self.name = name
        self.email = email
        self.status = status
    }
}

public enum NewAttendeeStatus: String, Codable {
    case pending, accepted, declined, tentative
}

public struct NewRecurrenceRule: Codable, Hashable {
    public let frequency: NewRecurrenceFrequency
    public let interval: Int
    public let endDate: Date?
    public let count: Int?

    public init(frequency: NewRecurrenceFrequency, interval: Int = 1, endDate: Date? = nil, count: Int? = nil) {
        self.frequency = frequency
        self.interval = interval
        self.endDate = endDate
        self.count = count
    }
}

public enum NewRecurrenceFrequency: String, Codable {
    case daily, weekly, monthly, yearly
}

public struct NewReminder: Codable, Hashable {
    public let minutesBefore: Int
    public let method: NewReminderMethod

    public init(minutesBefore: Int, method: NewReminderMethod = .alert) {
        self.minutesBefore = minutesBefore
        self.method = method
    }
}

public enum NewReminderMethod: String, Codable {
    case alert, email, sms
}

public enum NewPriority: Int, Codable {
    case none = 0, low = 1, medium = 5, high = 9
}

public enum NewEventStatus: String, Codable {
    case confirmed, tentative, cancelled
}

// MARK: - Color Wrapper for Codable Support

public struct CodableColor: Codable, Hashable {
    public var color: Color

    public init(_ color: Color) {
        self.color = color
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let colorName = try container.decode(String.self)

        switch colorName {
        case "blue": self.color = .blue
        case "red": self.color = .red
        case "green": self.color = .green
        case "orange": self.color = .orange
        case "purple": self.color = .purple
        case "pink": self.color = .pink
        case "yellow": self.color = .yellow
        case "gray": self.color = .gray
        case "black": self.color = .black
        default: self.color = .blue
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        // Converti Color in stringa rappresentativa
        if color == .blue { try container.encode("blue") }
        else if color == .red { try container.encode("red") }
        else if color == .green { try container.encode("green") }
        else if color == .orange { try container.encode("orange") }
        else if color == .purple { try container.encode("purple") }
        else if color == .pink { try container.encode("pink") }
        else if color == .yellow { try container.encode("yellow") }
        else if color == .gray { try container.encode("gray") }
        else if color == .black { try container.encode("black") }
        else { try container.encode("blue") }
    }
}

// MARK: - Calendar Models

public struct NewCalendar: Identifiable, Codable, Hashable {
    public let id: String
    public var title: String
    public var color: CodableColor
    public var isVisible: Bool
    public var accountType: NewCalendarAccountType

    public init(
        id: String = UUID().uuidString,
        title: String,
        color: Color = .blue,
        isVisible: Bool = true,
        accountType: NewCalendarAccountType = .local
    ) {
        self.id = id
        self.title = title
        self.color = CodableColor(color)
        self.isVisible = isVisible
        self.accountType = accountType
    }

    // Proprietà calcolata per ottenere il Color direttamente
    public var uiColor: Color {
        get { color.color }
        set { color = CodableColor(newValue) }
    }
}

public enum NewCalendarAccountType: String, Codable {
    case local, iCloud, google, microsoft, other
}

// MARK: - View Models

public enum NewCalendarViewMode {
    case month, week, day, agenda, year

    var title: String {
        switch self {
        case .month: return "Month"
        case .week: return "Week"
        case .day: return "Day"
        case .agenda: return "Agenda"
        case .year: return "Year"
        }
    }
}

public struct NewCalendarDay: Identifiable {
    public let id = UUID()
    public let date: Date
    public let events: [NewCalendarEvent]
    public let isToday: Bool
    public let isSelected: Bool

    public init(date: Date, events: [NewCalendarEvent] = [], isToday: Bool = false, isSelected: Bool = false) {
        self.date = date
        self.events = events
        self.isToday = isToday
        self.isSelected = isSelected
    }
}

public struct NewCalendarWeek {
    public let weekOfYear: Int
    public let year: Int
    public let days: [NewCalendarDay]

    public init(weekOfYear: Int, year: Int, days: [NewCalendarDay]) {
        self.weekOfYear = weekOfYear
        self.year = year
        self.days = days
    }
}

public struct NewCalendarMonth {
    public let month: Int
    public let year: Int
    public let weeks: [NewCalendarWeek]

    public init(month: Int, year: Int, weeks: [NewCalendarWeek]) {
        self.month = month
        self.year = year
        self.weeks = weeks
    }
}
