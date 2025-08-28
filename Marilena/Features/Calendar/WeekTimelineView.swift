import SwiftUI
import UniformTypeIdentifiers

struct WeekTimelineView: View {
    @ObservedObject var calendarManager: CalendarManager
    @State var weekStart: Date
    @State private var hourHeight: CGFloat = 56
    @State private var hourHeightBase: CGFloat = 56
    private let leftGutter: CGFloat = 54
    @State private var selectedEvent: CalendarEvent? = nil
    @State private var showingEdit: Bool = false
    @State private var showingCreateSheet: Bool = false
    @State private var createStart: Date = Date()
    @State private var createEnd: Date = Date().addingTimeInterval(3600)

    init(calendarManager: CalendarManager, referenceDate: Date = Date()) {
        self.calendarManager = calendarManager
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: referenceDate)
        let week = cal.dateInterval(of: .weekOfYear, for: startOfDay)!
        self._weekStart = State(initialValue: week.start)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            timeline
        }
        .task { await reloadWeek() }
        // Use simultaneous gesture so vertical scrolling and drags aren't blocked
        .simultaneousGesture(weekSwipeGesture())
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { scale in hourHeight = clampHourHeight(hourHeightBase * scale) }
                .onEnded { _ in hourHeightBase = hourHeight }
        )
        .sheet(isPresented: $showingEdit) {
            if let ev = selectedEvent {
                EventEditView(calendarManager: calendarManager, event: ev)
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateEventView(calendarManager: calendarManager, suggestedStart: createStart, suggestedEnd: createEnd)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button { shiftWeek(-1) } label: { Image(systemName: "chevron.left") }
            Spacer(minLength: 6)
            Text(weekTitle)
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 6)
            Button { shiftWeek(1) } label: { Image(systemName: "chevron.right") }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var timeline: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    ZStack(alignment: .topLeading) {
                        hoursGrid(height: hourHeight * 24)
                        daysColumns(width: geo.size.width)
                        nowIndicator(width: geo.size.width)
                    }
                    .frame(height: hourHeight * 24)
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
            }
        }
        .padding(.leading, 8)
    }

    private func daysColumns(width: CGFloat) -> some View {
        let colWidth = (width - (leftGutter + 8)) / 7.0
        return ZStack(alignment: .topLeading) {
            // day separators
            ForEach(0..<7, id: \.self) { i in
                let x = leftGutter + CGFloat(i) * colWidth
                Rectangle().fill(Color(.separator).opacity(0.6)).frame(width: 0.5)
                    .offset(x: x)
            }
            // events per day
            ForEach(0..<7, id: \.self) { i in
                let day = Calendar.current.date(byAdding: .day, value: i, to: weekStart)!
                let evs = events(for: day).filter { !$0.isAllDay }
                let placed = placeEvents(evs, for: day)
                ForEach(placed.indices, id: \.self) { idx in
                    let item = placed[idx]
                    let frame = frameFor(event: item.event, day: day, dayWidth: colWidth, columns: item.totalColumns, column: item.column)
                    DayEventBlock(event: item.event, totalColumns: item.totalColumns, manager: calendarManager) {
                        selectedEvent = item.event
                        showingEdit = true
                    }
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.minX + frame.width/2, y: frame.minY + frame.height/2)
                }
            }
        }
        .padding(.leading, leftGutter)
        .padding(.trailing, 8)
        .coordinateSpace(name: "weekArea")
        .onDrop(of: [UTType.text], delegate: WeekTimelineDropDelegate(calendarManager: calendarManager, weekStart: weekStart, hourHeight: hourHeight, leftGutter: leftGutter, totalWidth: width))
        .overlay(
            LongPressLocationOverlay(minimumPressDuration: 0.4) { p in
                // Quick-create on empty long press: compute day column and minute
                let dayIndex = computeDayIndex(totalWidth: width, x: p.x)
                let minutes = clamp(locationY: p.y, hourHeight: hourHeight)
                let snapped = snap(minutes: minutes)
                createStart = dateFrom(weekStart: weekStart, dayIndex: dayIndex, minutes: snapped)
                createEnd = dateFrom(weekStart: weekStart, dayIndex: dayIndex, minutes: snapped + CalendarPreferences.defaultDurationMinutes)
                showingCreateSheet = true
            }
        )
    }

    private func nowIndicator(width: CGFloat) -> some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekRange = cal.dateInterval(of: .weekOfYear, for: weekStart)!
        guard weekRange.contains(today) else { return AnyView(EmptyView()) }
        let minutes = max(0, min(24*60, Int(Date().timeIntervalSince(today) / 60)))
        let y = CGFloat(minutes) / 60.0 * hourHeight
        // vertical span across the 7 columns
        return AnyView(
            Rectangle()
                .fill(Color.red)
                .frame(height: 2)
                .offset(x: leftGutter + 4, y: y)
        )
    }

    private func frameFor(event ev: CalendarEvent, day: Date, dayWidth: CGFloat, columns: Int, column: Int) -> CGRect {
        let fractionWidth = dayWidth / CGFloat(max(1, columns))
        let x = CGFloat(column) * fractionWidth + CGFloat(Calendar.current.component(.weekday, from: day) - 1) * dayWidth
        let minutesFromStart = CGFloat(minutesSinceStartOfDay(ev.startDate))
        let minutesLength = CGFloat(max(10, minutesBetween(ev.startDate, ev.endDate)))
        let y = (minutesFromStart / 60.0) * hourHeight
        let h = (minutesLength / 60.0) * hourHeight
        return CGRect(x: x, y: y, width: fractionWidth - 5, height: max(h, 24))
    }

    private func events(for day: Date) -> [CalendarEvent] {
        calendarManager.events.filter { Calendar.current.isDate($0.startDate, inSameDayAs: day) || Calendar.current.isDate($0.endDate, inSameDayAs: day) || ($0.startDate < day && $0.endDate > day) }
    }

    private struct Placed { let event: CalendarEvent; let column: Int; let totalColumns: Int }

    private func placeEvents(_ events: [CalendarEvent], for day: Date) -> [Placed] {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
        let clamped = events.map { ev in
            let s = max(ev.startDate, dayStart)
            let e = min(ev.endDate, dayEnd)
            return CalendarEvent(id: ev.id, title: ev.title, description: ev.description, startDate: s, endDate: e, location: ev.location, isAllDay: ev.isAllDay, recurrenceRule: ev.recurrenceRule, attendees: ev.attendees, calendarId: ev.calendarId, url: ev.url, providerId: ev.providerId, providerType: ev.providerType, lastModified: ev.lastModified)
        }.sorted { a, b in
            if a.startDate == b.startDate { return a.endDate < b.endDate }
            return a.startDate < b.startDate
        }
        var result: [Placed] = []
        var i = 0
        while i < clamped.count {
            var cluster: [CalendarEvent] = [clamped[i]]
            var clusterEnd = clamped[i].endDate
            var j = i + 1
            while j < clamped.count {
                if clamped[j].startDate < clusterEnd {
                    cluster.append(clamped[j])
                    clusterEnd = max(clusterEnd, clamped[j].endDate)
                    j += 1
                } else { break }
            }
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
                if columns[idx].last!.endDate <= ev.startDate {
                    columns[idx].append(ev); placed = true; break
                }
            }
            if !placed { columns.append([ev]) }
        }
        let total = max(1, columns.count)
        var out: [Placed] = []
        for (idx, col) in columns.enumerated() { for ev in col { out.append(Placed(event: ev, column: idx, totalColumns: total)) } }
        return out
    }

    private func minutesSinceStartOfDay(_ date: Date) -> Int {
        let start = Calendar.current.startOfDay(for: date)
        return max(0, Int(date.timeIntervalSince(start) / 60))
    }
    private func minutesBetween(_ a: Date, _ b: Date) -> Int { max(1, Int(b.timeIntervalSince(a) / 60)) }

    private var weekTitle: String {
        let cal = Calendar.current
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .none
        let end = cal.date(byAdding: .day, value: 6, to: weekStart)!
        return df.string(from: weekStart) + " – " + df.string(from: end)
    }

    private func shiftWeek(_ delta: Int) {
        if let d = Calendar.current.date(byAdding: .day, value: delta * 7, to: weekStart) { weekStart = d }
        Task { await reloadWeek() }
    }

    private func reloadWeek() async {
        let end = Calendar.current.date(byAdding: .day, value: 7, to: weekStart)!
        await calendarManager.loadEvents(from: weekStart, to: end)
    }

    private func weekSwipeGesture() -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                // Avoid horizontal swipe if the gesture was mostly vertical (scroll)
                guard abs(dx) > 80, abs(dx) > abs(dy) else { return }
                withAnimation(.easeOut(duration: 0.2)) { shiftWeek(dx < 0 ? 1 : -1) }
            }
    }
}

private struct DayEventBlock: View {
    let event: CalendarEvent
    let totalColumns: Int
    @ObservedObject var manager: CalendarManager
    var onTap: () -> Void

    var body: some View {
        let isCompleted = manager.isCompleted(event)
        let baseColor = colorFor(event: event) ?? Color.blue
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
                        let wasCompleted = manager.isCompleted(event)
                        if wasCompleted { Haptics.selection() } else { Haptics.success() }
                        manager.toggleCompleted(event)
                    }) {
                        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isCompleted ? .green : baseColor)
                            .font(.title3)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Text(event.title).font(.caption.weight(.semibold)).lineLimit(1)
                    Spacer()
                    if totalColumns > 1 { Image(systemName: "exclamationmark.circle.fill").font(.caption).foregroundColor(.orange) }
                }
                Text("\(timeString(event.startDate)) – \(timeString(event.endDate))").font(.caption2).foregroundColor(.secondary)
            }
            .padding(8)
        }
        .onDrag {
            Haptics.impactLight()
            return NSItemProvider(object: NSString(string: manager.eventKey(for: event)))
        }
        .onTapGesture { onTap() }
    }

    private func timeString(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: date) }

    private func colorFor(event: CalendarEvent) -> Color? {
        if let calId = event.calendarId, let cal = manager.calendars.first(where: { $0.id == calId }) {
            if let c = Color(hex: cal.color) { return c }
        }
        switch event.providerType {
        case .eventKit: return Color.blue
        case .googleCalendar: return Color(red: 0.13, green: 0.52, blue: 0.96)
        case .microsoftGraph: return Color(red: 0.0, green: 0.46, blue: 0.85)
        }
    }
}

// MARK: - Drop Delegate for week view
private struct WeekTimelineDropDelegate: DropDelegate {
    let calendarManager: CalendarManager
    let weekStart: Date
    let hourHeight: CGFloat
    let leftGutter: CGFloat
    let totalWidth: CGFloat

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [UTType.text]).first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
            guard let data = item as? Data, let key = String(data: data, encoding: .utf8) ?? (item as? String) else { return }
            Task { @MainActor in
                guard let event = calendarManager.eventForKey(key) else { return }
                let loc = info.location
                let dayIndex = computeDayIndex(x: loc.x)
                let minutes = clamp(locationY: loc.y)
                let snapped = snap(minutes: minutes)
                let duration = Int(event.endDate.timeIntervalSince(event.startDate) / 60)
                let startDate = dateFrom(dayIndex: dayIndex, minutes: snapped)
                let endDate = dateFrom(dayIndex: dayIndex, minutes: snapped + duration)
                let updated = CalendarEvent(
                    id: event.id,
                    title: event.title,
                    description: event.description,
                    startDate: startDate,
                    endDate: endDate,
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

    // Helpers
    private func computeDayIndex(x: CGFloat) -> Int {
        let workingWidth = totalWidth - (leftGutter + 8)
        let colWidth = workingWidth / 7.0
        let idx = Int(floor((x - leftGutter) / colWidth))
        return max(0, min(6, idx))
    }
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
    private func dateFrom(dayIndex: Int, minutes: Int) -> Date {
        let day = Calendar.current.date(byAdding: .day, value: dayIndex, to: weekStart)!
        let start = Calendar.current.startOfDay(for: day)
        return start.addingTimeInterval(TimeInterval(minutes * 60))
    }
}
// Shared helpers for Week view
private func computeDayIndex(totalWidth: CGFloat, x: CGFloat, leftGutter: CGFloat = 54) -> Int {
    let workingWidth = totalWidth - (leftGutter + 8)
    let colWidth = workingWidth / 7.0
    let idx = Int(floor((x - leftGutter) / colWidth))
    return max(0, min(6, idx))
}
private func clamp(locationY: CGFloat, hourHeight: CGFloat = 56) -> Int {
    let minutes = Int((locationY / hourHeight) * 60)
    return max(0, min(24 * 60, minutes))
}
private func snap(minutes: Int) -> Int { let step = 15; let rem = minutes % step; if abs(rem) < step/2 { return minutes - rem }; return minutes + (minutes > 0 ? (step - rem) : -(step + rem)) }
private func clampHourHeight(_ value: CGFloat) -> CGFloat { min(120, max(36, value)) }
private func dateFrom(weekStart: Date, dayIndex: Int, minutes: Int) -> Date {
    let day = Calendar.current.date(byAdding: .day, value: dayIndex, to: weekStart)!
    let start = Calendar.current.startOfDay(for: day)
    return start.addingTimeInterval(TimeInterval(minutes * 60))
}
