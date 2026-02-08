//
//  NewAgendaView.swift
//  Marilena
//
//  Created by AI Assistant
//  Copyright © 2024. All rights reserved.
//

import SwiftUI

/// Vista agenda intelligente ispirata a Fantastical
public struct NewAgendaView: View {
    @ObservedObject var calendarService: NewCalendarService
    @State private var selectedDate: Date?
    @Environment(\.colorScheme) private var colorScheme

    private let calendar = Calendar.current

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header agenda
                agendaHeader

                // Lista eventi per data
                agendaList
            }
        }
        .refreshable {
            await calendarService.handlePullToRefresh()
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    let horizontalAmount = value.translation.width
                    let verticalAmount = value.translation.height
                    
                    // Solo se il movimento è principalmente orizzontale
                    if abs(horizontalAmount) > abs(verticalAmount) && abs(horizontalAmount) > 50 {
                        if horizontalAmount > 0 {
                            // Swipe verso destra
                            calendarService.handleHorizontalSwipe(.right)
                        } else {
                            // Swipe verso sinistra
                            calendarService.handleHorizontalSwipe(.left)
                        }
                    }
                }
        )
    }

    // MARK: - Agenda Header
    private var agendaHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Agenda")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                // Contatore eventi oggi
                if let todayEvents = todayEventsCount() {
                    Text("\(todayEvents) today")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5).opacity(0.5))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Divider()
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Agenda List
    private var agendaList: some View {
        let agendaData = calendarService.agendaEvents(from: Date())

        return LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
            if agendaData.isEmpty {
                emptyStateView
            } else {
                ForEach(agendaData.keys.sorted(), id: \.self) { date in
                    if let events = agendaData[date], !events.isEmpty {
                        Section(header: dateHeader(for: date)) {
                            ForEach(events) { event in
                                AgendaEventRow(event: event)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Date Header
    private func dateHeader(for date: Date) -> some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dateHeaderTitle(for: date))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(dateHeaderSubtitle(for: date))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Indicatore oggi
                if calendar.isDate(date, inSameDayAs: Date()) {
                    Text("Today")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Rectangle()
                .fill(Color(.separator))
                .frame(height: 1)
                .padding(.horizontal, 20)
        }
        .background(
            (colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No upcoming events")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)

            Text("Your schedule is clear for the coming weeks")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    // MARK: - Helper Methods

    private func dateHeaderTitle(for date: Date) -> String {
        if calendar.isDate(date, inSameDayAs: Date()) {
            return "Today"
        } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: Date())!) {
            return "Tomorrow"
        } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: Date())!) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        }
    }

    private func dateHeaderSubtitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }

    private func todayEventsCount() -> Int? {
        let todayEvents = calendarService.eventsForDate(Date())
        return todayEvents.isEmpty ? nil : todayEvents.count
    }
}

// MARK: - Agenda Event Row
private struct AgendaEventRow: View {
    let event: NewCalendarEvent
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Indicatore colore
            RoundedRectangle(cornerRadius: 2)
                .fill(event.uiColor)
                .frame(width: 4, height: 50)

            // Contenuto evento
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(event.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Spacer()

                    // Orario
                    Text(event.formattedTimeRange)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                // Location
                if let location = event.location {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        Text(location)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                // Attendees
                if !event.attendees.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        Text("\(event.attendees.count) attendee\(event.attendees.count == 1 ? "" : "s")")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview
struct NewAgendaView_Previews: PreviewProvider {
    static var previews: some View {
        let service = NewCalendarService(calendarManager: CalendarManager())
        NewAgendaView(calendarService: service)
            .previewLayout(.sizeThatFits)
    }
}
