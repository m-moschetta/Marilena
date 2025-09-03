//
//  NewWeekView.swift
//  Marilena
//
//  Created by AI Assistant
//  Copyright © 2024. All rights reserved.
//

import SwiftUI
import Combine

/// Vista settimanale elegante ispirata a Fantastical
public struct NewWeekView: View {
    @ObservedObject var calendarService: NewCalendarService
    @State private var currentTime = Date()
    @Environment(\.colorScheme) private var colorScheme

    private let calendar = Calendar.current
    private let hours = Array(0...23)
    private let hourHeight: CGFloat = 40

    // Timer per aggiornare l'indicatore dell'ora corrente
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // Sfondo con righe orarie
                    hourLinesBackground

                    // Timeline degli eventi
                    eventsTimeline

                    // Indicatore ora corrente
                    currentTimeIndicator
                }
                .frame(height: hourHeight * 24)
            }
            .onReceive(timer) { _ in
                currentTime = Date()
            }
            .onAppear {
                // Scroll all'ora corrente
                scrollToCurrentHour(proxy: proxy)
            }
        }
    }

    // MARK: - Hour Lines Background
    private var hourLinesBackground: some View {
        VStack(spacing: 0) {
            ForEach(hours, id: \.self) { hour in
                HStack(spacing: 0) {
                    // Etichetta ora
                    Text(hourLabel(for: hour))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 35, alignment: .trailing)
                        .padding(.trailing, 8)

                    // Linea orizzontale
                    Rectangle()
                        .fill(Color(.separator).opacity(0.3))
                        .frame(height: hour == 0 ? 2 : 1)
                }
                .frame(height: hourHeight, alignment: .top)
            }
        }
    }

    // MARK: - Events Timeline
    private var eventsTimeline: some View {
        let weekData = calendarService.weekData(for: calendarService.selectedDate)

        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Separatori verticali per i giorni
                daySeparators(width: geo.size.width)

                // Eventi per ogni giorno
                ForEach(weekData.days.indices, id: \.self) { dayIndex in
                    let day = weekData.days[dayIndex]
                    let dayX = dayXPosition(for: dayIndex, totalWidth: geo.size.width)

                    ForEach(day.events) { event in
                        WeekEventView(event: event, dayX: dayX, hourHeight: hourHeight)
                    }
                }
            }
        }
        .padding(.leading, 62) // Spazio per le etichette orarie
    }

    // MARK: - Day Separators
    private func daySeparators(width: CGFloat) -> some View {
        let dayWidth = (width - 62) / 7

        return ZStack {
            ForEach(0..<7, id: \.self) { dayIndex in
                let x = dayXPosition(for: dayIndex, totalWidth: width)

                VStack(spacing: 0) {
                    // Header del giorno
                    dayHeader(for: dayIndex, width: dayWidth)
                        .offset(y: -40)

                    // Separatore verticale
                    Rectangle()
                        .fill(Color(.separator).opacity(0.5))
                        .frame(width: 1)
                        .offset(x: x)
                }
            }
        }
    }

    // MARK: - Day Header
    private func dayHeader(for dayIndex: Int, width: CGFloat) -> some View {
        let weekData = calendarService.weekData(for: calendarService.selectedDate)
        let day = weekData.days[dayIndex]

        return VStack(spacing: 2) {
            Text(calendarService.weekdayName(for: day.date).prefix(3))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            Text(calendarService.dayNumber(for: day.date))
                .font(.system(size: 16, weight: day.isToday ? .bold : .regular))
                .foregroundColor(day.isToday ? .blue : .primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(day.isToday ? Color.blue.opacity(0.1) : Color.clear)
                )
        }
        .frame(width: width, height: 30)
    }

    // MARK: - Current Time Indicator
    private var currentTimeIndicator: some View {
        let calendar = Calendar.current
        let now = Date()

        // Verifica se oggi è nella settimana corrente
        let weekData = calendarService.weekData(for: calendarService.selectedDate)
        guard weekData.days.contains(where: { calendar.isDate($0.date, inSameDayAs: now) }) else {
            return AnyView(EmptyView())
        }

        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let y = (CGFloat(hour) + CGFloat(minute) / 60.0) * hourHeight

        return AnyView(
            HStack(spacing: 0) {
                // Indicatore circolare
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 4, height: 4)
                }
                .offset(x: -4, y: -4)

                // Linea orizzontale
                Rectangle()
                    .fill(Color.red)
                    .frame(height: 1)
            }
            .offset(y: y)
        )
    }

    // MARK: - Helper Methods

    private func hourLabel(for hour: Int) -> String {
        if hour == 0 {
            return "12 AM"
        } else if hour < 12 {
            return "\(hour) AM"
        } else if hour == 12 {
            return "12 PM"
        } else {
            return "\(hour - 12) PM"
        }
    }

    private func dayXPosition(for dayIndex: Int, totalWidth: CGFloat) -> CGFloat {
        let availableWidth = totalWidth - 62
        let dayWidth = availableWidth / 7
        return CGFloat(dayIndex) * dayWidth + dayWidth / 2
    }

    private func scrollToCurrentHour(proxy: ScrollViewProxy) {
        let hour = calendar.component(.hour, from: currentTime)
        let targetY = CGFloat(max(0, hour - 2)) * hourHeight

        withAnimation(.easeInOut(duration: 0.5)) {
            proxy.scrollTo(hour, anchor: .top)
        }
    }
}

// MARK: - Week Event View
private struct WeekEventView: View {
    let event: NewCalendarEvent
    let dayX: CGFloat
    let hourHeight: CGFloat

    var body: some View {
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: event.startDate)
        let startMinute = calendar.component(.minute, from: event.startDate)
        let duration = event.endDate.timeIntervalSince(event.startDate) / 3600

        let y = (CGFloat(startHour) + CGFloat(startMinute) / 60.0) * hourHeight
        let height = max(duration * hourHeight, 24)

        return VStack(alignment: .leading, spacing: 0) {
            // Titolo evento
            Text(event.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)

            // Orario se l'evento è abbastanza alto
            if height > 40 {
                Text(event.formattedTimeRange)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 6)
                    .padding(.bottom, 4)
            }
        }
        .frame(width: 80, height: height, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(event.uiColor.opacity(0.9))
        )
        .position(x: dayX, y: y + height / 2)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Preview
struct NewWeekView_Previews: PreviewProvider {
    static var previews: some View {
        let service = NewCalendarService(calendarManager: CalendarManager())
        NewWeekView(calendarService: service)
            .previewLayout(.sizeThatFits)
    }
}
