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

    @State private var isCreatingEvent = false
    @State private var eventCreationStart: Date = Date()
    @State private var eventCreationEnd: Date = Date()
    @State private var showingEventCreation = false

    public var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                // Header fisso con data corrente
                dayHeaderFixed

                ScrollView(.vertical, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        // Sfondo con righe orarie
                        hourLinesBackground

                        // Overlay per creazione eventi con long press
                        eventCreationOverlay

                        // Eventi del giorno
                        dayEvents

                        // Indicatore ora corrente
                        currentTimeIndicator
                        
                        // Anteprima evento in creazione
                        if case .creating(let startTime, let endTime) = calendarService.gestureState {
                            eventCreationPreview(startTime: startTime, endTime: endTime)
                        }
                    }
                    .frame(height: calendarService.dayViewHourHeight * 24)
                }
            }
            .refreshable {
                await calendarService.handlePullToRefresh()
            }
            .onReceive(timer) { _ in
                currentTime = Date()
            }
            .onAppear {
                scrollToCurrentHour(proxy: proxy)
            }
            .highPriorityGesture(
                DragGesture(minimumDistance: CalendarGestureUtils.HorizontalSwipeParams.minimumDistance)
                    .onEnded { value in
                        let gestureType = CalendarGestureUtils.analyzeGesture(value.translation)
                        
                        switch gestureType {
                        case .horizontalSwipe(let direction):
                            switch direction {
                            case .right:
                                calendarService.handleHorizontalSwipe(.right)
                            case .left:
                                calendarService.handleHorizontalSwipe(.left)
                            }
                        case .verticalScroll, .ambiguous:
                            // Non gestisce scroll verticale o gesti ambigui - lascia passare allo ScrollView
                            break
                        }
                    }
            )
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        calendarService.handleDayViewPinchGesture(scale: value)
                    }
                    .onEnded { _ in
                        calendarService.completePinchGesture()
                    }
            )
            .sheet(isPresented: $showingEventCreation) {
                // Sheet per creazione rapida evento
                NavigationView {
                    CreateEventView(
                        calendarManager: calendarService.calendarManager,
                        suggestedStart: eventCreationStart,
                        suggestedEnd: eventCreationEnd
                    )
                }
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
                    // Etichetta ora compatta
                    Text(hourLabel(for: hour))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 35, alignment: .trailing)
                        .padding(.trailing, 6)

                    // Linea orizzontale
                    Rectangle()
                        .fill(Color(.separator).opacity(hour == 0 ? 0.6 : 0.3))
                        .frame(height: hour == 0 ? 2 : 1)

                    Spacer()
                }
                .frame(height: calendarService.dayViewHourHeight, alignment: .top)
                .id(hour)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Day Header Fixed
    private var dayHeaderFixed: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(calendarService.weekdayName(for: calendarService.selectedDate))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(calendarService.dayNumber(for: calendarService.selectedDate))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Text(calendarService.monthTitle(for: calendarService.selectedDate))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Indicatore oggi
            if Calendar.current.isDateInToday(calendarService.selectedDate) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("Oggi")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            Color(.systemGray6)
                .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
        )
    }
    
    // MARK: - Event Creation Overlay
    private var eventCreationOverlay: some View {
        Color.clear
            .contentShape(Rectangle())
            .allowsHitTesting(true)
            .gesture(
                LongPressGesture(minimumDuration: CalendarGestureUtils.EventCreationParams.longPressMinimumDuration)
                    .sequenced(before: DragGesture(minimumDistance: CalendarGestureUtils.EventCreationParams.dragMinimumDistance))
                    .onChanged { value in
                        switch value {
                        case .second(true, let drag):
                            if let drag = drag {
                                let yPosition = drag.location.y
                                let (hour, rawMinute) = CalendarGestureUtils.hourFromYPosition(yPosition, hourHeight: calendarService.dayViewHourHeight)
                                let minute = CalendarGestureUtils.snapToMinuteGrid(rawMinute, gridSize: CalendarGestureUtils.EventCreationParams.snapToMinutes)
                                
                                if case .idle = calendarService.gestureState {
                                    // Inizia creazione evento
                                    let startDate = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: calendarService.selectedDate) ?? calendarService.selectedDate
                                    calendarService.startEventCreation(at: startDate)
                                } else {
                                    // Aggiorna fine evento
                                    let endDate = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: calendarService.selectedDate) ?? calendarService.selectedDate
                                    calendarService.updateEventCreation(endTime: endDate)
                                }
                            }
                        default:
                            break
                        }
                    }
                    .onEnded { value in
                        if case .second(true, _) = value {
                            if let timeRange = calendarService.completeEventCreation() {
                                eventCreationStart = timeRange.start
                                eventCreationEnd = timeRange.end
                                showingEventCreation = true
                            }
                        }
                    },
                including: .subviews
            )
            .onTapGesture(count: 2) { location in
                // Double tap per creazione rapida
                let yPosition = location.y
                let (hour, rawMinute) = CalendarGestureUtils.hourFromYPosition(yPosition, hourHeight: calendarService.dayViewHourHeight)
                let minute = CalendarGestureUtils.snapToMinuteGrid(rawMinute, gridSize: CalendarGestureUtils.EventCreationParams.snapToMinutes)
                
                let startDate = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: calendarService.selectedDate) ?? calendarService.selectedDate
                
                calendarService.handleDoubleTap(at: startDate)
                eventCreationStart = startDate
                eventCreationEnd = startDate.addingTimeInterval(3600) // 1 ora di default
                showingEventCreation = true
            }
            .padding(.horizontal, 84)
    }
    
    // MARK: - Helper Methods
    
    // MARK: - Event Creation Preview
    private func eventCreationPreview(startTime: Date, endTime: Date) -> some View {
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: startTime)
        let startMinute = calendar.component(.minute, from: startTime)
        let endHour = calendar.component(.hour, from: endTime)
        let endMinute = calendar.component(.minute, from: endTime)
        
        let startY = (CGFloat(startHour) + CGFloat(startMinute) / 60.0) * calendarService.dayViewHourHeight
        let endY = (CGFloat(endHour) + CGFloat(endMinute) / 60.0) * calendarService.dayViewHourHeight
        
        let actualStartY = min(startY, endY)
        let height = max(abs(endY - startY), 30) // Minimo 30 pixel
        
        return VStack {
            Text("Nuovo Evento")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
            
            Text("\(startTime.formatted(date: .omitted, time: .shortened)) - \(endTime.formatted(date: .omitted, time: .shortened))")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: height, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5]))
                )
        )
        .offset(y: actualStartY)
        .padding(.horizontal, 88)
        .animation(.easeInOut(duration: 0.1), value: actualStartY)
    }

    // MARK: - Day Events
    private var dayEvents: some View {
        let events = calendarService.dayData(for: calendarService.selectedDate)

        return ZStack(alignment: .topLeading) {
            ForEach(events.indices, id: \.self) { index in
                let event = events[index]
                DayEventView(event: event, hourHeight: calendarService.dayViewHourHeight, calendarService: calendarService)
            }
        }
        .padding(.horizontal, 84) // Spazio per etichette ora + margine
    }

    // MARK: - Current Time Indicator
    private var currentTimeIndicator: some View {
        // Solo se è oggi
        guard calendar.isDate(calendarService.selectedDate, inSameDayAs: Date()) else {
            return AnyView(EmptyView())
        }

        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)
        let y = (CGFloat(hour) + CGFloat(minute) / 60.0) * calendarService.dayViewHourHeight + 20 // +20 per header

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
                    .padding(.leading, 84)
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
    @ObservedObject var calendarService: NewCalendarService
    @State private var dragOffset = CGSize.zero

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
                .shadow(color: Color.black.opacity(dragOffset != .zero ? 0.25 : 0.15), radius: dragOffset != .zero ? 8 : 4, x: 0, y: dragOffset != .zero ? 4 : 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(dragOffset != .zero ? 0.5 : 0.2), lineWidth: dragOffset != .zero ? 2 : 1)
        )
        .offset(x: dragOffset.width, y: y + dragOffset.height)
        .scaleEffect(dragOffset != .zero ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: dragOffset)
        .padding(.horizontal, 4)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                    calendarService.updateEventDrag(eventId: event.id, offset: value.translation)
                }
                .onEnded { value in
                    let newY = y + value.translation.height
                    let newHour = max(0, min(23, Int(newY / hourHeight)))
                    let newStartDate = Calendar.current.date(bySettingHour: newHour, minute: startMinute, second: 0, of: event.startDate) ?? event.startDate
                    
                    Task {
                        await calendarService.completeEventDrag(eventId: event.id, newStartTime: newStartDate)
                    }
                    
                    dragOffset = .zero
                }
        )
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
