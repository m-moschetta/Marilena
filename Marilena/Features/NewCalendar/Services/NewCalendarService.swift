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

// MARK: - Gesture State Types
public enum CalendarGestureState {
    case idle
    case navigating(direction: NavigationDirection)
    case creating(startTime: Date, currentTime: Date)
    case dragging(eventId: String, offset: CGSize)
    case resizing(eventId: String, newDuration: TimeInterval)
    case zooming(scale: CGFloat)
}

public enum NavigationDirection {
    case left, right, up, down
}

public struct GesturePreferences {
    public var isNavigationEnabled: Bool = true
    public var isPinchToZoomEnabled: Bool = true
    public var isEventDragEnabled: Bool = true
    public var isEventCreateEnabled: Bool = true
    public var hapticFeedbackEnabled: Bool = true
    
    public init() {}
}

/// Service principale per il nuovo calendario ispirato a Fantastical
public class NewCalendarService: ObservableObject {
    // MARK: - Published Properties
    @Published public var events: [NewCalendarEvent] = []
    @Published public var calendars: [NewCalendar] = []
    @Published public var selectedDate: Date = Date()
    @Published public var viewMode: NewCalendarViewMode = .month
    @Published public var isLoading: Bool = false
    
    // MARK: - Gesture Properties
    @Published public var gestureState: CalendarGestureState = .idle
    @Published public var isRefreshing: Bool = false
    public var gesturePreferences: GesturePreferences = GesturePreferences()

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
    
    // MARK: - Gesture Handling Methods
    
    /// Gestisce lo swipe orizzontale per la navigazione
    public func handleHorizontalSwipe(_ direction: NavigationDirection) {
        guard gesturePreferences.isNavigationEnabled else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            gestureState = .navigating(direction: direction)
            
            switch direction {
            case .left:
                navigateToNextPeriod()
            case .right:
                navigateToPreviousPeriod()
            default:
                break
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.gestureState = .idle
            }
        }
        
        if gesturePreferences.hapticFeedbackEnabled {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }
    }
    
    // MARK: - Day View Zoom Properties
    @Published public var dayViewHourHeight: CGFloat = 60.0
    private let minHourHeight: CGFloat = 30.0
    private let maxHourHeight: CGFloat = 120.0
    
    /// Gestisce il pinch-to-zoom nella vista giorno per controllare l'altezza delle ore
    public func handleDayViewPinchGesture(scale: CGFloat) {
        guard gesturePreferences.isPinchToZoomEnabled && viewMode == .day else { return }
        
        gestureState = .zooming(scale: scale)
        
        let newHourHeight = dayViewHourHeight * scale
        
        // Applica i limiti min/max
        if newHourHeight >= minHourHeight && newHourHeight <= maxHourHeight {
            withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                dayViewHourHeight = newHourHeight
            }
            
            if gesturePreferences.hapticFeedbackEnabled {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred(intensity: 0.3)
            }
        }
    }
    
    /// Gestisce il pinch-to-zoom per cambiare tra le viste (mantenuto per altre viste)
    public func handleViewModePinchGesture(scale: CGFloat) {
        guard gesturePreferences.isPinchToZoomEnabled && viewMode != .day else { return }
        
        gestureState = .zooming(scale: scale)
        
        // Cambia vista basandosi sulla scala
        let newViewMode: NewCalendarViewMode
        if scale > 1.2 {
            // Zoom in - vista più dettagliata
            switch viewMode {
            case .month: newViewMode = .week
            case .week: newViewMode = .day
            case .agenda: newViewMode = .day
            case .year: newViewMode = .month
            case .day: return // Non cambiare dalla vista giorno
            }
        } else if scale < 0.8 {
            // Zoom out - vista meno dettagliata
            switch viewMode {
            case .month: newViewMode = .year
            case .week: newViewMode = .month
            case .day: return // Non cambiare dalla vista giorno
            case .agenda: newViewMode = .month
            case .year: newViewMode = .year
            }
        } else {
            return
        }
        
        if newViewMode != viewMode {
            withAnimation(.easeInOut(duration: 0.25)) {
                viewMode = newViewMode
            }
            
            if gesturePreferences.hapticFeedbackEnabled {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            }
        }
    }
    
    /// Reimposta l'altezza delle ore al valore predefinito
    public func resetDayViewZoom() {
        withAnimation(.easeInOut(duration: 0.3)) {
            dayViewHourHeight = 60.0
        }
    }
    
    /// Calcola quante ore sono visibili basandosi sull'altezza corrente
    public func visibleHoursInDayView(screenHeight: CGFloat) -> Int {
        let availableHeight = screenHeight - 200 // Rimuovi spazio per header/toolbar
        let visibleHours = Int(availableHeight / dayViewHourHeight)
        return max(4, min(24, visibleHours)) // Minimo 4 ore, massimo 24
    }
    
    /// Completa il gesto di pinch
    public func completePinchGesture() {
        gestureState = .idle
    }
    
    /// Gestisce la creazione di eventi con long press + drag
    public func startEventCreation(at date: Date) {
        guard gesturePreferences.isEventCreateEnabled else { return }
        
        gestureState = .creating(startTime: date, currentTime: date)
        
        if gesturePreferences.hapticFeedbackEnabled {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        }
    }
    
    /// Aggiorna la creazione evento durante il drag
    public func updateEventCreation(endTime: Date) {
        guard case .creating(let startTime, _) = gestureState else { return }
        gestureState = .creating(startTime: startTime, currentTime: endTime)
    }
    
    /// Completa la creazione evento
    public func completeEventCreation() -> (start: Date, end: Date)? {
        guard case .creating(let startTime, let endTime) = gestureState else { return nil }
        
        gestureState = .idle
        
        let actualStart = min(startTime, endTime)
        let actualEnd = max(startTime, endTime)
        
        // Assicura durata minima di 30 minuti
        let minDuration: TimeInterval = 30 * 60
        let finalEnd = actualEnd.timeIntervalSince(actualStart) < minDuration ?
            actualStart.addingTimeInterval(minDuration) : actualEnd
        
        if gesturePreferences.hapticFeedbackEnabled {
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
        }
        
        return (actualStart, finalEnd)
    }
    
    /// Cancella la creazione evento
    public func cancelEventCreation() {
        gestureState = .idle
    }
    
    /// Gestisce il drag di un evento esistente
    public func startEventDrag(eventId: String) {
        guard gesturePreferences.isEventDragEnabled else { return }
        
        gestureState = .dragging(eventId: eventId, offset: .zero)
        
        if gesturePreferences.hapticFeedbackEnabled {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }
    }
    
    /// Aggiorna il drag dell'evento
    public func updateEventDrag(eventId: String, offset: CGSize) {
        gestureState = .dragging(eventId: eventId, offset: offset)
    }
    
    /// Completa il drag dell'evento
    public func completeEventDrag(eventId: String, newStartTime: Date) async {
        gestureState = .idle
        
        // Trova l'evento e aggiorna il suo orario
        if let eventIndex = events.firstIndex(where: { $0.id == eventId }) {
            let event = events[eventIndex]
            let duration = event.endDate.timeIntervalSince(event.startDate)
            let newEndTime = newStartTime.addingTimeInterval(duration)
            
            var updatedEvent = event
            updatedEvent.startDate = newStartTime
            updatedEvent.endDate = newEndTime
            
            do {
                try await updateEvent(updatedEvent)
                
                if gesturePreferences.hapticFeedbackEnabled {
                    let notification = UINotificationFeedbackGenerator()
                    notification.notificationOccurred(.success)
                }
            } catch {
                print("Error updating event: \(error)")
                
                if gesturePreferences.hapticFeedbackEnabled {
                    let notification = UINotificationFeedbackGenerator()
                    notification.notificationOccurred(.error)
                }
            }
        }
    }
    
    /// Gestisce il pull-to-refresh
    public func handlePullToRefresh() async {
        isRefreshing = true
        await loadEvents()
        
        // Simula un piccolo delay per migliorare UX
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        isRefreshing = false
        
        if gesturePreferences.hapticFeedbackEnabled {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }
    }
    
    /// Gestisce il doppio tap per creazione rapida evento
    public func handleDoubleTap(at date: Date) {
        guard gesturePreferences.isEventCreateEnabled else { return }
        
        if gesturePreferences.hapticFeedbackEnabled {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        }
        
        // Ritorna le date per la creazione rapida
        // Sarà gestito dalla vista che chiama questo metodo
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
