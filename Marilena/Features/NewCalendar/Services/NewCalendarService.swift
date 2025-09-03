//
//  NewCalendarService.swift
//  Marilena
//
//  Created by AI Assistant
//  Copyright © 2024. All rights reserved.
//

import Foundation
import SwiftUI
import Combine

/// Service principale per il nuovo calendario ispirato a Fantastical
public class NewCalendarService: ObservableObject {
    // MARK: - Published Properties
    @Published public var events: [NewCalendarEvent] = []
    @Published public var calendars: [NewCalendar] = []
    @Published public var selectedDate: Date = Date()
    @Published public var viewMode: NewCalendarViewMode = .month
    @Published public var isLoading: Bool = false

    // MARK: - Private Properties
    private let _calendarManager: CalendarManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public Properties
    public var calendarManager: CalendarManager {
        return _calendarManager
    }

    // MARK: - Initialization
    public init(calendarManager: CalendarManager) {
        self._calendarManager = calendarManager
        setupDefaultCalendars()
        // loadEvents() will be called later when needed
    }

    // MARK: - Public Methods

    /// Carica gli eventi per un intervallo di date specifico
    public func loadEvents(from startDate: Date? = nil, to endDate: Date? = nil) async {
        await MainActor.run { isLoading = true }

        let start = startDate ?? startOfMonth(for: selectedDate)
        let end = endDate ?? endOfMonth(for: selectedDate)

        do {
            // Converti gli eventi esistenti nel nuovo formato
            let existingEvents = _calendarManager.events
            let convertedEvents = existingEvents.map { convertToNewEvent($0) }

            await MainActor.run {
                self.events = convertedEvents
                self.isLoading = false
            }
        } catch {
            print("Error loading events: \(error)")
            await MainActor.run { self.isLoading = false }
        }
    }

    /// Crea un nuovo evento
    public func createEvent(_ event: NewCalendarEvent) async throws {
        // Converti nel formato del calendar manager esistente
        let calendarEvent = convertToCalendarEvent(event)

        do {
            _ = try await _calendarManager.createEvent(CalendarEventRequest(
                title: event.title,
                description: event.notes,
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location,
                isAllDay: event.isAllDay,
                attendeeEmails: event.attendees.map { $0.email },
                calendarId: event.calendarId
            ))

            await loadEvents()
        } catch {
            throw error
        }
    }

    /// Aggiorna un evento esistente
    public func updateEvent(_ event: NewCalendarEvent) async throws {
        let calendarEvent = convertToCalendarEvent(event)

        do {
            try await _calendarManager.updateEvent(calendarEvent)
            await loadEvents()
        } catch {
            throw error
        }
    }

    /// Elimina un evento
    public func deleteEvent(_ eventId: String) async throws {
        do {
            try await _calendarManager.deleteEvent(eventId)
            await loadEvents()
        } catch {
            throw error
        }
    }

    /// Crea evento da testo naturale (Fantastical-style)
    public func createEventFromNaturalLanguage(_ text: String) async throws -> NewCalendarEvent {
        // Analizza il testo per estrarre informazioni
        let parsed = parseNaturalLanguage(text)

        let event = NewCalendarEvent(
            title: parsed.title,
            startDate: parsed.startDate ?? Date(),
            endDate: parsed.endDate ?? (parsed.startDate?.addingTimeInterval(3600) ?? Date().addingTimeInterval(3600)),
            location: parsed.location
        )

        try await createEvent(event)
        return event
    }

    // MARK: - View Data Methods

    /// Restituisce gli eventi per una data specifica
    public func eventsForDate(_ date: Date) -> [NewCalendarEvent] {
        events.filter { event in
            Calendar.current.isDate(event.startDate, inSameDayAs: date) ||
            Calendar.current.isDate(event.endDate, inSameDayAs: date) ||
            (event.startDate < date && event.endDate > date)
        }
    }

    /// Restituisce i dati per la vista mensile
    public func monthData(for date: Date) -> NewCalendarMonth {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month, .year], from: date)

        guard let month = components.month,
              let year = components.year,
              let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
            return NewCalendarMonth(month: 1, year: 2024, weeks: [])
        }

        var weeks: [NewCalendarWeek] = []

        // Trova il primo giorno della settimana che contiene il primo giorno del mese
        let weekdayComponents = calendar.dateComponents([.weekday], from: monthStart)
        let daysToSubtract = (weekdayComponents.weekday! - calendar.firstWeekday + 7) % 7
        let weekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: monthStart)!

        // Crea 6 settimane (massimo necessario per un mese)
        for weekOffset in 0..<6 {
            let currentWeekStart = calendar.date(byAdding: .day, value: weekOffset * 7, to: weekStart)!
            var days: [NewCalendarDay] = []

            for dayOffset in 0..<7 {
                let day = calendar.date(byAdding: .day, value: dayOffset, to: currentWeekStart)!
                let dayEvents = eventsForDate(day)
                let isToday = calendar.isDate(day, inSameDayAs: Date())
                let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)

                days.append(NewCalendarDay(
                    date: day,
                    events: dayEvents,
                    isToday: isToday,
                    isSelected: isSelected
                ))
            }

            let weekOfYear = calendar.component(.weekOfYear, from: currentWeekStart)
            weeks.append(NewCalendarWeek(
                weekOfYear: weekOfYear,
                year: year,
                days: days
            ))
        }

        return NewCalendarMonth(month: month, year: year, weeks: weeks)
    }

    /// Restituisce i dati per la vista settimanale
    public func weekData(for date: Date) -> NewCalendarWeek {
        let calendar = Calendar.current
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!

        var days: [NewCalendarDay] = []

        for dayOffset in 0..<7 {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
            let dayEvents = eventsForDate(day)
            let isToday = calendar.isDate(day, inSameDayAs: Date())
            let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)

            days.append(NewCalendarDay(
                date: day,
                events: dayEvents,
                isToday: isToday,
                isSelected: isSelected
            ))
        }

        let weekOfYear = calendar.component(.weekOfYear, from: weekStart)
        let year = calendar.component(.year, from: weekStart)

        return NewCalendarWeek(weekOfYear: weekOfYear, year: year, days: days)
    }

    /// Restituisce i dati per la vista giornaliera
    public func dayData(for date: Date) -> [NewCalendarEvent] {
        eventsForDate(date).sorted { $0.startDate < $1.startDate }
    }

    /// Restituisce gli eventi per la vista agenda
    public func agendaEvents(from startDate: Date, days: Int = 30) -> [Date: [NewCalendarEvent]] {
        var agendaData: [Date: [NewCalendarEvent]] = [:]

        for dayOffset in 0..<days {
            let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: startDate)!
            let dayEvents = eventsForDate(date)
            if !dayEvents.isEmpty {
                agendaData[date] = dayEvents.sorted { $0.startDate < $1.startDate }
            }
        }

        return agendaData
    }

    // MARK: - Navigation Methods

    public func selectDate(_ date: Date) {
        selectedDate = date
    }

    public func navigateToNextPeriod() {
        let calendar = Calendar.current

        switch viewMode {
        case .month:
            if let nextMonth = calendar.date(byAdding: .month, value: 1, to: selectedDate) {
                selectedDate = nextMonth
            }
        case .week:
            if let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) {
                selectedDate = nextWeek
            }
        case .day:
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: selectedDate) {
                selectedDate = nextDay
            }
        case .agenda, .year:
            // Implementazione futura
            break
        }
    }

    public func navigateToPreviousPeriod() {
        let calendar = Calendar.current

        switch viewMode {
        case .month:
            if let previousMonth = calendar.date(byAdding: .month, value: -1, to: selectedDate) {
                selectedDate = previousMonth
            }
        case .week:
            if let previousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) {
                selectedDate = previousWeek
            }
        case .day:
            if let previousDay = calendar.date(byAdding: .day, value: -1, to: selectedDate) {
                selectedDate = previousDay
            }
        case .agenda, .year:
            // Implementazione futura
            break
        }
    }

    public func navigateToToday() {
        selectedDate = Date()
    }

    // MARK: - Private Methods

    private func setupDefaultCalendars() {
        calendars = [
            NewCalendar(title: "Personale", color: .blue, accountType: .local),
            NewCalendar(title: "Lavoro", color: .red, accountType: .local),
            NewCalendar(title: "Famiglia", color: .green, accountType: .local)
        ]
    }

    private func convertToNewEvent(_ event: CalendarEvent) -> NewCalendarEvent {
        NewCalendarEvent(
            id: event.id ?? UUID().uuidString,
            title: event.title,
            notes: event.description,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            location: event.location,
            attendees: event.attendees.map { Attendee(name: $0.name ?? "", email: $0.email ?? "") },
            calendarId: event.calendarId,
            color: Color.blue // Default color, should be based on calendar
        )
    }

    private func convertToCalendarEvent(_ event: NewCalendarEvent) -> CalendarEvent {
        CalendarEvent(
            id: event.id,
            title: event.title,
            description: event.notes,
            startDate: event.startDate,
            endDate: event.endDate,
            location: event.location,
            isAllDay: event.isAllDay,
            recurrenceRule: nil, // Implementare conversione
            attendees: event.attendees.map { CalendarAttendee(email: $0.email ?? "", name: $0.name) },
            calendarId: event.calendarId,
            url: event.url?.absoluteString,
            providerId: event.id,
            providerType: .eventKit,
            lastModified: event.modified
        )
    }

    private func parseNaturalLanguage(_ text: String) -> (title: String, startDate: Date?, endDate: Date?, location: String?) {
        // Implementazione semplice del parsing del linguaggio naturale
        // In una versione completa, questo dovrebbe usare NLP più sofisticato

        let lowerText = text.lowercased()

        // Estrai titolo (tutto tranne le parole chiave temporali)
        var title = text
        var startDate: Date?
        var endDate: Date?
        var location: String?

        // Pattern semplici per il riconoscimento temporale
        let timePatterns = [
            "oggi": Date(),
            "domani": Calendar.current.date(byAdding: .day, value: 1, to: Date()),
            "dopodomani": Calendar.current.date(byAdding: .day, value: 2, to: Date())
        ]

        for (pattern, date) in timePatterns {
            if lowerText.contains(pattern) {
                startDate = date
                title = title.replacingOccurrences(of: pattern, with: "", options: .caseInsensitive)
                break
            }
        }

        // Se non trova date specifiche, assume oggi
        if startDate == nil {
            startDate = Date()
        }

        // Imposta durata predefinita di 1 ora
        if let start = startDate {
            endDate = start.addingTimeInterval(3600)
        }

        // Pulisce il titolo
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty {
            title = "Nuovo evento"
        }

        return (title, startDate, endDate, location)
    }

    private func startOfMonth(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    private func endOfMonth(for date: Date) -> Date {
        let calendar = Calendar.current
        let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth(for: date))!
        return calendar.date(byAdding: .day, value: -1, to: startOfNextMonth)!
    }
}

// MARK: - Extensions

extension NewCalendarService {
    /// Restituisce il nome del mese formattato
    public func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    /// Restituisce il nome del giorno della settimana
    public func weekdayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    /// Restituisce il numero del giorno
    public func dayNumber(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}
