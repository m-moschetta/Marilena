import SwiftUI

struct DayTimelineView: View {
    @ObservedObject var calendarManager: CalendarManager
    @State var selectedDate: Date
    @State private var draggingEventID: String?
    @State private var resizingEventID: String?
    @State private var scrollToNow: Bool = true
    private let leftGutter: CGFloat = 54 // hour label + spacing
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

    @State private var hourHeight: CGFloat = 64
    @State private var hourHeightBase: CGFloat = 64
    private let minDurationMinutes = 15

    init(calendarManager: CalendarManager, date: Date = Date()) {
        self.calendarManager = calendarManager
        self._selectedDate = State(initialValue: Calendar.current.startOfDay(for: date))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            allDayBar
            Divider()
            timeline
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
        // Horizontal swipe between days without blocking vertical scroll/gestures
        .simultaneousGesture(daySwipeGesture())
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var allDayBar: some View {
        let allDay = dayEvents.filter { $0.isAllDay }
        return Group {
            if !allDay.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(allDay, id: \.id) { ev in
                            HStack(spacing: 6) {
                                Button(action: {
                                    let wasCompleted = calendarManager.isCompleted(ev)
                                    if wasCompleted { Haptics.selection() } else { Haptics.success() }
                                    calendarManager.toggleCompleted(ev)
                                }) {
                                    Image(systemName: calendarManager.isCompleted(ev) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .frame(width: 32, height: 32)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Text(ev.title).lineLimit(1)
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }
            }
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
                                hourHeight = clampHourHeight(hourHeightBase * scale)
                            }
                            .onEnded { _ in
                                hourHeightBase = hourHeight
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
                        .font(.caption)
                        .frame(width: 40, alignment: .trailing)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 6)
                    Rectangle().fill(Color(.separator)).frame(height: 0.5)
                }
                .frame(height: hourHeight, alignment: .top)
                .id("hour_\(hour)")
            }
        }
        .padding(.leading, 8)
    }

    private func eventsOverlay(width: CGFloat) -> some View {
        let nonAllDay = dayEvents.filter { !$0.isAllDay }
        let placed = placeEvents(nonAllDay)
        return ZStack(alignment: .topLeading) {
            ForEach(placed.indices, id: \.self) { idx in
                let item = placed[idx]
                let frame = frameFor(event: item.event, dayWidth: width - (leftGutter + 12), columns: item.totalColumns, column: item.column)
                eventBlock(item.event, totalColumns: item.totalColumns)
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
        let y = CGFloat(minutes) / 60.0 * hourHeight
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
        let baseColor = colorFor(event: ev) ?? Color.blue
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
                            .font(.title3)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Text(ev.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    if totalColumns > 1 {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                Text("\(timeString(ev.startDate)) – \(timeString(ev.endDate))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
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
        .gesture(dragGesture(ev: ev))
        .onDrag {
            Haptics.impactLight()
            return NSItemProvider(object: NSString(string: calendarManager.eventKey(for: ev)))
        }
        .onTapGesture {
            selectedEvent = ev
            showingEdit = true
        }
    }

    // MARK: - Selection overlay & gesture
    private func selectionOverlay() -> some View {
        guard isSelecting, let s = selectStartMin, let e = selectEndMin else { return AnyView(EmptyView()) }
        let start = CGFloat(min(s, e))
        let end = CGFloat(max(s, e))
        let y = (start / 60.0) * hourHeight
        let h = max(8, ((end - start) / 60.0) * hourHeight)
        return AnyView(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.accentColor.opacity(0.15))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1, dash: [4,3])))
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

    // MARK: - Gestures

    private func dragGesture(ev: CalendarEvent) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if draggingEventID == nil { Haptics.impactLight() }
                draggingEventID = ev.id ?? ev.providerId
            }
            .onEnded { value in
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
                Task { try? await calendarManager.updateEvent(updated) }
            }
    }

    private func resizeGesture(ev: CalendarEvent, isTop: Bool) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { _ in
                if resizingEventID == nil { Haptics.impactLight() }
                resizingEventID = ev.id ?? ev.providerId
            }
            .onEnded { value in
                resizingEventID = nil
                let minutesDelta = Int((value.translation.height / hourHeight) * 60)
                if minutesDelta == 0 { return }
                let snapped = snapMinutes(minutesDelta)
                var newStart = ev.startDate
                var newEnd = ev.endDate
                if isTop {
                    newStart = ev.startDate.addingTimeInterval(TimeInterval(snapped * 60))
                    if newStart >= newEnd { newStart = newEnd.addingTimeInterval(-TimeInterval(minDurationMinutes * 60)) }
                } else {
                    newEnd = ev.endDate.addingTimeInterval(TimeInterval(snapped * 60))
                    if newEnd <= newStart { newEnd = newStart.addingTimeInterval(TimeInterval(minDurationMinutes * 60)) }
                }
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
                Task { try? await calendarManager.updateEvent(updated) }
            }
    }

    // MARK: - Layout helpers

    private struct Placed {
        let event: CalendarEvent
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
        let y = (minutesFromStart / 60.0) * hourHeight
        let h = (minutesLength / 60.0) * hourHeight
        return CGRect(x: x, y: y, width: fractionWidth - 5, height: max(h, 24))
    }

    // MARK: - Utils

    private var dayEvents: [CalendarEvent] {
        calendarManager.events.filter { Calendar.current.isDate($0.startDate, inSameDayAs: selectedDate) || Calendar.current.isDate($0.endDate, inSameDayAs: selectedDate) || ($0.startDate < selectedDate && $0.endDate > selectedDate) }
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
        case .eventKit: return Color.blue
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
