//
//  EventListRow.swift
//  Marilena
//
//  Created by AI Assistant
//  Copyright © 2024. All rights reserved.
//

import SwiftUI

struct EventListRow: View {
    let event: CalendarEvent
    @ObservedObject var calendarManager: CalendarManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Time indicator
            VStack(alignment: .leading, spacing: 2) {
                Text(timeString(event.startDate))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.red)
                
                if !event.isAllDay {
                    Text(duration)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 50, alignment: .leading)
            
            // Event content
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                
                if let location = event.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                        Text(location)
                            .font(.caption)
                        Spacer()
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Completion toggle
            Button(action: {
                let wasCompleted = calendarManager.isCompleted(event)
                if wasCompleted { Haptics.selection() } else { Haptics.success() }
                calendarManager.toggleCompleted(event)
            }) {
                Image(systemName: calendarManager.isCompleted(event) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(calendarManager.isCompleted(event) ? .green : colorFor(event: event))
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
        )
    }
    
    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = event.isAllDay ? "MMM d" : "HH:mm"
        return formatter.string(from: date)
    }
    
    private var duration: String {
        if event.isAllDay { return "All day" }
        
        let interval = event.endDate.timeIntervalSince(event.startDate)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func colorFor(event: CalendarEvent) -> Color {
        if let calId = event.calendarId,
           let cal = calendarManager.calendars.first(where: { $0.id == calId }) {
            if let color = Color(hex: cal.color) {
                return color
            }
        }
        
        // Fallback colors
        switch event.providerType {
        case .eventKit: return Color.red
        case .googleCalendar: return Color(red: 0.13, green: 0.52, blue: 0.96)
        case .microsoftGraph: return Color(red: 0.0, green: 0.46, blue: 0.85)
        }
    }
}

// MARK: - Reminder List Row

struct ReminderListRow: View {
    let reminder: CalendarReminder
    @ObservedObject var calendarManager: CalendarManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Time indicator
            VStack(alignment: .leading, spacing: 2) {
                if let dueDate = reminder.dueDate {
                    Text(timeString(dueDate))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(reminder.statusColor)
                } else {
                    Text("--:--")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                
                Text(reminder.priority.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 50, alignment: .leading)
            
            // Reminder content
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .strikethrough(reminder.isCompleted)
                
                if let location = reminder.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                        Text(location)
                            .font(.caption)
                        Spacer()
                    }
                    .foregroundColor(.secondary)
                }
                
                if reminder.isOverdue {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("In ritardo")
                            .font(.caption)
                        Spacer()
                    }
                    .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            // Completion toggle
            Button(action: {
                let wasCompleted = reminder.isCompleted
                if wasCompleted { Haptics.selection() } else { Haptics.success() }
                calendarManager.toggleCompleted(reminder)
            }) {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(reminder.isCompleted ? .green : reminder.statusColor)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            
            // Type indicator
            Image(systemName: "checklist")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(reminder.statusColor.opacity(0.05))
                .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
        )
    }
    
    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct EventListRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            EventListRow(
                event: CalendarEvent(
                    id: "1",
                    title: "Team Meeting",
                    description: "Weekly standup",
                    startDate: Date(),
                    endDate: Date().addingTimeInterval(3600),
                    location: "Conference Room A",
                    isAllDay: false,
                    recurrenceRule: nil,
                    attendees: [],
                    calendarId: nil,
                    url: nil,
                    providerId: "1",
                    providerType: .eventKit,
                    lastModified: Date()
                ),
                calendarManager: CalendarManager()
            )
            
            ReminderListRow(
                reminder: CalendarReminder(
                    title: "Comprare il latte",
                    notes: "Non dimenticare",
                    dueDate: Date().addingTimeInterval(3600),
                    priority: .high,
                    isCompleted: false,
                    list: "Casa"
                ),
                calendarManager: CalendarManager()
            )
        }
        .padding()
    }
}