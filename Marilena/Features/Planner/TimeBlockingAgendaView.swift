import SwiftUI
import Combine

/// Vista timeblocking per visualizzare l'agenda delle prossime 48 ore con blocchi temporali
public struct TimeBlockingAgendaView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var reminderService: ReminderService
    
    @State private var events: [CalendarEvent] = []
    @State private var allDayEvents: [CalendarEvent] = []
    @State private var backlogItems: [CalendarReminder] = []
    @State private var currentTime = Date()
    @State private var timeUpdateCancellable: AnyCancellable?
    @State private var isLoading = false
    @State private var dragOffsets: [String: CGFloat] = [:]
    @State private var resizeOffsets: [String: CGFloat] = [:]
    @State private var isResizing: [String: Bool] = [:]
    
    // Configurazione vista
    private let minimumHoursToShow: Int = 48
    private let hourHeight: CGFloat = 80
    private let startHour: Int = 0 // Inizia da mezzanotte
    
    public init(calendarManager: CalendarManager, reminderService: ReminderService = .shared) {
        self.calendarManager = calendarManager
        self.reminderService = reminderService
    }

    // Timeline: giornata odierna + giornata di domani
    private var timelineStartDate: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var timelineEndDate: Date {
        Calendar.current.date(byAdding: .day, value: 2, to: timelineStartDate) ?? Date()
    }

    private var timelineHoursToShow: Int {
        let hours = Int(ceil(timelineEndDate.timeIntervalSince(timelineStartDate) / 3600))
        return max(minimumHoursToShow, hours)
    }
    
    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    // Header con data corrente
                    headerView
                    
                    if !allDayEvents.isEmpty {
                        allDaySection
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                    
                    // Timeline con blocchi temporali
                    timelineView
                        .padding(.horizontal, 16)
                }
            }
            .onAppear {
                Task { await loadData() }
                scrollToCurrentTime(proxy: proxy)
                startTimeUpdater()
            }
            .onDisappear {
                stopTimeUpdater()
            }
            .refreshable {
                await refreshData()
            }
        }
        .navigationTitle("Agenda")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        Group {
            let formattedNow = formattedHeaderDate(Date())
            let eventsCount = events.count
            VStack(spacing: 8) {
                Text(formattedNow)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                if eventsCount > 0 {
                    Text("\(eventsCount) eventi programmati")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))
        }
    }
    
    // MARK: - Timeline View
    
    private var timelineView: some View {
        ZStack(alignment: .topLeading) {
            // Griglia oraria di sfondo
            hourGrid
            
            // Blocchi eventi
            eventBlocks
            
            // Indicatore ora corrente
            currentTimeIndicator
        }
        .frame(height: CGFloat(timelineHoursToShow) * hourHeight)
    }
    
    // MARK: - Hour Grid
    
    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<timelineHoursToShow, id: \.self) { hourOffset in
                hourRow(hourOffset: hourOffset)
            }
        }
    }
    
    private func hourRow(hourOffset: Int) -> some View {
        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .hour, value: hourOffset, to: timelineStartDate) ?? timelineStartDate
        let formattedTime = formattedHourLabel(targetDate)
        
        return HStack(spacing: 0) {
            // Etichetta ora
            VStack(alignment: .trailing, spacing: 0) {
                Text(formattedTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .trailing)
                    .padding(.trailing, 8)
            }
            
            // Linea oraria
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 1)
            
            Spacer()
        }
        .frame(height: hourHeight)
    }
    
    // MARK: - Event Blocks
    
    private var eventBlocks: some View {
        GeometryReader { geometry in
            ForEach(events) { event in
                eventBlock(for: event, in: geometry)
            }
        }
        .padding(.leading, 68) // Spazio per etichette ore
    }
    
    private func eventBlock(for event: CalendarEvent, in geometry: GeometryProxy) -> some View {
        let timeRange = formattedTimeRange(start: event.startDate, end: event.endDate)
        let key = eventKey(for: event)
        let isCompleted = calendarManager.isCompleted(event)
        
        // Calcola posizione e altezza del blocco
        let startOffset = event.startDate.timeIntervalSince(timelineStartDate) / 3600.0
        let duration = event.endDate.timeIntervalSince(event.startDate) / 3600.0
        
        let yPosition = CGFloat(startOffset) * hourHeight
        let baseHeight = max(CGFloat(duration) * hourHeight, 40) // Minimo 40pt
        let resizeOffset = resizeOffsets[key] ?? 0
        let blockHeight = max(baseHeight + resizeOffset, 40) // Altezza minima 40pt
        let dragOffset = dragOffsets[key] ?? 0
        let isCurrentlyResizing = isResizing[key] ?? false
        
        // Colore basato sul tipo di evento
        let color = eventColor(for: event)
        
        return HStack(spacing: 8) {
            // Pallino di completamento (stile Structured)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    calendarManager.toggleCompleted(event)
                }
                
                // Haptic feedback
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            } label: {
                ZStack {
                    Circle()
                        .stroke(isCompleted ? color : Color(.separator), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(color)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
            
            // Contenuto evento
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .strikethrough(isCompleted)
                    .opacity(isCompleted ? 0.6 : 1.0)

                Text(timeRange)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .opacity(isCompleted ? 0.6 : 1.0)
                
                if let location = event.location {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                        Text(location)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                    .opacity(isCompleted ? 0.6 : 1.0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: blockHeight)
        .background(color.opacity(isCompleted ? 0.1 : 0.2))
        .overlay(
            Rectangle()
                .fill(color)
                .frame(width: 4)
                .opacity(isCompleted ? 0.5 : 1.0),
            alignment: .leading
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            // Handle per ridimensionamento sul bordo inferiore
            VStack {
                Spacer()
                ZStack {
                    // Area touch più grande per facilitare il drag
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 12)
                    
                    // Indicatore visivo del bordo ridimensionabile
                    HStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isCurrentlyResizing ? color : Color(.separator))
                            .frame(width: 40, height: 3)
                            .opacity(isCurrentlyResizing ? 1.0 : 0.6)
                        Spacer()
                    }
                    .frame(height: 12)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { dragValue in
                            if !isCurrentlyResizing {
                                isResizing[key] = true
                                // Haptic feedback quando inizia il ridimensionamento
                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                impact.impactOccurred()
                            }
                            
                            let heightDelta = dragValue.translation.height
                            resizeOffsets[key] = heightDelta
                        }
                        .onEnded { dragValue in
                            let heightDelta = dragValue.translation.height
                            let hoursDelta = heightDelta / hourHeight
                            
                            // Durata minima: 15 minuti
                            let minDuration: TimeInterval = 15 * 60
                            let currentDuration = event.endDate.timeIntervalSince(event.startDate)
                            let newDuration = max(currentDuration + (hoursDelta * 3600), minDuration)
                            
                            let newEnd = event.startDate.addingTimeInterval(newDuration)
                            let updatedEvent = CalendarEvent(
                                id: event.id,
                                title: event.title,
                                description: event.description,
                                startDate: event.startDate,
                                endDate: newEnd,
                                location: event.location,
                                isAllDay: event.isAllDay,
                                recurrenceRule: event.recurrenceRule,
                                attendees: event.attendees,
                                calendarId: event.calendarId,
                                url: event.url,
                                providerId: event.providerId,
                                providerType: event.providerType,
                                lastModified: Date()
                            )
                            
                            Task {
                                do {
                                    try await calendarManager.updateEvent(updatedEvent)
                                    await MainActor.run {
                                        replaceEvent(event, with: updatedEvent)
                                        resizeOffsets[key] = 0
                                        isResizing[key] = false
                                        
                                        // Haptic feedback per conferma
                                        let notification = UINotificationFeedbackGenerator()
                                        notification.notificationOccurred(.success)
                                    }
                                } catch {
                                    await MainActor.run {
                                        resizeOffsets[key] = 0
                                        isResizing[key] = false
                                        
                                        // Haptic feedback per errore
                                        let notification = UINotificationFeedbackGenerator()
                                        notification.notificationOccurred(.error)
                                    }
                                }
                            }
                        }
                )
            }
            .allowsHitTesting(true),
            alignment: .bottom
        )
        .position(x: geometry.size.width / 2, y: yPosition + blockHeight / 2 + dragOffset)
        .gesture(
            LongPressGesture(minimumDuration: 0.3)
                .sequenced(before: DragGesture(minimumDistance: 0))
                .onChanged { value in
                    // Non permettere lo spostamento se si sta ridimensionando
                    if isResizing[key] == true { return }
                    
                    if case .second(true, let drag?) = value {
                        dragOffsets[key] = drag.translation.height
                    }
                }
                .onEnded { value in
                    // Non permettere lo spostamento se si sta ridimensionando
                    if isResizing[key] == true { return }
                    
                    guard case .second(true, let drag?) = value else {
                        dragOffsets[key] = 0
                        return
                    }
                    
                    let hoursDelta = drag.translation.height / hourHeight
                    guard abs(hoursDelta) > 0.01 else {
                        dragOffsets[key] = 0
                        return
                    }
                    
                    let newStart = event.startDate.addingTimeInterval(Double(hoursDelta) * 3600)
                    let newEnd = event.endDate.addingTimeInterval(Double(hoursDelta) * 3600)
                    let updatedEvent = shiftedEvent(event, newStart: newStart, newEnd: newEnd)
                    
                    Task {
                        do {
                            try await calendarManager.updateEvent(updatedEvent)
                            await MainActor.run {
                                replaceEvent(event, with: updatedEvent)
                                dragOffsets[key] = 0
                            }
                        } catch {
                            await MainActor.run {
                                dragOffsets[key] = 0
                            }
                        }
                    }
                }
        )
    }
    
    private func eventColor(for event: CalendarEvent) -> Color {
        // Colore basato sul calendario o tipo di evento
        if event.title.lowercased().contains("meeting") || event.title.lowercased().contains("riunione") {
            return .blue
        } else if event.title.lowercased().contains("focus") || event.title.lowercased().contains("lavoro") {
            return .orange
        } else if event.isAllDay {
            return .purple
        } else {
            return .green
        }
    }
    
    // MARK: - Current Time Indicator
    
    private var currentTimeIndicator: some View {
        GeometryReader { geometry in
            let hoursSinceStart = currentTime.timeIntervalSince(timelineStartDate) / 3600.0
            
            if hoursSinceStart >= 0 && hoursSinceStart <= Double(timelineHoursToShow) {
                let yPosition = CGFloat(hoursSinceStart) * hourHeight
                
                VStack(spacing: 0) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                    
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
                .position(x: 30, y: yPosition)
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        isLoading = true

        let startDate = timelineStartDate
        let endDate = timelineEndDate

        await calendarManager.loadEvents(from: startDate, to: endDate)
        await reminderService.loadBacklogItems()

        await MainActor.run {
            let windowEvents = calendarManager.events
                .filter { event in
                    // includi eventi che si sovrappongono alla finestra -6h/+18h
                    event.endDate >= startDate && event.startDate <= endDate
                }

            allDayEvents = windowEvents
                .filter { $0.isAllDay }
                .sorted { $0.startDate < $1.startDate }
            events = windowEvents
                .filter { !$0.isAllDay }
                .sorted { $0.startDate < $1.startDate }

            backlogItems = reminderService.getBacklogItems()
            isLoading = false
        }
    }
    
    private func refreshData() async {
        await loadData()
    }

    private func eventKey(for event: CalendarEvent) -> String {
        event.id ?? event.providerId ?? "\(event.title)-\(event.startDate.timeIntervalSince1970)"
    }

    private func shiftedEvent(_ event: CalendarEvent, newStart: Date, newEnd: Date) -> CalendarEvent {
        CalendarEvent(
            id: event.id,
            title: event.title,
            description: event.description,
            startDate: newStart,
            endDate: newEnd,
            location: event.location,
            isAllDay: event.isAllDay,
            recurrenceRule: event.recurrenceRule,
            attendees: event.attendees,
            calendarId: event.calendarId,
            url: event.url,
            providerId: event.providerId,
            providerType: event.providerType,
            lastModified: event.lastModified
        )
    }

    private func replaceEvent(_ original: CalendarEvent, with updated: CalendarEvent) {
        if let idx = events.firstIndex(where: { eventKey(for: $0) == eventKey(for: original) }) {
            events[idx] = updated
        }
    }

    private func formattedHeaderDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formattedHourLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formattedTimeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.timeStyle = .short
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
    
    private var allDaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Eventi All‑Day")
                .font(.headline)
            
            ForEach(allDayEvents.indices, id: \.self) { index in
                let event = allDayEvents[index]
                let isCompleted = calendarManager.isCompleted(event)
                
                HStack(spacing: 10) {
                    // Pallino di completamento
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            calendarManager.toggleCompleted(event)
                        }
                        
                        // Haptic feedback
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(isCompleted ? eventColor(for: event) : Color(.separator), lineWidth: 2)
                                .frame(width: 20, height: 20)
                            
                            if isCompleted {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(eventColor(for: event))
                            } else {
                                Circle()
                                    .fill(eventColor(for: event))
                                    .frame(width: 10, height: 10)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.subheadline)
                            .lineLimit(1)
                            .strikethrough(isCompleted)
                            .opacity(isCompleted ? 0.6 : 1.0)
                        if let location = event.location, !location.isEmpty {
                            Label(location, systemImage: "mappin.and.ellipse")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .opacity(isCompleted ? 0.6 : 1.0)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .opacity(isCompleted ? 0.7 : 1.0)
            }
        }
    }
    
    private func scrollToCurrentTime(proxy: ScrollViewProxy) {
        let hoursSinceStart = currentTime.timeIntervalSince(timelineStartDate) / 3600.0
        
        if hoursSinceStart >= 0 && hoursSinceStart <= Double(timelineHoursToShow) {
            let targetHour = Int(hoursSinceStart)
            withAnimation {
                proxy.scrollTo(targetHour, anchor: .center)
            }
        }
    }
    
    // MARK: - Time Updater
    
    private func startTimeUpdater() {
        timeUpdateCancellable = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                currentTime = Date()
            }
    }
    
    private func stopTimeUpdater() {
        timeUpdateCancellable?.cancel()
        timeUpdateCancellable = nil
    }
}

#if canImport(SwiftUI)
#Preview {
    NavigationView {
        TimeBlockingAgendaView(
            calendarManager: CalendarManager(),
            reminderService: .shared
        )
    }
}
#endif
