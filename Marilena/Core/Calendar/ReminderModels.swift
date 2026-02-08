//
//  ReminderModels.swift
//  Marilena
//
//  Modelli per i reminder del calendario
//

import Foundation

/// Rappresenta un reminder/promemoria nel calendario
public struct CalendarReminder: Identifiable, Codable {
    public let id: String
    public var title: String
    public var notes: String?
    public var dueDate: Date?
    public var priority: ReminderPriority
    public var isCompleted: Bool
    public var listId: String?
    public var listName: String?
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        priority: ReminderPriority = .none,
        isCompleted: Bool = false,
        listId: String? = nil,
        listName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.priority = priority
        self.isCompleted = isCompleted
        self.listId = listId
        self.listName = listName
    }
    
    /// Indica se il reminder è scaduto
    public var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return dueDate < Date() && !isCompleted
    }
    
    /// Nome della lista (alias per listName)
    public var list: String? {
        get { listName }
        set { listName = newValue }
    }
}

/// Priorità di un reminder
public enum ReminderPriority: Int, Codable {
    case none = 0
    case low = 1
    case medium = 5
    case high = 9
    
    public var displayName: String {
        switch self {
        case .none: return "Nessuna"
        case .low: return "Bassa"
        case .medium: return "Media"
        case .high: return "Alta"
        }
    }
}
