//
//  ReminderService.swift
//  Marilena
//
//  Service per la gestione dei reminder
//

import Foundation
import Combine

/// Service per gestire i reminder dell'utente
public class ReminderService: ObservableObject {
    public static let shared = ReminderService()
    
    @Published public var reminders: [CalendarReminder] = []
    
    private init() {}
    
    /// Carica i reminder
    public func loadReminders() async {
        // Implementazione placeholder
    }
    
    /// Carica i reminder per un periodo
    public func loadReminders(from startDate: Date, to endDate: Date) async {
        // Implementazione placeholder
    }
    
    /// Completa un reminder
    public func completeReminder(_ reminder: CalendarReminder) {
        if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[index].isCompleted = true
        }
    }
    
    /// Toggle stato completamento
    public func toggleCompleted(_ reminder: CalendarReminder) async {
        if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[index].isCompleted.toggle()
        }
    }
    
    /// Elimina un reminder
    public func deleteReminder(_ reminder: CalendarReminder) async {
        reminders.removeAll { $0.id == reminder.id }
    }
    
    /// Restituisce i reminder per una data specifica
    public func remindersForDate(_ date: Date) -> [CalendarReminder] {
        let calendar = Calendar.current
        return reminders.filter { reminder in
            guard let dueDate = reminder.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: date)
        }
    }
    
    /// Crea un nuovo reminder
    public func createReminder(
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        priority: ReminderPriority = .none
    ) -> CalendarReminder {
        let reminder = CalendarReminder(
            title: title,
            notes: notes,
            dueDate: dueDate,
            priority: priority
        )
        reminders.append(reminder)
        return reminder
    }
    
    /// Aggiunge un item al backlog
    public func addToBacklog(title: String, notes: String? = nil, priority: ReminderPriority = .none) async -> String {
        let reminder = createReminder(title: title, notes: notes, priority: priority)
        return reminder.id
    }
    
    /// Completa un item del backlog
    public func completeBacklogItem(reminderId: String) async {
        if let index = reminders.firstIndex(where: { $0.id == reminderId }) {
            reminders[index].isCompleted = true
        }
    }
    
    /// Carica gli item del backlog
    public func loadBacklogItems() async {
        // Implementazione placeholder - i reminder sono già in memoria
    }
    
    /// Restituisce gli item del backlog (non completati)
    public func getBacklogItems() -> [CalendarReminder] {
        return reminders.filter { !$0.isCompleted }
    }
}
