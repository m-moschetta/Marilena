//
//  NewDayView.swift
//  Marilena
//
//  Created by AI Assistant
//  Copyright © 2024. All rights reserved.
//

import SwiftUI
import Combine

/// Vista giornaliera dettagliata ispirata a Fantastical
public struct NewDayView: View {
    @ObservedObject var calendarService: NewCalendarService
    @State private var currentTime = Date()
    @Environment(\.colorScheme) private var colorScheme

    private let calendar = Calendar.current
    private let hours = Array(0...23)
    private let hourHeight: CGFloat = 50

    // Timer per aggiornare l'indicatore dell'ora corrente
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header del giorno
                    dayHeader

                    // Timeline giornaliera
                    ZStack(alignment: .topLeading) {
                        // Sfondo con righe orarie
                        hourLinesBackground

                        // Eventi del giorno
                        dayEvents

                        // Indicatore ora corrente
                        currentTimeIndicator
                    }
                    .frame(height: hourHeight * 24)
                }
            }
            .onReceive(timer) { _ in
                currentTime = Date()
            }
            .onAppear {
                scrollToCurrentHour(proxy: proxy)
            }
        }
    }

    // MARK: - Day Header
    private var dayHeader: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(calendarService.weekdayName(for: calendarService.selectedDate))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)

                    Text("\(calendarService.monthTitle(for: calendarService.selectedDate)) \(calendarService.dayNumber(for: calendarService.selectedDate))")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Indicatore "oggi" se è oggi
                if calendar.isDate(calendarService.selectedDate, inSameDayAs: Date()) {
                    Text("Today")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Divider()
        }
    }

    // MARK: - Hour Lines Background
    private var hourLinesBackground: some View {
        VStack(spacing: 0) {
            ForEach(hours, id: \.self) { hour in
                HStack(spacing: 0) {
                    // Etichetta ora
                    Text(hourLabel(for: hour))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 45, alignment: .trailing)
                        .padding(.trailing, 8)

                    // Linea orizzontale
                    Rectangle()
                        .fill(Color(.separator).opacity(hour == 0 ? 0.6 : 0.3))
                        .frame(height: hour == 0 ? 2 : 1)

                    Spacer()
                }
                .frame(height: hourHeight, alignment: .top)
                .id(hour)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Day Events
    private var dayEvents: some View {
        let events = calendarService.dayData(for: calendarService.selectedDate)

        return ZStack(alignment: .topLeading) {
            ForEach(events.indices, id: \.self) { index in
                let event = events[index]
                DayEventView(event: event, hourHeight: hourHeight)
            }
        }
        .padding(.horizontal, 96) // Spazio per etichette ora + margine
    }

    // MARK: - Current Time Indicator
    private var currentTimeIndicator: some View {
        // Solo se è oggi
        guard calendar.isDate(calendarService.selectedDate, inSameDayAs: Date()) else {
            return AnyView(EmptyView())
        }

        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)
        let y = (CGFloat(hour) + CGFloat(minute) / 60.0) * hourHeight + 20 // +20 per header

        return AnyView(
            HStack(spacing: 0) {
                // Indicatore circolare
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                }
                .offset(x: 76, y: -5) // Posizionato accanto all'etichetta ora

                // Linea orizzontale
                Rectangle()
                    .fill(Color.red)
                    .frame(height: 2)
                    .padding(.leading, 96)
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

    private func scrollToCurrentHour(proxy: ScrollViewProxy) {
        let hour = calendar.component(.hour, from: currentTime)
        let targetHour = max(0, hour - 2) // Mostra 2 ore prima

        withAnimation(.easeInOut(duration: 0.5)) {
            proxy.scrollTo(targetHour, anchor: .top)
        }
    }
}

// MARK: - Day Event View
private struct DayEventView: View {
    let event: NewCalendarEvent
    let hourHeight: CGFloat

    var body: some View {
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: event.startDate)
        let startMinute = calendar.component(.minute, from: event.startDate)
        let duration = event.endDate.timeIntervalSince(event.startDate) / 3600

        let y = (CGFloat(startHour) + CGFloat(startMinute) / 60.0) * hourHeight
        let height = max(duration * hourHeight, 32)

        return VStack(alignment: .leading, spacing: 4) {
            // Titolo
            Text(event.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            // Orario
            Text(event.formattedTimeRange)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))

            // Location se presente e spazio sufficiente
            if let location = event.location, height > 60 {
                Text(location)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: height, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(event.uiColor.opacity(0.9))
                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .offset(y: y)
        .padding(.horizontal, 4)
    }
}

// MARK: - Preview
struct NewDayView_Previews: PreviewProvider {
    static var previews: some View {
        let service = NewCalendarService(calendarManager: CalendarManager())
        NewDayView(calendarService: service)
            .previewLayout(.sizeThatFits)
    }
}
