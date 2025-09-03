//
//  ReminderModels.swift
//  Marilena
//
//  Created by AI Assistant
//  Copyright © 2024. All rights reserved.
//

import Foundation
import EventKit
import SwiftUI

// MARK: - Reminder Model

/// Modello unificato per promemoria che possono essere visualizzati insieme agli eventi del calendario
public struct CalendarReminder: Identifiable, Hashable {
    public let id: String
    public var title: String
    public var notes: String?
    public var dueDate: Date?
    public var priority: ReminderPriority
    public var isCompleted: Bool
    public var completionDate: Date?
    public var list: String? // Nome della lista di promemoria
    public var url: URL?
    public var location: String?
    public var creationDate: Date
    public var lastModified: Date
    
    // Proprietà per integrazione con calendario
    public var displayDate: Date {
        dueDate ?? creationDate
    }
    
    public var isOverdue: Bool {
        guard let dueDate = dueDate, !isCompleted else { return false }
        return dueDate < Date()
    }
    
    public var statusColor: Color {
        if isCompleted {
            return .green
        } else if isOverdue {
            return .red
        } else if priority == .high {
            return .orange
        } else {
            return .blue
        }
    }
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        priority: ReminderPriority = .medium,
        isCompleted: Bool = false,
        completionDate: Date? = nil,
        list: String? = nil,
        url: URL? = nil,
        location: String? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.priority = priority
        self.isCompleted = isCompleted
        self.completionDate = completionDate
        self.list = list
        self.url = url
        self.location = location
        self.creationDate = Date()
        self.lastModified = Date()
    }
    
    // Inizializzatore da EKReminder
    public init(from ekReminder: EKReminder) {
        self.id = ekReminder.calendarItemIdentifier
        self.title = ekReminder.title ?? "Promemoria senza titolo"
        self.notes = ekReminder.notes
        self.dueDate = ekReminder.dueDateComponents?.date
        self.priority = ReminderPriority(from: ekReminder.priority)
        self.isCompleted = ekReminder.isCompleted
        self.completionDate = ekReminder.completionDate
        self.list = ekReminder.calendar?.title
        self.url = ekReminder.url
        self.location = ekReminder.location
        self.creationDate = ekReminder.creationDate ?? Date()
        self.lastModified = ekReminder.lastModifiedDate ?? Date()
    }
}

// MARK: - Supporting Types

public enum ReminderPriority: Int, CaseIterable {
    case none = 0
    case low = 1
    case medium = 5
    case high = 9
    
    var displayName: String {
        switch self {
        case .none: return "Nessuna"
        case .low: return "Bassa"
        case .medium: return "Media"
        case .high: return "Alta"
        }
    }
    
    var color: Color {
        switch self {
        case .none: return .gray
        case .low: return .green
        case .medium: return .blue
        case .high: return .red
        }
    }
    
    init(from ekPriority: Int) {
        switch ekPriority {
        case 1...3: self = .low
        case 4...6: self = .medium
        case 7...9: self = .high
        default: self = .none
        }
    }
}

// MARK: - Calendar Item Types

public enum CalendarItemType {
    case event
    case reminder
    
    var icon: String {
        switch self {
        case .event: return "calendar"
        case .reminder: return "checklist"
        }
    }
}