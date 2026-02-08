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
    @Published public private(set) var events: [NewCalendarEvent] = []
    @Published public var calendars: [NewCalendar] = []
    @Published public var selectedDate: Date = Date()
    @Published public var viewMode: NewCalendarViewMode = .day
    @Published public var isLoading: Bool = false
    
    // MARK: - Gesture Properties
    @Published public var gestureState: CalendarGestureState = .idle
    @Published public var isRefreshing: Bool = false
    public var gesturePreferences: GesturePreferences = GesturePreferences()

    // MARK: - Private Properties
    private let _calendarManager: CalendarManager
    private let eventParser = FoundationModelsEventParser.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Caching Properties
    private var viewDataCache: [String: Any] = [:]
    private var lastEventsUpdate: Date = Date.distantPast
    private let cacheValidityDuration: TimeInterval = 300 // 5 minuti

    // MARK: - Lazy Loading Properties
    private var isInitialLoadComplete = false
    private var preloadedDateRanges: Set<ClosedRange<Date>> = []
    private let preloadBufferDays: Int = 7

    // MARK: - Performance Optimization Properties
    private var sortedEventsByDate: [NewCalendarEvent] = []
    private var eventsByDateIndex: [Date: [NewCalendarEvent]] = [:]
    private var isEventsSorted = false

    // MARK: - Debouncing Properties
    private var navigationDebounceTimer: Timer?
    private var pendingNavigationDate: Date?
    private let navigationDebounceInterval: TimeInterval = 0.3 // 300ms

    // MARK: - Background Loading Properties
    private var backgroundLoadTimer: Timer?
    private var isUserActive = true
    private let backgroundLoadDelay: TimeInterval = 2.0 // 2 secondi di inattività
    private let backgroundLoadInterval: TimeInterval = 300 // 5 minuti
    
    // MARK: - Public Properties
    public var calendarManager: CalendarManager {
        return _calendarManager
    }

    // MARK: - Initialization
    public init(calendarManager: CalendarManager) {
        self._calendarManager = calendarManager
        setupDefaultCalendars()
        setupCalendarManagerObserver()
        // loadEvents() will be called later when needed
    }

    // MARK: - Caching Methods

    /// Genera una chiave di cache per i dati di vista
    private func cacheKey(for date: Date, viewMode: NewCalendarViewMode) -> String {
        let dateKey = date.formatted(date: .numeric, time: .omitted)
        return "\(viewMode.title)_\(dateKey)"
    }

    /// Verifica se il cache è valido
    private func isCacheValid(for key: String) -> Bool {
        guard let cachedDate = viewDataCache["\(key)_timestamp"] as? Date else {
            return false
        }
        return Date().timeIntervalSince(cachedDate) < cacheValidityDuration
    }

    /// Invalida il cache per una data specifica
    private func invalidateCache(for date: Date, viewMode: NewCalendarViewMode) {
        let key = cacheKey(for: date, viewMode: viewMode)
        viewDataCache.removeValue(forKey: key)
        viewDataCache.removeValue(forKey: "\(key)_timestamp")
    }

    /// Invalida tutto il cache
    private func invalidateAllCache() {
        viewDataCache.removeAll()
    }

    /// Setup observer per il CalendarManager
    private func setupCalendarManagerObserver() {
        _calendarManager.$events
            .sink { [weak self] _ in
                self?.handleEventsUpdate()
            }
            .store(in: &cancellables)
    }

    /// Gestisce l'aggiornamento degli eventi
    private func handleEventsUpdate() {
        lastEventsUpdate = Date()
        invalidateAllCache()

        // Sincronizza gli eventi dal CalendarManager
        let updatedEvents = _calendarManager.events.map { convertToNewEvent($0) }
        mergeEvents(updatedEvents)

        rebuildEventIndexes()
    }

    /// Ricostruisce gli indici per ottimizzare il filtraggio
    private func rebuildEventIndexes() {
        isEventsSorted = false
        eventsByDateIndex.removeAll()
    }

    /// Ordina gli eventi per data se non già ordinati
    private func ensureEventsSorted() {
        guard !isEventsSorted else { return }

        sortedEventsByDate = events.sorted { $0.startDate < $1.startDate }
        isEventsSorted = true
    }

    /// Crea l'indice degli eventi per data per ottimizzare le ricerche
    private func buildEventsByDateIndex() {
        eventsByDateIndex.removeAll()
        let calendar = Calendar.current

        for event in events {
            let eventDates = eventDateRange(for: event, calendar: calendar)

            for date in eventDates {
                let dayStart = calendar.startOfDay(for: date)
                eventsByDateIndex[dayStart, default: []].append(event)
            }
        }
    }

    /// Calcola l'intervallo di date per un evento (per eventi che si estendono su più giorni)
    private func eventDateRange(for event: NewCalendarEvent, calendar: Calendar) -> [Date] {
        var dates: [Date] = []
        let startOfStartDay = calendar.startOfDay(for: event.startDate)
        let endOfEndDay = calendar.startOfDay(for: event.endDate)

        var currentDate = startOfStartDay
        while currentDate <= endOfEndDay {
            dates.append(currentDate)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        return dates
    }

    // MARK: - Debouncing Methods

    /// Gestisce la navigazione con debouncing per evitare caricamenti multipli
    private func debouncedNavigate(to date: Date) {
        // Cancella il timer precedente se esiste
        navigationDebounceTimer?.invalidate()

        pendingNavigationDate = date

        // Imposta un nuovo timer
        navigationDebounceTimer = Timer.scheduledTimer(withTimeInterval: navigationDebounceInterval, repeats: false) { [weak self] _ in
            guard let self = self, let pendingDate = self.pendingNavigationDate else { return }

            // Esegui la navigazione effettiva
            self.performNavigation(to: pendingDate)
            self.pendingNavigationDate = nil
        }
    }

    /// Esegue la navigazione effettiva dopo il debouncing
    private func performNavigation(to date: Date) {
        // L'utente è attivo, quindi interrompi il background loading
        markUserActive()

        selectedDate = date

        // Pre-carica i dati per la nuova data
        Task {
            await self.preloadDataForDate(date)
        }
    }

    // MARK: - Background Loading Methods

    /// Segnala che l'utente è attivo (annulla il background loading)
    public func markUserActive() {
        isUserActive = true
        resetBackgroundLoadTimer()
    }

    /// Segnala che l'utente è inattivo (avvia il background loading)
    public func markUserInactive() {
        isUserActive = false
        scheduleBackgroundLoading()
    }

    /// Pianifica il caricamento in background
    private func scheduleBackgroundLoading() {
        backgroundLoadTimer?.invalidate()

        backgroundLoadTimer = Timer.scheduledTimer(withTimeInterval: backgroundLoadDelay, repeats: false) { [weak self] _ in
            self?.performBackgroundLoading()
        }
    }

    /// Resetta il timer di background loading
    private func resetBackgroundLoadTimer() {
        backgroundLoadTimer?.invalidate()
        if !isUserActive {
            scheduleBackgroundLoading()
        }
    }

    /// Esegue il caricamento in background di dati non essenziali
    private func performBackgroundLoading() {
        guard !isUserActive && !isLoading else { return }

        Task { [weak self] in
            await self?.loadBackgroundEvents()
        }

        // Ripianifica il prossimo caricamento in background
        scheduleNextBackgroundLoad()
    }

    /// Carica eventi in background per migliorare le performance future
    private func loadBackgroundEvents() async {
        let now = Date()
        let futureStartDate = Calendar.current.date(byAdding: .day, value: preloadBufferDays * 3, to: now)!
        let futureEndDate = Calendar.current.date(byAdding: .day, value: preloadBufferDays * 6, to: now)!

        // Carica eventi futuri che non sono ancora caricati
        let futureRange = futureStartDate...futureEndDate
        if !isDateRangePreloaded(futureRange) {
            await loadEvents(from: futureStartDate, to: futureEndDate, forceRefresh: false)
        }
    }

    /// Pianifica il prossimo caricamento in background
    private func scheduleNextBackgroundLoad() {
        backgroundLoadTimer = Timer.scheduledTimer(withTimeInterval: backgroundLoadInterval, repeats: false) { [weak self] _ in
            self?.performBackgroundLoading()
        }
    }

    // MARK: - Lazy Loading Methods

    /// Verifica se una data è già pre-caricata
    private func isDateRangePreloaded(_ dateRange: ClosedRange<Date>) -> Bool {
        return preloadedDateRanges.contains { existingRange in
            existingRange.overlaps(dateRange) || existingRange.contains(dateRange.lowerBound)
        }
    }

    /// Marca un intervallo di date come pre-caricato
    private func markDateRangeAsPreloaded(_ dateRange: ClosedRange<Date>) {
        preloadedDateRanges.insert(dateRange)
    }

    // MARK: - Public Methods

    /// Carica gli eventi per un intervallo di date specifico
    public func loadEvents(from startDate: Date? = nil, to endDate: Date? = nil, forceRefresh: Bool = false) async {
        let start = startDate ?? startOfMonth(for: selectedDate)
        let end = endDate ?? endOfMonth(for: selectedDate)

        // Controlla se i dati sono già caricati e validi
        let dateRange = start...end
        if !forceRefresh && isDateRangePreloaded(dateRange) && isInitialLoadComplete {
            await MainActor.run { isLoading = false }
            return
        }

        await MainActor.run { isLoading = true }

        do {
            // Se è il primo caricamento, usa gli eventi esistenti dal CalendarManager
            if !isInitialLoadComplete {
                let existingEvents = _calendarManager.events
                let convertedEvents = existingEvents.map { convertToNewEvent($0) }

                await MainActor.run {
                    self.events = convertedEvents
                    self.isLoading = false
                    self.isInitialLoadComplete = true
                    self.markDateRangeAsPreloaded(dateRange)
                    self.buildEventsByDateIndex() // Costruisci l'indice per ottimizzare le ricerche
                }
            } else {
                // Per caricamenti successivi, carica e unisci gli eventi
                await _calendarManager.loadEvents(from: start, to: end)

                let existingEvents = _calendarManager.events
                let newConvertedEvents = existingEvents.map { convertToNewEvent($0) }

                await MainActor.run {
                    // Unisci gli eventi invece di sostituirli completamente
                    self.mergeEvents(newConvertedEvents)
                    self.isLoading = false
                    self.markDateRangeAsPreloaded(dateRange)
                    self.buildEventsByDateIndex() // Costruisci l'indice per ottimizzare le ricerche
                }
            }
        } catch {
            print("Error loading events: \(error)")
            await MainActor.run { self.isLoading = false }
        }
    }

    /// Unisce nuovi eventi con quelli esistenti evitando duplicati
    private func mergeEvents(_ newEvents: [NewCalendarEvent]) {
        var eventDict = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0) })

        for newEvent in newEvents {
            eventDict[newEvent.id] = newEvent
        }

        events = Array(eventDict.values).sorted { $0.startDate < $1.startDate }
        isEventsSorted = true
    }

    /// Carica gli eventi iniziali con pre-caricamento intelligente
    public func loadInitialEvents() async {
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -preloadBufferDays, to: now)!
        let endDate = Calendar.current.date(byAdding: .day, value: preloadBufferDays * 2, to: now)!

        await loadEvents(from: startDate, to: endDate)
    }

    /// Crea un nuovo evento
    public func createEvent(_ event: NewCalendarEvent) async throws {
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

            // Aggiorna direttamente l'array locale per un refresh immediato
            await MainActor.run {
                // Usa mergeEvents per evitare duplicati e mantenere l'ordinamento
                self.mergeEvents([event])
                // Invalida il cache per le date interessate
                self.invalidateCache(for: event.startDate, viewMode: .day)
                self.invalidateCache(for: event.startDate, viewMode: .week)
                self.invalidateCache(for: event.startDate, viewMode: .month)
                // Ricostruisci l'indice per le ricerche ottimizzate
                self.buildEventsByDateIndex()
            }

            // Aggiorna il lastEventsUpdate per invalidare altri cache
            lastEventsUpdate = Date()
        } catch {
            throw error
        }
    }

    /// Aggiorna un evento esistente
    public func updateEvent(_ event: NewCalendarEvent) async throws {
        let calendarEvent = convertToCalendarEvent(event)

        do {
            try await _calendarManager.updateEvent(calendarEvent)

            // Aggiorna direttamente l'evento nell'array locale per un refresh immediato
            await MainActor.run {
                // Usa mergeEvents per aggiornare l'evento e mantenere l'ordinamento
                self.mergeEvents([event])
                // Invalida il cache per le date interessate
                self.invalidateCache(for: event.startDate, viewMode: .day)
                self.invalidateCache(for: event.startDate, viewMode: .week)
                self.invalidateCache(for: event.startDate, viewMode: .month)
                // Ricostruisci l'indice per le ricerche ottimizzate
                self.buildEventsByDateIndex()
            }

            // Aggiorna il lastEventsUpdate per invalidare altri cache
            lastEventsUpdate = Date()
        } catch {
            throw error
        }
    }

    /// Elimina un evento
    public func deleteEvent(_ eventId: String) async throws {
        do {
            // Trova l'evento prima di eliminarlo
            guard let eventToDelete = events.first(where: { $0.id == eventId }) else {
                throw CalendarServiceError.eventNotFound
            }

            try await _calendarManager.deleteEvent(eventId)

            // Rimuovi direttamente l'evento dall'array locale per un refresh immediato
            await MainActor.run {
                if let index = self.events.firstIndex(where: { $0.id == eventId }) {
                    self.events.remove(at: index)
                    // Invalida il cache per le date interessate
                    self.invalidateCache(for: eventToDelete.startDate, viewMode: .day)
                    self.invalidateCache(for: eventToDelete.startDate, viewMode: .week)
                    self.invalidateCache(for: eventToDelete.startDate, viewMode: .month)
                    // Ricostruisci l'indice per le ricerche ottimizzate
                    self.buildEventsByDateIndex()
                }
            }

            // Aggiorna il lastEventsUpdate per invalidare altri cache
            lastEventsUpdate = Date()
        } catch {
            throw error
        }
    }

    /// Crea evento da testo naturale sfruttando Apple Foundation Models quando disponibili
    public func createEventFromNaturalLanguage(_ text: String) async throws -> NewCalendarEvent {
        let candidate = try await eventParser.parseEvent(from: text, referenceDate: selectedDate)
        let event = buildEvent(from: candidate, fallbackText: text, referenceDate: selectedDate)
        try await createEvent(event)
        return event
    }

    /// Restituisce un evento suggerito senza crearlo, utile per l'anteprima
    public func suggestedEvent(from text: String) async -> NewCalendarEvent? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        do {
            let candidate = try await eventParser.parseEvent(from: text, referenceDate: selectedDate)
            return buildEvent(from: candidate, fallbackText: text, referenceDate: selectedDate)
        } catch {
            print("Errore analisi linguaggio naturale: \(error)")
            return nil
        }
    }

    // MARK: - View Data Methods

    /// Restituisce gli eventi per una data specifica (ottimizzato con indice)
    public func eventsForDate(_ date: Date) -> [NewCalendarEvent] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)

        // Se abbiamo l'indice, usalo per una ricerca più veloce
        if !eventsByDateIndex.isEmpty {
            return eventsByDateIndex[dayStart] ?? []
        }

        // Fallback al filtraggio tradizionale se l'indice non è disponibile
        return events.filter { event in
            let eventStartDay = calendar.startOfDay(for: event.startDate)
            let eventEndDay = calendar.startOfDay(for: event.endDate)
            return eventStartDay <= dayStart && eventEndDay >= dayStart
        }
    }

    /// Restituisce i dati per la vista mensile (con caching)
    public func monthData(for date: Date) -> NewCalendarMonth {
        let cacheKey = self.cacheKey(for: date, viewMode: .month)

        // Controlla se i dati sono in cache e validi
        if let cachedData = viewDataCache[cacheKey] as? NewCalendarMonth,
           isCacheValid(for: cacheKey) {
            return cachedData
        }

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

        let monthData = NewCalendarMonth(month: month, year: year, weeks: weeks)

        // Salva in cache
        viewDataCache[cacheKey] = monthData
        viewDataCache["\(cacheKey)_timestamp"] = Date()

        return monthData
    }

    /// Restituisce i dati per la vista settimanale (con caching)
    public func weekData(for date: Date) -> NewCalendarWeek {
        let cacheKey = self.cacheKey(for: date, viewMode: .week)

        // Controlla se i dati sono in cache e validi
        if let cachedData = viewDataCache[cacheKey] as? NewCalendarWeek,
           isCacheValid(for: cacheKey) {
            return cachedData
        }

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

        let weekData = NewCalendarWeek(weekOfYear: weekOfYear, year: year, days: days)

        // Salva in cache
        viewDataCache[cacheKey] = weekData
        viewDataCache["\(cacheKey)_timestamp"] = Date()

        return weekData
    }

    /// Restituisce i dati per la vista giornaliera (con caching)
    public func dayData(for date: Date) -> [NewCalendarEvent] {
        let cacheKey = self.cacheKey(for: date, viewMode: .day)

        // Controlla se i dati sono in cache e validi
        if let cachedData = viewDataCache[cacheKey] as? [NewCalendarEvent],
           isCacheValid(for: cacheKey) {
            return cachedData
        }

        let dayEvents = eventsForDate(date).sorted { $0.startDate < $1.startDate }

        // Salva in cache
        viewDataCache[cacheKey] = dayEvents
        viewDataCache["\(cacheKey)_timestamp"] = Date()

        return dayEvents
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
        // Se la data è la stessa, non fare nulla
        guard !Calendar.current.isDate(date, inSameDayAs: selectedDate) else { return }

        // Usa il debouncing per evitare caricamenti multipli
        debouncedNavigate(to: date)
    }

    public func navigateToNextPeriod() {
        let calendar = Calendar.current

        let nextDate: Date?
        switch viewMode {
        case .month:
            nextDate = calendar.date(byAdding: .month, value: 1, to: selectedDate)
        case .week:
            nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate)
        case .day:
            nextDate = calendar.date(byAdding: .day, value: 1, to: selectedDate)
        case .agenda, .year:
            nextDate = nil
        }

        if let nextDate = nextDate {
            debouncedNavigate(to: nextDate)
        }
    }

    public func navigateToPreviousPeriod() {
        let calendar = Calendar.current

        let previousDate: Date?
        switch viewMode {
        case .month:
            previousDate = calendar.date(byAdding: .month, value: -1, to: selectedDate)
        case .week:
            previousDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate)
        case .day:
            previousDate = calendar.date(byAdding: .day, value: -1, to: selectedDate)
        case .agenda, .year:
            previousDate = nil
        }

        if let previousDate = previousDate {
            debouncedNavigate(to: previousDate)
        }
    }

    public func navigateToToday() {
        let today = Date()

        // Se siamo già oggi, non fare nulla
        guard !Calendar.current.isDate(today, inSameDayAs: selectedDate) else { return }

        debouncedNavigate(to: today)
    }

    /// Pre-carica i dati per una data specifica in background
    private func preloadDataForDate(_ date: Date) async {
        // Calcola l'intervallo da pre-caricare basato sulla vista corrente
        let calendar = Calendar.current
        let startDate: Date
        let endDate: Date

        switch viewMode {
        case .month:
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
            startDate = calendar.date(byAdding: .day, value: -7, to: monthStart)! // Buffer di 7 giorni prima
            endDate = calendar.date(byAdding: .month, value: 1, to: monthStart)! // Fino alla fine del mese successivo
        case .week:
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
            startDate = calendar.date(byAdding: .day, value: -7, to: weekStart)! // Buffer di 7 giorni prima
            endDate = calendar.date(byAdding: .day, value: 14, to: weekStart)! // Settimana + buffer di 7 giorni dopo
        case .day:
            startDate = calendar.date(byAdding: .day, value: -1, to: date)! // Giorno prima
            endDate = calendar.date(byAdding: .day, value: 2, to: date)! // Giorno + giorno dopo
        case .agenda, .year:
            startDate = calendar.date(byAdding: .day, value: -7, to: date)!
            endDate = calendar.date(byAdding: .day, value: 30, to: date)!
        }

        // Carica i dati in background se non già caricati
        let dateRange = startDate...endDate
        if !isDateRangePreloaded(dateRange) {
            await loadEvents(from: startDate, to: endDate, forceRefresh: false)
        }
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
    
    /// Proprietà per tracciare se un evento è in modalità drag
    public var isDraggingEvent: Bool {
        if case .dragging = gestureState {
            return true
        }
        return false
    }

    /// Gestisce il drag di un evento esistente (con force touch)
    public func startEventDrag(eventId: String) {
        guard gesturePreferences.isEventDragEnabled else { return }

        gestureState = .dragging(eventId: eventId, offset: .zero)

        if gesturePreferences.hapticFeedbackEnabled {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred(intensity: 0.6)
        }
    }

    /// Annulla il drag di un evento
    public func cancelEventDrag() {
        gestureState = .idle
    }

    /// Proprietà per gestire la vista di dettaglio dell'evento
    @Published public var selectedEvent: NewCalendarEvent?
    @Published public var showingEventDetail = false

    /// Apre i dettagli di un evento
    public func openEventDetails(eventId: String) {
        guard let event = events.first(where: { $0.id == eventId }) else {
            print("Event not found: \(eventId)")
            return
        }

        selectedEvent = event
        showingEventDetail = true
    }

    /// Chiude la vista di dettaglio dell'evento
    public func closeEventDetail() {
        selectedEvent = nil
        showingEventDetail = false
    }

    /// Salva le modifiche all'evento
    public func saveEventChanges(_ updatedEvent: NewCalendarEvent) async throws {
        try await updateEvent(updatedEvent)
        closeEventDetail()
    }

    /// Elimina l'evento corrente
    public func deleteCurrentEvent() async throws {
        if let eventId = selectedEvent?.id {
            try await deleteEvent(eventId)
            closeEventDetail()
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

        // Refresh incrementale per l'intervallo attualmente visualizzato
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let endDate = Calendar.current.date(byAdding: .day, value: 14, to: now)!

        await loadEvents(from: startDate, to: endDate, forceRefresh: true)

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

    private func buildEvent(from candidate: FoundationModelEventCandidate, fallbackText: String, referenceDate: Date) -> NewCalendarEvent {
        let calendar = Calendar.current
        var start = candidate.startDate ?? referenceDate
        var isAllDay = candidate.isAllDay

        if isAllDay {
            start = calendar.startOfDay(for: start)
        }

        var end: Date
        if isAllDay {
            let startOfDay = calendar.startOfDay(for: start)
            end = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(86_400)
        } else if let specifiedEnd = candidate.endDate, specifiedEnd > start {
            end = specifiedEnd
        } else {
            let defaultEnd = calendar.date(byAdding: .hour, value: 1, to: start) ?? start.addingTimeInterval(3600)
            end = defaultEnd
            if let specifiedEnd = candidate.endDate, specifiedEnd <= start {
                isAllDay = false
            }
        }

        let cleanedTitle = candidate.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = (cleanedTitle?.isEmpty == false ? cleanedTitle : fallbackText).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? fallbackText

        let cleanedNotes = candidate.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedLocation = candidate.location?.trimmingCharacters(in: .whitespacesAndNewlines)
        let attendees = mapAttendees(candidate.attendees)

        let calendarId = defaultCalendarId()
        let color = defaultCalendarColor()

        return NewCalendarEvent(
            title: title.isEmpty ? fallbackText : title,
            notes: cleanedNotes?.isEmpty == true ? nil : cleanedNotes,
            startDate: isAllDay ? calendar.startOfDay(for: start) : start,
            endDate: isAllDay ? end : max(end, start.addingTimeInterval(900)),
            isAllDay: isAllDay,
            location: cleanedLocation?.isEmpty == true ? nil : cleanedLocation,
            attendees: attendees,
            calendarId: calendarId,
            color: color
        )
    }

    private func mapAttendees(_ rawValues: [String]) -> [Attendee] {
        rawValues.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            if let emailRangeStart = trimmed.firstIndex(of: "<"), let emailRangeEnd = trimmed.firstIndex(of: ">"), emailRangeStart < emailRangeEnd {
                let name = trimmed[..<emailRangeStart].trimmingCharacters(in: .whitespacesAndNewlines)
                let email = trimmed[trimmed.index(after: emailRangeStart)..<emailRangeEnd].trimmingCharacters(in: .whitespacesAndNewlines)
                return Attendee(name: name.isEmpty ? email : name, email: email)
            }

            if trimmed.contains("@") {
                return Attendee(name: trimmed, email: trimmed)
            }

            return Attendee(name: trimmed, email: "")
        }
    }

    private func defaultCalendarId() -> String? {
        calendars.first(where: { $0.isVisible })?.id ?? calendars.first?.id
    }

    private func defaultCalendarColor() -> Color {
        calendars.first(where: { $0.isVisible })?.uiColor ?? calendars.first?.uiColor ?? .blue
    }

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

    // MARK: - Overlap Detection Methods

    /// Verifica se un evento si sovrappone con altri eventi esistenti
    /// - Parameters:
    ///   - startDate: Data di inizio del nuovo/modificato evento
    ///   - endDate: Data di fine del nuovo/modificato evento
    ///   - excludeEventId: ID dell'evento da escludere dal controllo (utile per aggiornamenti)
    /// - Returns: Array di eventi che si sovrappongono
    public func findOverlappingEvents(
        startDate: Date,
        endDate: Date,
        excludeEventId: String? = nil
    ) -> [NewCalendarEvent] {
        return events.filter { event in
            // Escludi l'evento corrente se specificato
            if let excludeId = excludeEventId, event.id == excludeId {
                return false
            }

            // Due eventi si sovrappongono se:
            // - L'inizio del primo è prima della fine del secondo E
            // - La fine del primo è dopo l'inizio del secondo
            let overlaps = startDate < event.endDate && endDate > event.startDate
            return overlaps
        }
    }

    /// Verifica se un evento creerebbe una sovrapposizione
    /// - Parameters:
    ///   - startDate: Data di inizio del nuovo evento
    ///   - endDate: Data di fine del nuovo evento
    ///   - excludeEventId: ID dell'evento da escludere (opzionale)
    /// - Returns: true se c'è sovrapposizione, false altrimenti
    public func hasOverlap(
        startDate: Date,
        endDate: Date,
        excludeEventId: String? = nil
    ) -> Bool {
        return !findOverlappingEvents(
            startDate: startDate,
            endDate: endDate,
            excludeEventId: excludeEventId
        ).isEmpty
    }

    /// Trova tutti gli eventi che si sovrappongono nel periodo specificato
    /// - Parameters:
    ///   - startDate: Data di inizio del periodo
    ///   - endDate: Data di fine del periodo
    /// - Returns: Dizionario con evento come chiave e array di eventi sovrapposti come valore
    public func findAllOverlaps(
        from startDate: Date,
        to endDate: Date
    ) -> [String: [NewCalendarEvent]] {
        var overlaps: [String: [NewCalendarEvent]] = [:]

        // Filtra eventi nel periodo
        let eventsInRange = events.filter { event in
            event.startDate >= startDate && event.startDate <= endDate
        }

        // Per ogni evento, cerca sovrapposizioni
        for event in eventsInRange {
            let overlappingEvents = findOverlappingEvents(
                startDate: event.startDate,
                endDate: event.endDate,
                excludeEventId: event.id
            )

            if !overlappingEvents.isEmpty {
                overlaps[event.id] = overlappingEvents
            }
        }

        return overlaps
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
