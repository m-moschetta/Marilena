//
//  ReminderService.swift
//  Marilena
//
//  Created by AI Assistant
//  Copyright © 2024. All rights reserved.
//

import Foundation
import EventKit
import SwiftUI
import Combine

@MainActor
public class ReminderService: ObservableObject {
    @Published public var reminders: [CalendarReminder] = []
    @Published public var isLoading: Bool = false
    @Published public var error: String?
    
    private let eventStore = EKEventStore()
    
    public static let shared = ReminderService()
    
    private init() {}
    
    // MARK: - Authorization
    
    public func requestAccess() async -> Bool {
        do {
            return try await eventStore.requestFullAccessToReminders()
        } catch {
            self.error = "Errore accesso promemoria: \(error.localizedDescription)"
            return false
        }
    }
    
    public var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .reminder)
    }
    
    // MARK: - Loading Reminders
    
    public func loadReminders(from startDate: Date? = nil, to endDate: Date? = nil) async {
        guard authorizationStatus == .fullAccess else {
            let accessGranted = await requestAccess()
            guard accessGranted else {
                return
            }
            // Se l'accesso è stato concesso, continuiamo con l'esecuzione
            // ma dobbiamo uscire da questo guard
            return await loadReminders(from: startDate, to: endDate)
        }
        
        isLoading = true
        error = nil
        
        do {
            let calendars = eventStore.calendars(for: .reminder)
            let predicate = eventStore.predicateForReminders(in: calendars)
            
            let ekReminders = try await withCheckedThrowingContinuation { continuation in
                eventStore.fetchReminders(matching: predicate) { reminders in
                    if let reminders = reminders {
                        continuation.resume(returning: reminders)
                    } else {
                        continuation.resume(throwing: NSError(domain: "ReminderService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch reminders"]))
                    }
                }
            }
            
            let calendarReminders = ekReminders.map { CalendarReminder(from: $0) }
            
            // Filtra per date se specificate
            let filteredReminders: [CalendarReminder]
            if let startDate = startDate, let endDate = endDate {
                filteredReminders = calendarReminders.filter { reminder in
                    guard let dueDate = reminder.dueDate else {
                        // Include promemoria senza data di scadenza se sono stati creati nel periodo
                        return reminder.creationDate >= startDate && reminder.creationDate <= endDate
                    }
                    return dueDate >= startDate && dueDate <= endDate
                }
            } else {
                filteredReminders = calendarReminders
            }
            
            reminders = filteredReminders.sorted { 
                ($0.dueDate ?? $0.creationDate) < ($1.dueDate ?? $1.creationDate) 
            }
            
        } catch {
            self.error = "Errore caricamento promemoria: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Reminder Operations
    
    public func toggleCompleted(_ reminder: CalendarReminder) async {
        guard let ekReminder = try? await eventStore.calendarItem(withIdentifier: reminder.id) as? EKReminder else {
            error = "Promemoria non trovato"
            return
        }
        
        ekReminder.isCompleted = !ekReminder.isCompleted
        ekReminder.completionDate = ekReminder.isCompleted ? Date() : nil
        
        do {
            try eventStore.save(ekReminder, commit: true)
            
            // Aggiorna l'array locale
            if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
                var updatedReminder = reminders[index]
                updatedReminder.isCompleted = ekReminder.isCompleted
                updatedReminder.completionDate = ekReminder.completionDate
                reminders[index] = updatedReminder
            }
            
        } catch {
            self.error = "Errore aggiornamento promemoria: \(error.localizedDescription)"
        }
    }
    
    public func createReminder(title: String, notes: String? = nil, dueDate: Date? = nil, priority: ReminderPriority = .medium) async {
        guard authorizationStatus == .fullAccess else {
            error = "Accesso ai promemoria negato"
            return
        }
        
        let ekReminder = EKReminder(eventStore: eventStore)
        ekReminder.title = title
        ekReminder.notes = notes
        ekReminder.priority = priority.rawValue
        
        if let dueDate = dueDate {
            ekReminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        }
        
        // Usa il calendario predefinito per i promemoria
        if let defaultCalendar = eventStore.defaultCalendarForNewReminders() {
            ekReminder.calendar = defaultCalendar
        }
        
        do {
            try eventStore.save(ekReminder, commit: true)
            
            // Aggiungi alla lista locale
            let newReminder = CalendarReminder(from: ekReminder)
            reminders.append(newReminder)
            reminders.sort { ($0.dueDate ?? $0.creationDate) < ($1.dueDate ?? $1.creationDate) }
            
        } catch {
            self.error = "Errore creazione promemoria: \(error.localizedDescription)"
        }
    }
    
    public func deleteReminder(_ reminder: CalendarReminder) async {
        guard let ekReminder = try? await eventStore.calendarItem(withIdentifier: reminder.id) as? EKReminder else {
            error = "Promemoria non trovato"
            return
        }
        
        do {
            try eventStore.remove(ekReminder, commit: true)
            
            // Rimuovi dalla lista locale
            reminders.removeAll { $0.id == reminder.id }
            
        } catch {
            self.error = "Errore eliminazione promemoria: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Helper Methods
    
    public func reminders(for date: Date) -> [CalendarReminder] {
        let calendar = Calendar.current
        return reminders.filter { reminder in
            if let dueDate = reminder.dueDate {
                return calendar.isDate(dueDate, inSameDayAs: date)
            } else {
                return calendar.isDate(reminder.creationDate, inSameDayAs: date)
            }
        }
    }
    
    public func upcomingReminders(limit: Int = 10) -> [CalendarReminder] {
        let now = Date()
        return reminders
            .filter { !$0.isCompleted && ($0.dueDate ?? $0.creationDate) >= now }
            .prefix(limit)
            .map { $0 }
    }
    
    public func overdueReminders() -> [CalendarReminder] {
        return reminders.filter { $0.isOverdue }
    }
}