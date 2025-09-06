//
//  NewMonthView.swift
//  Marilena
//
//  Created by AI Assistant
//  Copyright © 2024. All rights reserved.
//

import SwiftUI

/// Vista mensile elegante ispirata a Fantastical
public struct NewMonthView: View {
    @ObservedObject var calendarService: NewCalendarService
    @Environment(\.colorScheme) private var colorScheme

    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header con giorni della settimana
                weekdayHeader

                // Grid del mese
                monthGrid

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)
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
                            // Swipe verso destra - mese precedente
                            calendarService.handleHorizontalSwipe(.right)
                        } else {
                            // Swipe verso sinistra - mese successivo
                            calendarService.handleHorizontalSwipe(.left)
                        }
                    }
                }
        )
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    calendarService.handleViewModePinchGesture(scale: value)
                }
                .onEnded { _ in
                    calendarService.completePinchGesture()
                }
        )
    }

    // MARK: - Weekday Header
    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(daysOfWeek, id: \.self) { day in
                Text(day)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Month Grid
    private var monthGrid: some View {
        let monthData = calendarService.monthData(for: calendarService.selectedDate)

        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
            spacing: 0
        ) {
            ForEach(monthData.weeks.flatMap { $0.days }) { day in
                MonthDayCell(day: day, calendarService: calendarService)
                    .frame(height: 60)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        calendarService.selectDate(day.date)
                    }
                    .onTapGesture(count: 2) {
                        calendarService.handleDoubleTap(at: day.date)
                        // Potremmo aprire qui un sheet per creare evento veloce
                    }
            }
        }
    }
}

// MARK: - Month Day Cell
private struct MonthDayCell: View {
    let day: NewCalendarDay
    @ObservedObject var calendarService: NewCalendarService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Numero del giorno
            Text(calendarService.dayNumber(for: day.date))
                .font(.system(size: 13, weight: day.isToday ? .bold : .regular))
                .foregroundColor(dayTextColor)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(dayBackground)
                .clipShape(Circle())

            // Eventi del giorno (punti colorati come Fantastical)
            if !day.events.isEmpty {
                EventsDots(events: day.events)
                    .padding(.horizontal, 4)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(day.isSelected ? Color.blue.opacity(0.1) : Color.clear)
                .padding(.horizontal, 2)
                .padding(.vertical, 1)
        )
    }

    private var dayTextColor: Color {
        let calendar = Calendar.current
        if day.isToday {
            return .white
        } else if calendar.component(.month, from: day.date) != calendar.component(.month, from: calendarService.selectedDate) {
            return .secondary.opacity(0.5)
        } else {
            return .primary
        }
    }

    private var dayBackground: Color {
        if day.isToday {
            return .blue
        } else {
            return .clear
        }
    }
}

// MARK: - Events Dots
private struct EventsDots: View {
    let events: [NewCalendarEvent]
    private let maxDots = 4

    var body: some View {
        HStack(spacing: 2) {
            ForEach(events.prefix(maxDots)) { event in
                Circle()
                    .fill(event.uiColor.opacity(0.8))
                    .frame(width: 6, height: 6)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                    )
            }

            if events.count > maxDots {
                Text("+\(events.count - maxDots)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview
struct NewMonthView_Previews: PreviewProvider {
    static var previews: some View {
        let service = NewCalendarService(calendarManager: CalendarManager())
        NewMonthView(calendarService: service)
            .previewLayout(.sizeThatFits)
    }
}
