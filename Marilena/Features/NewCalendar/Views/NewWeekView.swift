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
            VStack(spacing: 0) {
                // Header fisso con giorni della settimana
                weekDaysHeader
                
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
            }
            .refreshable {
                await calendarService.handlePullToRefresh()
            }
            .onReceive(timer) { _ in
                currentTime = Date()
            }
            .onAppear {
                // Scroll all'ora corrente
                scrollToCurrentHour(proxy: proxy)
            }
            .gesture(
                DragGesture()
                    .onEnded { value in
                        let horizontalAmount = value.translation.width
                        let verticalAmount = value.translation.height
                        
                        // Solo se il movimento è principalmente orizzontale
                        if abs(horizontalAmount) > abs(verticalAmount) && abs(horizontalAmount) > 50 {
                            if horizontalAmount > 0 {
                                // Swipe verso destra - settimana precedente
                                calendarService.handleHorizontalSwipe(.right)
                            } else {
                                // Swipe verso sinistra - settimana successiva
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
            .sheet(isPresented: $calendarService.showingEventDetail) {
                // Sheet per dettagli/modifica evento
                if let event = calendarService.selectedEvent {
                    EventDetailView(calendarService: calendarService)
                }
            }
        }
    }
    
    // MARK: - Week Days Header
    private var weekDaysHeader: some View {
        let weekData = calendarService.weekData(for: calendarService.selectedDate)

        return HStack(spacing: 0) {
            // Spazio per allineare con le etichette delle ore
            Spacer()
                .frame(width: 50)

            // Header giorni della settimana
            ForEach(weekData.days.indices, id: \.self) { dayIndex in
                let day = weekData.days[dayIndex]

                VStack(spacing: 4) {
                    Text(calendarService.weekdayName(for: day.date).prefix(3))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    Text(calendarService.dayNumber(for: day.date))
                        .font(.system(size: 18, weight: day.isToday ? .bold : .semibold))
                        .foregroundColor(day.isToday ? .white : .primary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(day.isToday ? Color.blue : Color.clear)
                        )
                        .overlay(
                            Circle()
                                .stroke(day.isSelected ? Color.blue : Color.clear, lineWidth: 2)
                        )
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    calendarService.selectDate(day.date)
                }
            }
        }
        .padding(.vertical, 12)
        .background(
            Color(.systemGray6)
                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        )
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
                        .frame(width: 42, alignment: .trailing)
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

        return VStack(spacing: 0) {
            // Sezione eventi tutto il giorno
            allDayEventsSection(weekData: weekData)
                .padding(.leading, 50)

            // Timeline eventi con orario
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    // Separatori verticali per i giorni
                    daySeparators(width: geo.size.width)

                    // Eventi con orario per ogni giorno
                    ForEach(weekData.days.indices, id: \.self) { dayIndex in
                        let day = weekData.days[dayIndex]
                        let dayWidth = (geo.size.width - 50) / 7
                        let dayX = CGFloat(dayIndex) * dayWidth
                        let timedEvents = day.events.filter { !$0.isAllDay }

                        ForEach(timedEvents) { event in
                            WeekEventView(event: event, dayX: dayX, dayWidth: dayWidth, hourHeight: hourHeight, calendarService: calendarService)
                        }
                    }
                }
            }
            .padding(.leading, 50)
        }
    }

    // MARK: - All Day Events Section
    private func allDayEventsSection(weekData: NewCalendarWeek) -> some View {
        let hasAllDayEvents = weekData.days.contains { day in
            day.events.contains { $0.isAllDay }
        }

        return Group {
            if hasAllDayEvents {
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        ForEach(weekData.days.indices, id: \.self) { dayIndex in
                            let day = weekData.days[dayIndex]
                            let allDayEvents = day.events.filter { $0.isAllDay }

                            VStack(spacing: 2) {
                                ForEach(allDayEvents) { event in
                                    Text(event.title)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(event.uiColor.opacity(0.9))
                                        )
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .frame(height: 40)
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Day Separators
    private func daySeparators(width: CGFloat) -> some View {
        let dayWidth = (width - 50) / 7

        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { dayIndex in
                Rectangle()
                    .fill(Color(.separator).opacity(0.2))
                    .frame(width: dayIndex < 6 ? 1 : 0)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
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
        let availableWidth = totalWidth - 50
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
    let dayWidth: CGFloat
    let hourHeight: CGFloat
    @ObservedObject var calendarService: NewCalendarService
    @State private var dragOffset = CGSize.zero

    var body: some View {
        timedEventContent
    }

    private var timedEventContent: some View {
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: event.startDate)
        let startMinute = calendar.component(.minute, from: event.startDate)
        let duration = event.endDate.timeIntervalSince(event.startDate) / 3600

        let y = (CGFloat(startHour) + CGFloat(startMinute) / 60.0) * hourHeight
        let height = max(duration * hourHeight, 24)
        let eventWidth = dayWidth * 0.9

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
        .frame(width: eventWidth, height: height, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(event.uiColor.opacity(event.displayOpacity() * 0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.3), lineWidth: dragOffset != .zero ? 2 : 0)
                )
        )
        .offset(x: dayX + dayWidth * 0.05, y: y)
        .offset(dragOffset)
        .shadow(color: Color.black.opacity(dragOffset != .zero ? 0.3 : 0.1), radius: dragOffset != .zero ? 8 : 2, x: 0, y: dragOffset != .zero ? 4 : 1)
        .scaleEffect(dragOffset != .zero ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: dragOffset)
        .gesture(
            LongPressGesture(minimumDuration: 0.3)
                .onEnded { _ in
                    calendarService.startEventDrag(eventId: event.id)
                }
                .simultaneously(with:
                    DragGesture(minimumDistance: 5, coordinateSpace: .local)
                        .onChanged { value in
                            if calendarService.isDraggingEvent {
                                dragOffset = value.translation
                                calendarService.updateEventDrag(eventId: event.id, offset: value.translation)
                            }
                        }
                        .onEnded { value in
                            if calendarService.isDraggingEvent {
                                let newY = y + dragOffset.height + value.translation.height
                                let newHour = max(0, min(23, Int(newY / hourHeight)))
                                let newStartDate = Calendar.current.date(bySettingHour: newHour, minute: startMinute, second: 0, of: event.startDate) ?? event.startDate

                                Task {
                                    await calendarService.completeEventDrag(eventId: event.id, newStartTime: newStartDate)
                                }

                                dragOffset = .zero
                            }
                            calendarService.cancelEventDrag()
                        }
                )
        )
        .onTapGesture {
            calendarService.openEventDetails(eventId: event.id)
        }
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
