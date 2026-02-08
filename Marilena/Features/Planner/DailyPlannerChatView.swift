#if false
import SwiftUI
import CoreData
import Combine
import UserNotifications

struct DailyPlannerChatView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var calendarManager: CalendarManager

    private let chat: ChatMarilena
    @StateObject private var plannerService: DailyPlannerChatService

    @State private var showingPomodoroSheet = false
    @State private var showingEventSheet = false
    @State private var showingSummaryToast = false
    @State private var toastMessage = ""

    @State private var pomodoroTitle = ""
    @State private var focusMinutes = PlannerPreferences.shared.focusDurationMinutes
    @State private var breakMinutes = PlannerPreferences.shared.breakDurationMinutes

    @State private var eventTitle = ""
    @State private var eventDuration = 60
    @State private var eventStart = Date()
    @State private var timelineReferenceDate = Date()
    @State private var showingTimelineSheet = false
    @State private var handledTimelineContextID: UUID?
    @State private var showingEventDetail = false
    @State private var selectedEventId: String?
    @State private var showingPomodoroFullscreen = false
    @State private var currentTime = Date()
    @State private var timeUpdateCancellable: AnyCancellable?

    init(chat: ChatMarilena) {
        self.chat = chat
        let context = chat.managedObjectContext ?? PersistenceController.shared.container.viewContext
        _plannerService = StateObject(wrappedValue: DailyPlannerChatService(context: context))
    }

    var body: some View {
        let handler = PlannerChatToolHandler(
            service: plannerService,
            calendarManager: calendarManager,
            context: viewContext,
            onEventCreated: { eventId in
                selectedEventId = eventId
                showingEventDetail = true
            }
        )

        VStack(spacing: 0) {
            // Barra Pomodoro in alto
            if let pomodoroState = plannerService.pomodoroState {
                PomodoroTopBar(
                    state: pomodoroState,
                    currentTime: currentTime,
                    onTap: { showingPomodoroFullscreen = true },
                    onStop: { plannerService.stopPomodoroSession(manual: true) }
                )
            }

            // Chat principale
            ModularChatView(
                chat: chat,
                title: chat.titolo ?? "Pianificazione",
                showSettings: false,
                toolHandler: handler,
                calendarManager: calendarManager
            )
        }
            .onAppear {
                UserDefaults.standard.set(true, forKey: "use_responses_api")
                UserDefaults.standard.set(true, forKey: "enable_responses_streaming")
                Task {
                    await prepareChat()
                }
                startTimeUpdater()
            }
            .onDisappear {
                stopTimeUpdater()
            }
            .onReceive(plannerService.$timelineContext.compactMap { $0 }) { (context: DailyPlannerChatService.PlannerTimelineContext) in
                guard context.scope == .daily else { return }
                guard context.id != handledTimelineContextID else { return }
                handledTimelineContextID = context.id
                presentTimeline(for: context.scope, reference: context.referenceDate)
            }
            .onReceive(plannerService.$pomodoroState) { newState in
                if newState != nil {
                    showingPomodoroFullscreen = true
                } else {
                    showingPomodoroFullscreen = false
                }
            }
            .sheet(isPresented: $showingPomodoroSheet) {
                PomodoroComposer(
                    title: $pomodoroTitle,
                    focusMinutes: $focusMinutes,
                    breakMinutes: $breakMinutes,
                    onConfirm: startPomodoro
                )
            }
            .sheet(isPresented: $showingEventSheet) {
                CalendarEventComposer(
                    title: $eventTitle,
                    durationMinutes: $eventDuration,
                    startDate: $eventStart,
                    onConfirm: addCalendarEvent
                )
            }
            .sheet(isPresented: $showingTimelineSheet) {
                NavigationStack {
                    PlannerEventTimelineView(
                        referenceDate: timelineReferenceDate,
                        calendarManager: calendarManager
                    )
                    .navigationTitle("Piano giornaliero")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Chiudi") { showingTimelineSheet = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingEventDetail) {
                if let eventId = selectedEventId {
                    let calendarService = NewCalendarService(calendarManager: calendarManager)
                    EventDetailView(calendarService: calendarService)
                        .onAppear {
                            calendarService.openEventDetails(eventId: eventId)
                        }
                }
            }
            .fullScreenCover(isPresented: $showingPomodoroFullscreen) {
                PomodoroFullscreenView(
                    service: plannerService,
                    onStop: {
                        plannerService.stopPomodoroSession(manual: true)
                        showingPomodoroFullscreen = false
                    },
                    onDismiss: {
                        showingPomodoroFullscreen = false
                    }
                )
                .onReceive(plannerService.$pomodoroState) { newState in
                    if newState == nil { showingPomodoroFullscreen = false }
                }
                .onAppear {
                    #if canImport(UIKit)
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    #endif
                }
            }
            .toast(isPresented: $showingSummaryToast) {
                Label(toastMessage.isEmpty ? "Operazione completata" : toastMessage, systemImage: "sparkles")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
            }
    }

    private var plannerActions: [ChatQuickAction] {
        [
            ChatQuickAction(title: "Aggiorna riepilogo", systemIcon: "arrow.clockwise") { self.refreshSnapshot() },
            ChatQuickAction(title: "Agenda di oggi", systemIcon: "list.bullet") { self.showTodaySummary() },
            ChatQuickAction(title: "Panoramica settimana", systemIcon: "calendar") { self.planCurrentWeek() },
            ChatQuickAction(title: "Panoramica mese", systemIcon: "calendar.badge.clock") { self.planCurrentMonth() },
            ChatQuickAction(title: "Report progressi", systemIcon: "chart.bar") { Task { await self.generateProgressReport() } },
            ChatQuickAction(title: "Inizia Pomodoro", systemIcon: "timer") {
                dismissKeyboard()
                self.showingPomodoroSheet = true
            },
            ChatQuickAction(title: "Aggiungi evento", systemIcon: "calendar.badge.plus") {
                dismissKeyboard()
                self.showingEventSheet = true
            }
        ]
    }

    private var todayEvents: [CalendarEvent] {
        calendarManager.events.filter { Calendar.current.isDate($0.startDate, inSameDayAs: Date()) }
    }

    private func prepareChat() async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfRange = calendar.date(byAdding: .day, value: 7, to: startOfDay) ?? Date()
        await calendarManager.loadEvents(from: startOfDay, to: endOfRange)
        await plannerService.ensureDailyPlannerChat(for: Date(), events: calendarManager.events)
    }

    private func refreshSnapshot() {
        Task {
            await plannerService.refreshSuggestions()
            appendSnapshotMessage()
            showToast("Riepilogo aggiornato")
        }
    }

    private func showTodaySummary() {
        appendSnapshotMessage()
        showToast("Agenda aggiornata")
        presentTimeline(for: .daily, reference: Date())
    }

    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    private func appendSnapshotMessage() {
        let currentChat = plannerService.todayChat ?? chat
        let events = calendarManager.events.filter { Calendar.current.isDate($0.startDate, inSameDayAs: Date()) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.timeStyle = .short
        let eventsList = events.map { "- \(formatter.string(from: $0.startDate)) · \($0.title)" }.joined(separator: "\n")
        var message = "Ecco l'agenda aggiornata di oggi:\n\n"
        message += eventsList.isEmpty ? "Nessun evento registrato." : eventsList
        if !plannerService.suggestions.isEmpty {
            message += "\n\nSuggerimenti dalle email:"
            for suggestion in plannerService.suggestions {
                message += "\n• \(suggestion.title): \(suggestion.summary)"
            }
        }
        plannerService.appendAssistantMessage(message, in: currentChat, type: "planning_summary")
    }

    private func planCurrentWeek() {
        Task {
            let now = Date()
            let range = plannerService.plannerRange(for: .weekly, reference: now)
            await plannerService.refreshSuggestions()
            await calendarManager.loadEvents(from: range.start, to: range.end)
            let events = calendarManager.events.filter { range.contains($0.startDate) }
            let currentChat = plannerService.todayChat ?? chat
            await plannerService.appendOverview(
                for: .weekly,
                range: range,
                events: events,
                suggestions: plannerService.suggestions,
                calendarManager: calendarManager,
                in: currentChat
            )
            showToast("Panoramica settimanale pronta")
        }
    }

    private func planCurrentMonth() {
        Task {
            let now = Date()
            let range = plannerService.plannerRange(for: .monthly, reference: now)
            await plannerService.refreshSuggestions()
            await calendarManager.loadEvents(from: range.start, to: range.end)
            let events = calendarManager.events.filter { range.contains($0.startDate) }
            let currentChat = plannerService.todayChat ?? chat
            await plannerService.appendOverview(
                for: .monthly,
                range: range,
                events: events,
                suggestions: plannerService.suggestions,
                calendarManager: calendarManager,
                in: currentChat
            )
            showToast("Panoramica mensile pronta")
        }
    }

    private func generateProgressReport() async {
        let currentChat = plannerService.todayChat ?? chat
        let result = await plannerService.handlePlannerReport(
            referenceDate: Date(),
            chat: currentChat,
            calendarManager: calendarManager
        )
        showToast(result.response)
    }

    private func showToast(_ message: String) {
        toastMessage = message
        showingSummaryToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showingSummaryToast = false
        }
    }

    private func presentTimeline(for scope: DailyPlannerChatService.PlannerScope, reference: Date) {
        guard scope == .daily else { return }
        timelineReferenceDate = Calendar.current.startOfDay(for: reference)
        showingTimelineSheet = true
    }

    private func startPomodoro() {
        showingPomodoroSheet = false
        let currentChat = plannerService.todayChat ?? chat
        let sanitizedTitle = pomodoroTitle.isEmpty ? "Sessione di focus" : pomodoroTitle

        Task {
            do {
                let result = try await plannerService.startPomodoroSession(
                    title: sanitizedTitle,
                    focusMinutes: focusMinutes,
                    breakMinutes: breakMinutes,
                    calendarManager: calendarManager,
                    chat: currentChat
                )
                showToast(result.response)
            } catch {
                plannerService.appendAssistantMessage("Non sono riuscita a creare il Pomodoro nel calendario (\(error.localizedDescription)).", in: currentChat, type: "planning_error")
            }
        }
    }

    private func addCalendarEvent() {
        showingEventSheet = false
        let currentChat = plannerService.todayChat ?? chat
        let sanitizedTitle = eventTitle.isEmpty ? "Attività pianificata" : eventTitle
        let end = eventStart.addingTimeInterval(TimeInterval(eventDuration * 60))
        let request = CalendarEventRequest(
            title: sanitizedTitle,
            description: "Inserito da Marilena Planner",
            startDate: eventStart,
            endDate: end,
            location: nil,
            isAllDay: false,
            attendeeEmails: [],
            calendarId: nil
        )

        Task {
            do {
                _ = try await calendarManager.createEvent(request)
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "it_IT")
                formatter.timeStyle = .short
                plannerService.appendAssistantMessage("Evento aggiunto alle \(formatter.string(from: eventStart)): **\(sanitizedTitle)**.", in: currentChat, type: "planning_event")
            } catch {
                plannerService.appendAssistantMessage("Non sono riuscita a salvare l'evento (\(error.localizedDescription)).", in: currentChat, type: "planning_error")
            }
        }
    }

    // MARK: - Time Updater

    private func startTimeUpdater() {
        timeUpdateCancellable = Timer.publish(every: 1, on: .main, in: .common)
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

// MARK: - Pomodoro Top Bar

private struct PomodoroTopBar: View {
    let state: DailyPlannerChatService.PomodoroState
    let currentTime: Date
    let onTap: () -> Void
    let onStop: () -> Void

    private var remaining: TimeInterval {
        state.remainingTime(at: currentTime)
    }

    private var progress: Double {
        state.progress(at: currentTime)
    }

    private var phaseColor: Color {
        state.phase == .focus ? .red : (state.phase == .breakTime ? .blue : .green)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icona fase
                Image(systemName: state.phase == .focus ? "brain.head.profile" : "cup.and.saucer.fill")
                    .font(.body.bold())
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating, isActive: true)

                // Timer
                Text(timeString(from: remaining))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                // Titolo
                Text(state.title)
                    .font(.body.bold())
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)

                Spacer()

                // Progress percentage
                Text("\(Int(progress * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.8))

                // Stop button
                Button(action: onStop) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                ZStack(alignment: .leading) {
                    // Background gradient
                    LinearGradient(
                        colors: state.phase == .focus ?
                            [Color.red, Color.orange] :
                            [Color.blue, Color.cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )

                    // Progress overlay
                    LinearGradient(
                        colors: state.phase == .focus ?
                            [Color.red.opacity(0.7), Color.orange.opacity(0.7)] :
                            [Color.blue.opacity(0.7), Color.cyan.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .opacity(0.5)
                    .frame(maxWidth: .infinity)
                    .frame(width: UIScreen.main.bounds.width * CGFloat(progress))
                }
            )
            .shadow(color: phaseColor.opacity(0.4), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func timeString(from interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: interval) ?? "--:--"
    }
}

private struct PomodoroComposer: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var title: String
    @Binding var focusMinutes: Int
    @Binding var breakMinutes: Int
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header con icona
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.red.opacity(0.8), Color.orange.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .shadow(color: .red.opacity(0.3), radius: 15, y: 5)

                            Image(systemName: "timer")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundStyle(.white)
                        }

                        Text("Nuovo Pomodoro")
                            .font(.title.bold())

                        Text("Configura la tua sessione di focus")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)

                    // Card Attività
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Attività", systemImage: "target")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        TextField("Su cosa vuoi concentrarti?", text: $title)
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                    }
                    .padding(20)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 2)

                    // Card Durata Focus
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Durata Focus", systemImage: "brain.head.profile")
                            .font(.headline)
                            .foregroundStyle(.red)

                        VStack(spacing: 8) {
                            Text("\(focusMinutes)")
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.red, .orange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )

                            Text("minuti")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)

                        HStack(spacing: 12) {
                            ForEach([15, 25, 45, 60], id: \.self) { duration in
                                Button {
                                    focusMinutes = duration
                                } label: {
                                    Text("\(duration)")
                                        .font(.body.bold())
                                        .foregroundStyle(focusMinutes == duration ? .white : .primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(focusMinutes == duration ? Color.red : Color(.tertiarySystemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }

                        Stepper("", value: $focusMinutes, in: 10...120, step: 5)
                            .labelsHidden()
                    }
                    .padding(20)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 2)

                    // Card Durata Pausa
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Durata Pausa", systemImage: "cup.and.saucer.fill")
                            .font(.headline)
                            .foregroundStyle(.blue)

                        VStack(spacing: 8) {
                            Text("\(breakMinutes)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.blue)

                            Text("minuti")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)

                        HStack(spacing: 12) {
                            ForEach([3, 5, 10, 15], id: \.self) { duration in
                                Button {
                                    breakMinutes = duration
                                } label: {
                                    Text("\(duration)")
                                        .font(.body.bold())
                                        .foregroundStyle(breakMinutes == duration ? .white : .primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(breakMinutes == duration ? Color.blue : Color(.tertiarySystemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }

                        Stepper("", value: $breakMinutes, in: 3...30, step: 1)
                            .labelsHidden()
                    }
                    .padding(20)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 2)

                    // Pulsante Avvia
                    Button {
                        PlannerPreferences.shared.saveFocusDurations(focus: focusMinutes, pause: breakMinutes)
                        onConfirm()
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "play.fill")
                                .font(.headline)
                            Text("Avvia Pomodoro")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.red, Color.orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .red.opacity(0.3), radius: 10, y: 4)
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Tool Handler

final class PlannerChatToolHandler: ChatToolHandler {
    private weak var service: DailyPlannerChatService?
    private weak var calendarManager: CalendarManager?
    private let context: NSManagedObjectContext
    private let onEventCreated: (String) -> Void
    var onUIAction: ((ToolUIAction) -> Void)?

    init(
        service: DailyPlannerChatService,
        calendarManager: CalendarManager,
        context: NSManagedObjectContext,
        onEventCreated: @escaping (String) -> Void
    ) {
        self.service = service
        self.calendarManager = calendarManager
        self.context = context
        self.onEventCreated = onEventCreated
    }

    var toolDefinitions: [AIToolDefinition] {
        PlannerToolRegistry.shared.toolDefinitions()
    }

    func handleToolCalls(_ toolCalls: [MessageToolCall], chat: ChatMarilena) async -> [ToolExecutionResult] {
        guard let service, let calendarManager else {
            print("🔧 [PlannerToolHandler] Service or CalendarManager not available")
            return []
        }

        print("🔧 [PlannerToolHandler] Handling \(toolCalls.count) tool calls")
        var executions: [ToolExecutionResult] = []
        for call in toolCalls where call.isCompleted {
            guard let name = call.name else {
                print("🔧 [PlannerToolHandler] Skipping tool call with no name")
                continue
            }
            print("🔧 [PlannerToolHandler] Executing tool: \(name)")
            print("🔧 [PlannerToolHandler] Arguments: \(call.arguments)")
            do {
                let result = try await service.performToolCall(
                    name: name,
                    arguments: call.arguments,
                    chat: chat,
                    calendarManager: calendarManager
                )
                print("🔧 [PlannerToolHandler] Tool \(name) completed: \(result.response)")

                // Se è stato creato un evento, apri il detail
                if name == PlannerToolName.createEvent.rawValue,
                   let eventId = result.payload?.string(for: "event_id"),
                   !eventId.isEmpty {
                    await MainActor.run {
                        // Ricarica gli eventi dal calendario
                        Task {
                            await calendarManager.loadEvents(from: Date().addingTimeInterval(-86400), to: Date().addingTimeInterval(86400 * 7))
                            // Aspetta un attimo per dare tempo al calendario di aggiornare
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 secondi
                            onEventCreated(eventId)
                        }
                    }
                }

                executions.append(
                    ToolExecutionResult(
                        callId: call.id,
                        name: name,
                        output: result.response
                    )
                )
            } catch {
                print("🔧 [PlannerToolHandler] Tool \(name) failed: \(error)")
                await MainActor.run {
                    service.appendAssistantMessage(
                        "❌ Errore esecuzione tool \(name): \(error.localizedDescription)",
                        in: chat,
                        type: "planning_error"
                    )
                }
                executions.append(
                    ToolExecutionResult(
                        callId: call.id,
                        name: name,
                        output: "❌ Errore esecuzione tool \(name): \(error.localizedDescription)"
                    )
                )
            }
        }

        return executions
    }
}

private struct CalendarEventComposer: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var title: String
    @Binding var durationMinutes: Int
    @Binding var startDate: Date
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Dettagli") {
                    TextField("Titolo", text: $title)
                    DatePicker("Inizio", selection: $startDate)
                    Stepper(value: $durationMinutes, in: 15...240, step: 15) {
                        Text("Durata: \(durationMinutes) min")
                    }
                }
            }
            .navigationTitle("Nuovo evento")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        onConfirm()
                        dismiss()
                    }
                }
            }
        }
    }
}

// Basic toast modifier for quick feedback
private extension View {
    func toast<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        ZStack(alignment: .top) {
            self
            if isPresented.wrappedValue {
                content()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
                    .padding(.top, 80)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isPresented.wrappedValue)
    }
}
#endif
