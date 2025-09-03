import SwiftUI

struct DayTimelineView: View {
    @ObservedObject var calendarManager: CalendarManager
    @State var selectedDate: Date
    @State private var draggingEventID: String?
    @State private var resizingEventID: String?
    @State private var scrollToNow: Bool = true
    private let leftGutter: CGFloat = 48 // hour label + spacing
    @State private var showGraphicalPicker: Bool = false
    // Creation by drag
    @State private var isSelecting: Bool = false
    @State private var selectStartMin: Int? = nil
    @State private var selectEndMin: Int? = nil
    @State private var showingCreateSheet: Bool = false
    @State private var createStart: Date = Date()
    @State private var createEnd: Date = Date().addingTimeInterval(3600)
    // Detail / edit
    @State private var selectedEvent: CalendarEvent? = nil
    @State private var showingDetail: Bool = false
    @State private var showingEdit: Bool = false
    @State private var showingAICreateSheet: Bool = false
    @State private var showingEventsList: Bool = false

    @State private var hourHeight: CGFloat = 64
    @State private var hourHeightBase: CGFloat = 64
    private let minDurationMinutes = 15

    init(calendarManager: CalendarManager, date: Date = Date()) {
        self.calendarManager = calendarManager
        self._selectedDate = State(initialValue: Calendar.current.startOfDay(for: date))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                allDayBar
                
                // Events List (Fantastical-style)
                if showingEventsList {
                    eventsListView
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Divider()
                timeline
            }
            
            // Floating Action Buttons
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        // AI Event Creation Button
                        Button(action: {
                            createStart = Date()
                            createEnd = Date().addingTimeInterval(3600)
                            showingAICreateSheet = true
                        }) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.purple)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        
                        // Classic Event Creation Button
                        Button(action: {
                            createStart = Date()
                            createEnd = Date().addingTimeInterval(3600)
                            showingCreateSheet = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.red)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 20)
                }
            }
        }
        // nested navigation title not needed; CalendarView owns it
        .task {
            await calendarManager.loadEvents(from: selectedDate, to: Calendar.current.date(byAdding: .day, value: 1, to: selectedDate))
        }
        .sheet(isPresented: $showingCreateSheet) {
            NavigationView {
                CreateEventView(calendarManager: calendarManager, suggestedStart: createStart, suggestedEnd: createEnd)
            }
        }
        .sheet(isPresented: $showingDetail) {
            if let ev = selectedEvent {
                EventDetailSheet(event: ev, calendarManager: calendarManager)
            }
        }
        .sheet(isPresented: $showingEdit) {
            if let ev = selectedEvent {
                EventEditView(calendarManager: calendarManager, event: ev)
            }
        }
        .sheet(isPresented: $showingAICreateSheet) {
            NavigationView {
                AIEventCreationView(calendarManager: calendarManager, suggestedStart: createStart, suggestedEnd: createEnd)
            }
        }
        // Horizontal swipe between days without blocking vertical scroll/gestures
        .simultaneousGesture(daySwipeGesture())
    }
    
    // MARK: - Events List View (Fantastical-style)
    private var eventsListView: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                // Eventi imminenti
                ForEach(upcomingEvents, id: \.id) { event in
                    EventListRow(event: event, calendarManager: calendarManager)
                        .onTapGesture {
                            selectedEvent = event
                            showingEdit = true
                        }
                }
                
                // Promemoria imminenti
                ForEach(upcomingReminders, id: \.id) { reminder in
                    ReminderListRow(reminder: reminder, calendarManager: calendarManager)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 200)
        .background(Color(.systemGray6))
    }
    
    private var upcomingEvents: [CalendarEvent] {
        let calendar = Calendar.current
        let now = Date()
        let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: now) ?? now
        
        return calendarManager.events
            .filter { event in
                event.startDate >= now && event.startDate <= endOfWeek
            }
            .sorted { $0.startDate < $1.startDate }
            .prefix(10)
            .map { $0 }
    }
    
    private var upcomingReminders: [CalendarReminder] {
        let calendar = Calendar.current
        let now = Date()
        let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: now) ?? now
        
        return calendarManager.reminders
            .filter { reminder in
                !reminder.isCompleted && (reminder.dueDate ?? reminder.creationDate) >= now && (reminder.dueDate ?? reminder.creationDate) <= endOfWeek
            }
            .sorted { ($0.dueDate ?? $0.creationDate) < ($1.dueDate ?? $1.creationDate) }
            .prefix(5)
            .map { $0 }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: { shiftDay(-1) }) { Image(systemName: "chevron.left") }
            Spacer(minLength: 6)
            DatePicker("", selection: $selectedDate, displayedComponents: [.date])
                .datePickerStyle(.compact)
                .labelsHidden()
                .onChange(of: selectedDate) { _, _ in
                    Task { await calendarManager.loadEvents(from: selectedDate, to: Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)) }
                }
            Button(action: { showGraphicalPicker.toggle() }) {
                Image(systemName: "calendar")
                    .foregroundColor(.red)
            }
            .popover(isPresented: $showGraphicalPicker) {
                VStack(alignment: .leading) {
                    DatePicker("", selection: $selectedDate, displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .onChange(of: selectedDate) { _, _ in
                            Task { await calendarManager.loadEvents(from: selectedDate, to: Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)) }
                        }
                }
                .padding()
            }
            Spacer(minLength: 6)
            Button(action: { shiftDay(1) }) { Image(systemName: "chevron.right") }
            Button(action: { 
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingEventsList.toggle() 
                }
            }) { 
                Image(systemName: showingEventsList ? "chevron.up" : "chevron.down")
                    .foregroundColor(.red)
                    .font(.system(size: 12, weight: .semibold))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var allDayBar: some View {
        let allDay = dayEvents.filter { $0.isAllDay }
        let allDayReminders = dayReminders.filter { $0.dueDate == nil } // Promemoria senza orario specifico
        
        return Group {
            if !allDay.isEmpty || !allDayReminders.isEmpty {
                VStack(spacing: 4) {
                    // Eventi tutto il giorno - stile iPhone Calendar
                    ForEach(allDay, id: \.id) { ev in
                        HStack(spacing: 8) {
                            Button(action: {
                                let wasCompleted = calendarManager.isCompleted(ev)
                                if wasCompleted { Haptics.selection() } else { Haptics.success() }
                                calendarManager.toggleCompleted(ev)
                            }) {
                                Image(systemName: calendarManager.isCompleted(ev) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(calendarManager.isCompleted(ev) ? .green : eventColor(for: ev))
                                    .font(.system(size: 18, weight: .medium))
                            }
                            .buttonStyle(.plain)
                            
                            Text(ev.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            if let location = ev.location, !location.isEmpty {
                                Image(systemName: "location.fill")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(eventColor(for: ev).opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(eventColor(for: ev).opacity(0.3), lineWidth: 1)
                                )
                        )
                        .onTapGesture {
                            selectedEvent = ev
                            showingEdit = true
                        }
                    }
                    
                    // Promemoria senza orario - design più compatto
                    ForEach(allDayReminders, id: \.id) { reminder in
                        HStack(spacing: 8) {
                            Button(action: {
                                let wasCompleted = reminder.isCompleted
                                if wasCompleted { Haptics.selection() } else { Haptics.success() }
                                calendarManager.toggleCompleted(reminder)
                            }) {
                                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(reminder.isCompleted ? .green : reminder.statusColor)
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .buttonStyle(.plain)
                            
                            Image(systemName: "checklist")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(reminder.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .strikethrough(reminder.isCompleted)
                            
                            Spacer()
                            
                            if reminder.isOverdue {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(reminder.statusColor.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(reminder.statusColor.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
            }
        }
    }
    
    // Helper function per il colore dell'evento
    private func eventColor(for event: CalendarEvent) -> Color {
        switch event.providerType {
        case .eventKit:
            return .blue
        case .googleCalendar:
            return .green
        case .microsoftGraph:
            return .orange
        }
    }

    private var timeline: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    ZStack(alignment: .topLeading) {
                        hoursGrid(height: hourHeight * 24)
                        eventsOverlay(width: geo.size.width)
                        nowIndicator(width: geo.size.width)
                        selectionOverlay()
                    }
                    .frame(height: hourHeight * 24)
                    .contentShape(Rectangle())
                    .overlay(
                        ZStack {
                            // Two-finger pan to select interval
                            TwoFingerPanOverlay(
                                onBegan: { p in beginTwoFingerSelection(at: p) },
                                onChanged: { start, cur in updateTwoFingerSelection(start: start, current: cur) },
                                onEnded: { start, cur in endTwoFingerSelection(start: start, current: cur) }
                            )
                            // Single-finger long press to quick-create default duration
                            LongPressLocationOverlay(minimumPressDuration: 0.4) { p in
                                guard draggingEventID == nil && resizingEventID == nil else { return }
                                let m = snapMinutes(clampToMinutes(p.y))
                                createStart = dateFromMinutes(m)
                                createEnd = dateFromMinutes(m + CalendarPreferences.defaultDurationMinutes)
                                showingCreateSheet = true
                            }
                        }
                    )
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged { scale in
                                let newHeight = clampHourHeight(hourHeightBase * scale)
                                
                                // Feedback tattile quando si raggiungono le dimensioni standard
                                if abs(newHeight - 64) < 2 && abs(hourHeight - 64) >= 2 {
                                    Haptics.impactLight() // Snap a dimensione normale
                                } else if abs(newHeight - 100) < 2 && abs(hourHeight - 100) >= 2 {
                                    Haptics.impactLight() // Snap a dimensione grande
                                } else if abs(newHeight - 40) < 2 && abs(hourHeight - 40) >= 2 {
                                    Haptics.impactLight() // Snap a dimensione piccola
                                }
                                
                                hourHeight = newHeight
                            }
                            .onEnded { scale in
                                hourHeightBase = hourHeight
                                
                                // Feedback di completamento
                                Haptics.impactMedium()
                            }
                    )
                    .onAppear {
                        if scrollToNow { scrollToCurrentHour(proxy: proxy, viewHeight: geo.size.height) }
                    }
                }
            }
        }
    }

    private func hoursGrid(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HStack(alignment: .top) {
                    Text(String(format: "%02d:00", hour))
                        .font(.caption2)
                        .frame(width: 36, alignment: .trailing)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 4)
                    Rectangle().fill(Color(.separator)).frame(height: 0.5)
                }
                .frame(height: hourHeight, alignment: .top)
                .id("hour_\(hour)")
            }
        }
        .padding(.leading, 4)
    }

    private func eventsOverlay(width: CGFloat) -> some View {
        let nonAllDay = dayEvents.filter { !$0.isAllDay }
        let timedReminders = dayReminders.filter { $0.dueDate != nil }
        let placed = placeEvents(nonAllDay)
        let reminderPlaced = placeReminders(timedReminders)
        
        return ZStack(alignment: .topLeading) {
            // Eventi normali
            ForEach(placed.indices, id: \.self) { idx in
                let item = placed[idx]
                let frame = frameFor(event: item.event, dayWidth: width - (leftGutter + 12), columns: item.totalColumns, column: item.column)
                eventBlock(item.event, totalColumns: item.totalColumns)
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.minX + frame.width / 2, y: frame.minY + frame.height / 2)
            }
            
            // Promemoria con orario
            ForEach(reminderPlaced.indices, id: \.self) { idx in
                let item = reminderPlaced[idx]
                let frame = frameForReminder(reminder: item.reminder, dayWidth: width - (leftGutter + 12), columns: item.totalColumns, column: item.column)
                reminderBlock(item.reminder, totalColumns: item.totalColumns)
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.minX + frame.width / 2, y: frame.minY + frame.height / 2)
            }
        }
        .padding(.leading, leftGutter) // align after hour labels
        .padding(.trailing, 8)
        .coordinateSpace(name: "timelineArea")
        .onDrop(of: [UTType.text], delegate: TimelineDropDelegate(calendarManager: calendarManager, selectedDate: selectedDate, hourHeight: hourHeight))
    }

    private func nowIndicator(width: CGFloat) -> some View {
        let cal = Calendar.current
        let start = cal.startOfDay(for: selectedDate)
        let now = Date()
        let visibleDay = cal.isDate(now, inSameDayAs: selectedDate)
        guard visibleDay else { return AnyView(EmptyView()) }
        let minutes = max(0, min(24*60, Int(now.timeIntervalSince(start) / 60)))
        let y = CGFloat(minutes) / 60 * hourHeight
        return AnyView(
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.red)
                    .frame(height: 2)
                    .offset(x: leftGutter + 4, y: y)
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .offset(x: leftGutter, y: y - 3)
            }
        )
    }

    private func eventBlock(_ ev: CalendarEvent, totalColumns: Int) -> some View {
        let isCompleted = calendarManager.isCompleted(ev)
        let baseColor = colorFor(event: ev) ?? Color.red
        var isDragging = draggingEventID == (ev.id ?? ev.providerId)

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(isCompleted ? Color.green.opacity(0.18) : baseColor.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isCompleted ? Color.green.opacity(0.7) : baseColor.opacity(0.7), lineWidth: totalColumns > 1 ? 2 : 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Button(action: {
                        let wasCompleted = calendarManager.isCompleted(ev)
                        if wasCompleted { Haptics.selection() } else { Haptics.success() }
                        calendarManager.toggleCompleted(ev)
                    }) {
                        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isCompleted ? .green : baseColor)
                            .font(.title2)
                            .frame(width: 32, height: 32)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .allowsHitTesting(true) // Explicitly allow button taps
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ev.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .allowsHitTesting(false) // Don't interfere with gestures
                        
                        Text("\(timeString(ev.startDate)) – \(timeString(ev.endDate))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .allowsHitTesting(false) // Don't interfere with gestures
                    }
                    
                    Spacer()
                    if totalColumns > 1 {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .allowsHitTesting(false) // Don't interfere with gestures
                    }
                }
            }
            .padding(8)
            
            // Resize handles areas (top and bottom invisible pads)
            VStack(spacing: 0) {
                Rectangle().fill(Color.clear).frame(height: 12)
                    .contentShape(Rectangle())
                    .gesture(resizeGesture(ev: ev, isTop: true))
                Spacer(minLength: 0)
                Rectangle().fill(Color.clear).frame(height: 12)
                    .contentShape(Rectangle())
                    .gesture(resizeGesture(ev: ev, isTop: false))
            }
        }
        .scaleEffect(isDragging ? 1.05 : 1)
        .shadow(color: isDragging ? Color.primary.opacity(0.3) : Color.clear, radius: isDragging ? 8 : 0, x: 0, y: isDragging ? 4 : 0)
        .animation(.easeOut(duration: 0.2), value: isDragging)
        .simultaneousGesture(
            // Single unified gesture system that handles all interactions
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let distance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))

                    // Only start dragging if we've moved enough and it's been long enough
                    if distance > 15 && draggingEventID == nil {
                        Haptics.impactLight()
                        draggingEventID = ev.id ?? ev.providerId
                    }
                }
                .onEnded { value in
                    let distance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
                    
                    if draggingEventID == (ev.id ?? ev.providerId) {
                        // Handle drag end - move event
                        let minutesDelta = Int((value.translation.height / hourHeight) * 60)
                        let snappedDelta = snapMinutes(minutesDelta)
                        
                        if snappedDelta != 0 {
                            moveEvent(ev, byMinutes: snappedDelta)
                        }
                        draggingEventID = nil
                    } else if distance < 10 {
                        // Small movement = tap gesture for editing
                        selectedEvent = ev
                        showingEdit = true
                    }
                }
        )
        .simultaneousGesture(
            // Separate long press for force-starting drag mode
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    if draggingEventID == nil {
                        Haptics.impactMedium()
                        draggingEventID = ev.id ?? ev.providerId
                    }
                }
        )
        .onDrag {
            Haptics.impactLight()
            return NSItemProvider(object: NSString(string: calendarManager.eventKey(for: ev)))
        }
    }

    // MARK: - Selection overlay & gesture
    private func selectionOverlay() -> some View {
        guard isSelecting, let s = selectStartMin, let e = selectEndMin else { return AnyView(EmptyView()) }
        let start = CGFloat(min(s, e))
        let end = CGFloat(max(s, e))
        let y = (start / 60) * hourHeight
        let h = max(8, ((end - start) / 60) * hourHeight)
        return AnyView(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.red.opacity(0.15))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.red, style: StrokeStyle(lineWidth: 1, dash: [4,3])))
                .frame(height: h)
                .padding(.leading, leftGutter)
                .padding(.trailing, 8)
                .offset(y: y)
        )
    }

    // Two-finger creation helpers
    private func beginTwoFingerSelection(at point: CGPoint) {
        // Begin only if on grid area
        isSelecting = true
        let m = snapMinutes(clampToMinutes(point.y))
        selectStartMin = m
        selectEndMin = m
    }

    private func updateTwoFingerSelection(start: CGPoint, current: CGPoint) {
        guard isSelecting else { return }
        let s = snapMinutes(clampToMinutes(start.y))
        let c = snapMinutes(clampToMinutes(current.y))
        selectStartMin = s
        selectEndMin = c
    }

    private func endTwoFingerSelection(start: CGPoint, current: CGPoint) {
        guard isSelecting else { return }
        defer { isSelecting = false; selectStartMin = nil; selectEndMin = nil }
        let s = snapMinutes(clampToMinutes(start.y))
        let e = snapMinutes(clampToMinutes(current.y))
        let startMin = min(s, e)
        let endMin = max(s, e)
        guard endMin - startMin >= minDurationMinutes else { return }
        createStart = dateFromMinutes(startMin)
        createEnd = dateFromMinutes(endMin)
        showingCreateSheet = true
    }

    // MARK: - Event Movement
    
    private func moveEvent(_ event: CalendarEvent, byMinutes delta: Int) {
        let newStart = event.startDate.addingTimeInterval(TimeInterval(delta * 60))
        let newEnd = event.endDate.addingTimeInterval(TimeInterval(delta * 60))
        
        let updatedEvent = CalendarEvent(
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
            lastModified: Date()
        )
        
        Task {
            do {
                try await calendarManager.updateEvent(updatedEvent)
                Haptics.success()
            } catch {
                Haptics.selection()
                calendarManager.error = "Errore spostamento evento: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Gestures

    private func dragGesture(ev: CalendarEvent) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if draggingEventID == nil {
                    Haptics.impactLight()
                    // Feedback visivo durante il drag
                    draggingEventID = ev.id ?? ev.providerId
                }
            }
            .onEnded { value in
                let wasDragging = draggingEventID != nil
                draggingEventID = nil

                let minutesDelta = Int((value.translation.height / hourHeight) * 60)
                guard minutesDelta != 0 else { return }

                let snapped = snapMinutes(minutesDelta)
                let newStart = ev.startDate.addingTimeInterval(TimeInterval(snapped * 60))
                let newEnd = ev.endDate.addingTimeInterval(TimeInterval(snapped * 60))

                let updated = CalendarEvent(
                    id: ev.id,
                    title: ev.title,
                    description: ev.description,
                    startDate: newStart,
                    endDate: newEnd,
                    location: ev.location,
                    isAllDay: ev.isAllDay,
                    recurrenceRule: ev.recurrenceRule,
                    attendees: ev.attendees,
                    calendarId: ev.calendarId,
                    url: ev.url,
                    providerId: ev.providerId,
                    providerType: ev.providerType,
                    lastModified: Date()
                )

                Task {
                    do {
                        try await calendarManager.updateEvent(updated)
                        if wasDragging {
                            Haptics.success()
                        }
                    } catch {
                        Haptics.selection()
                        calendarManager.error = "Errore spostamento evento: \(error.localizedDescription)"
                    }
                }
            }
    }

    private func resizeGesture(ev: CalendarEvent, isTop: Bool) -> some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                if resizingEventID == nil { 
                    Haptics.impactLight() 
                    resizingEventID = ev.id ?? ev.providerId
                }
                
                // Feedback visivo durante il resize
                let minutesDelta = Int((value.translation.height / hourHeight) * 60)
                let snapped = snapMinutes(minutesDelta)
                
                // Feedback tattile per snap ai 15 minuti
                if snapped % 15 == 0 && snapped != 0 {
                    Haptics.selection()
                }
            }
            .onEnded { value in
                defer { resizingEventID = nil }
                
                let minutesDelta = Int((value.translation.height / hourHeight) * 60)
                let snapped = snapMinutes(minutesDelta)
                
                guard snapped != 0 else { return }
                
                var newStart = ev.startDate
                var newEnd = ev.endDate
                
                if isTop {
                    newStart = ev.startDate.addingTimeInterval(TimeInterval(snapped * 60))
                    // Assicura durata minima
                    if newStart >= newEnd { 
                        newStart = newEnd.addingTimeInterval(-TimeInterval(minDurationMinutes * 60)) 
                    }
                } else {
                    newEnd = ev.endDate.addingTimeInterval(TimeInterval(snapped * 60))
                    // Assicura durata minima
                    if newEnd <= newStart { 
                        newEnd = newStart.addingTimeInterval(TimeInterval(minDurationMinutes * 60)) 
                    }
                }
                
                resizeEvent(ev, newStart: newStart, newEnd: newEnd)
            }
    }
    
    private func resizeEvent(_ event: CalendarEvent, newStart: Date, newEnd: Date) {
        let updatedEvent = CalendarEvent(
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
            lastModified: Date()
        )
        
        Task {
            do {
                try await calendarManager.updateEvent(updatedEvent)
                Haptics.success()
            } catch {
                Haptics.selection()
                calendarManager.error = "Errore ridimensionamento evento: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Layout helpers

    private struct Placed {
        let event: CalendarEvent
        let column: Int
        let totalColumns: Int
    }
    
    private struct PlacedReminder {
        let reminder: CalendarReminder
        let column: Int
        let totalColumns: Int
    }

    private func placeEvents(_ events: [CalendarEvent]) -> [Placed] {
        let dayStart = selectedDate
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!

        // Clamp events to the day and sort
        let clamped: [CalendarEvent] = events.map { ev in
            let s = max(ev.startDate, dayStart)
            let e = min(ev.endDate, dayEnd)
            return CalendarEvent(id: ev.id, title: ev.title, description: ev.description, startDate: s, endDate: e, location: ev.location, isAllDay: ev.isAllDay, recurrenceRule: ev.recurrenceRule, attendees: ev.attendees, calendarId: ev.calendarId, url: ev.url, providerId: ev.providerId, providerType: ev.providerType, lastModified: ev.lastModified)
        }.sorted { a, b in
            if a.startDate == b.startDate { return a.endDate < b.endDate }
            return a.startDate < b.startDate
        }

        // Build clusters of overlapping events
        var result: [Placed] = []
        var i = 0
        while i < clamped.count {
            var cluster: [CalendarEvent] = [clamped[i]]
            var clusterEnd = clamped[i].endDate
            var j = i + 1
            while j < clamped.count {
                if clamped[j].startDate < clusterEnd { // overlap
                    cluster.append(clamped[j])
                    clusterEnd = max(clusterEnd, clamped[j].endDate)
                    j += 1
                } else {
                    break
                }
            }
            // Assign columns within cluster
            let placedCluster = assignColumns(cluster)
            result.append(contentsOf: placedCluster)
            i = j
        }
        return result
    }

    private func assignColumns(_ cluster: [CalendarEvent]) -> [Placed] {
        var columns: [[CalendarEvent]] = []
        for ev in cluster {
            var placed = false
            for idx in 0..<columns.count {
                if columns[idx].last!.endDate <= ev.startDate { // free slot
                    columns[idx].append(ev)
                    placed = true
                    break
                }
            }
            if !placed {
                columns.append([ev])
            }
        }
        let total = max(1, columns.count)
        var out: [Placed] = []
        for (idx, col) in columns.enumerated() {
            for ev in col { out.append(Placed(event: ev, column: idx, totalColumns: total)) }
        }
        return out
    }

    private func frameFor(event ev: CalendarEvent, dayWidth: CGFloat, columns: Int, column: Int) -> CGRect {
        let fractionWidth = dayWidth / CGFloat(max(1, columns))
        let x = CGFloat(column) * fractionWidth
        let minutesFromStart = CGFloat(minutesSinceStartOfDay(ev.startDate))
        let minutesLength = CGFloat(max(10, minutesBetween(ev.startDate, ev.endDate)))
        let y = (minutesFromStart / 60) * hourHeight
        let h = (minutesLength / 60) * hourHeight
        return CGRect(x: x, y: y, width: fractionWidth - 5, height: max(h, 24))
    }
    
    // MARK: - Reminder Layout Methods
    
    private func placeReminders(_ reminders: [CalendarReminder]) -> [PlacedReminder] {
        // I promemoria vengono trattati come eventi di 30 minuti per la visualizzazione
        var result: [PlacedReminder] = []
        let sortedReminders = reminders.sorted { 
            ($0.dueDate ?? $0.creationDate) < ($1.dueDate ?? $1.creationDate) 
        }
        
        // Per semplicità, i promemoria non si sovrappongono - ognuno occupa una colonna
        for reminder in sortedReminders {
            result.append(PlacedReminder(reminder: reminder, column: 0, totalColumns: 1))
        }
        
        return result
    }
    
    private func frameForReminder(reminder: CalendarReminder, dayWidth: CGFloat, columns: Int, column: Int) -> CGRect {
        let fractionWidth = dayWidth / CGFloat(max(1, columns))
        let x = CGFloat(column) * fractionWidth
        
        guard let dueDate = reminder.dueDate else {
            // Se non c'è data di scadenza, mostra all'inizio della giornata
            return CGRect(x: x, y: 0, width: fractionWidth - 5, height: 40)
        }
        
        let minutesFromStart = CGFloat(minutesSinceStartOfDay(dueDate))
        let y = (minutesFromStart / 60) * hourHeight
        let h: CGFloat = 40 // Altezza fissa per i promemoria
        
        return CGRect(x: x, y: y, width: fractionWidth - 5, height: h)
    }
    
    private func reminderBlock(_ reminder: CalendarReminder, totalColumns: Int) -> some View {
        let isCompleted = reminder.isCompleted
        let baseColor = reminder.statusColor
        
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(isCompleted ? Color.green.opacity(0.18) : baseColor.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isCompleted ? Color.green.opacity(0.7) : baseColor.opacity(0.7), lineWidth: totalColumns > 1 ? 2 : 1)
                )

            HStack(spacing: 6) {
                Button(action: {
                    let wasCompleted = reminder.isCompleted
                    if wasCompleted { Haptics.selection() } else { Haptics.success() }
                    calendarManager.toggleCompleted(reminder)
                }) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isCompleted ? .green : baseColor)
                        .font(.title3)
                        .frame(width: 24, height: 24)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                
                Image(systemName: "checklist")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(reminder.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                
                Spacer()
                
                if reminder.isOverdue {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
            .padding(6)
        }
        .onTapGesture {
            // TODO: Aggiungi vista dettaglio per promemoria
        }
    }

    // MARK: - Utils

    private var dayEvents: [CalendarEvent] {
        calendarManager.events.filter { Calendar.current.isDate($0.startDate, inSameDayAs: selectedDate) || Calendar.current.isDate($0.endDate, inSameDayAs: selectedDate) || ($0.startDate < selectedDate && $0.endDate > selectedDate) }
    }
    
    private var dayReminders: [CalendarReminder] {
        calendarManager.reminders.filter { reminder in
            if let dueDate = reminder.dueDate {
                return Calendar.current.isDate(dueDate, inSameDayAs: selectedDate)
            } else {
                return Calendar.current.isDate(reminder.creationDate, inSameDayAs: selectedDate)
            }
        }
    }

    private func minutesSinceStartOfDay(_ date: Date) -> Int {
        let start = Calendar.current.startOfDay(for: selectedDate)
        return max(0, Int(date.timeIntervalSince(start) / 60))
    }

    private func minutesBetween(_ a: Date, _ b: Date) -> Int {
        max(1, Int(b.timeIntervalSince(a) / 60))
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func colorFor(event: CalendarEvent) -> Color? {
        if let calId = event.calendarId, let cal = calendarManager.calendars.first(where: { $0.id == calId }) {
            if let c = Color(hex: cal.color) { return c }
        }
        // fallback per provider
        switch event.providerType {
        case .eventKit: return Color.red
        case .googleCalendar: return Color(red: 0.13, green: 0.52, blue: 0.96)
        case .microsoftGraph: return Color(red: 0.0, green: 0.46, blue: 0.85)
        }
    }

    private func snapMinutes(_ minutes: Int) -> Int {
        let step = minDurationMinutes
        let rem = minutes % step
        if abs(rem) < step/2 { return minutes - rem }
        return minutes + (minutes > 0 ? (step - rem) : -(step + rem))
    }

    private func clampHourHeight(_ value: CGFloat) -> CGFloat {
        min(120, max(36, value))
    }

    private func clampToMinutes(_ y: CGFloat) -> Int {
        let minutes = Int((y / hourHeight) * 60)
        return max(0, min(24 * 60, minutes))
    }

    private func dateFromMinutes(_ minutes: Int) -> Date {
        let start = Calendar.current.startOfDay(for: selectedDate)
        return start.addingTimeInterval(TimeInterval(minutes * 60))
    }

    private func shiftDay(_ delta: Int) {
        if let d = Calendar.current.date(byAdding: .day, value: delta, to: selectedDate) {
            selectedDate = Calendar.current.startOfDay(for: d)
        }
    }

    private func daySwipeGesture() -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard draggingEventID == nil, resizingEventID == nil, !isSelecting else { return }
                guard abs(dx) > 80, abs(dx) > abs(dy) else { return }
                withAnimation(.easeOut(duration: 0.2)) { shiftDay(dx < 0 ? 1 : -1) }
            }
    }

    private func scrollToCurrentHour(proxy: ScrollViewProxy, viewHeight: CGFloat) {
        let now = Date()
        guard Calendar.current.isDate(now, inSameDayAs: selectedDate) else { return }
        let hour = Calendar.current.component(.hour, from: now)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation { proxy.scrollTo("hour_\(max(0, hour-1))", anchor: .top) }
        }
    }

    // MARK: - Context Menu Actions

    private func duplicateEvent(_ event: CalendarEvent) async {
        let duration = event.endDate.timeIntervalSince(event.startDate)
        let newStart = event.startDate.addingTimeInterval(3600) // +1 ora
        let newEnd = newStart.addingTimeInterval(duration)

        let duplicated = CalendarEvent(
            id: nil, // Nuovo ID
            title: "\(event.title) (copia)",
            description: event.description,
            startDate: newStart,
            endDate: newEnd,
            location: event.location,
            isAllDay: event.isAllDay,
            recurrenceRule: event.recurrenceRule,
            attendees: event.attendees,
            calendarId: event.calendarId,
            url: event.url,
            providerId: nil, // Nuovo evento
            providerType: event.providerType,
            lastModified: Date()
        )

        do {
            let request = CalendarEventRequest(
                title: duplicated.title,
                description: duplicated.description,
                startDate: duplicated.startDate,
                endDate: duplicated.endDate,
                location: duplicated.location,
                isAllDay: duplicated.isAllDay,
                attendeeEmails: duplicated.attendees.map { $0.email },
                calendarId: duplicated.calendarId
            )
            _ = try await calendarManager.createEvent(request)
        } catch {
            calendarManager.error = "Errore duplicazione evento: \(error.localizedDescription)"
        }
    }

    private func moveToTomorrow(_ event: CalendarEvent) async {
        let duration = event.endDate.timeIntervalSince(event.startDate)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: event.startDate) ?? event.startDate
        let newStart = Calendar.current.startOfDay(for: tomorrow).addingTimeInterval(
            TimeInterval(Calendar.current.component(.hour, from: event.startDate) * 3600 +
                         Calendar.current.component(.minute, from: event.startDate) * 60)
        )
        let newEnd = newStart.addingTimeInterval(duration)

        let moved = CalendarEvent(
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
            lastModified: Date()
        )

        do {
            try await calendarManager.updateEvent(moved)
        } catch {
            calendarManager.error = "Errore spostamento evento: \(error.localizedDescription)"
        }
    }

    private func deleteEvent(_ event: CalendarEvent) async {
        do {
            try await calendarManager.deleteEvent(event.id ?? "")
        } catch {
            calendarManager.error = "Errore eliminazione evento: \(error.localizedDescription)"
        }
    }
}

// MARK: - Drop Delegate for moving events via system drag & drop
import UniformTypeIdentifiers

private struct TimelineDropDelegate: DropDelegate {
    let calendarManager: CalendarManager
    let selectedDate: Date
    let hourHeight: CGFloat

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [UTType.text]).first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
            guard let data = item as? Data, let key = String(data: data, encoding: .utf8) ?? (item as? String) else { return }
            Task { @MainActor in
                guard let event = calendarManager.eventForKey(key) else { return }
                let location = info.location
                let minutes = clamp(locationY: location.y)
                let snapped = snap(minutes: minutes)
                let duration = Int(event.endDate.timeIntervalSince(event.startDate) / 60)
                let newStart = dateFromMinutes(snapped)
                let newEnd = dateFromMinutes(snapped + duration)
                let updated = CalendarEvent(
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
                    lastModified: Date()
                )
                try? await calendarManager.updateEvent(updated)
            }
        }
        return true
    }

    // Helpers use same logic as DayTimelineView
    private func clamp(locationY: CGFloat) -> Int {
        let minutes = Int((locationY / hourHeight) * 60)
        return max(0, min(24 * 60, minutes))
    }
    private func snap(minutes: Int) -> Int {
        let step = 15
        let rem = minutes % step
        if abs(rem) < step/2 { return minutes - rem }
        return minutes + (minutes > 0 ? (step - rem) : -(step + rem))
    }
    private func dateFromMinutes(_ minutes: Int) -> Date {
        let start = Calendar.current.startOfDay(for: selectedDate)
        return start.addingTimeInterval(TimeInterval(minutes * 60))
    }
}
