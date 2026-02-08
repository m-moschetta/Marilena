import Foundation
import CoreData
import CoreLocation
import Combine

// MARK: - OpenClaw Context Provider
// Raccoglie e formatta dati contestuali da calendario, trascrizioni, reminder, posizione e profilo utente
// per passarli a OpenClaw come memoria RAG-like

/// Struttura per il contesto completo da passare a OpenClaw
struct OpenClawContext: Codable {
    let timestamp: Date
    let calendar: CalendarContext?
    let reminders: [ReminderContext]
    let transcriptions: [TranscriptionContext]
    let userProfile: UserProfileContext?
    let recentChats: [ChatContext]
    let location: LocationContext?

    /// Genera una rappresentazione testuale del contesto per il prompt
    func toPromptText() -> String {
        var sections: [String] = []

        // Calendario
        if let cal = calendar, !cal.todayEvents.isEmpty || !cal.upcomingEvents.isEmpty || cal.currentEvent != nil {
            var calSection = "## CALENDARIO\n"

            if let current = cal.currentEvent {
                calSection += "\n### In corso adesso:\n"
                calSection += "- \(current.title)"
                if let loc = current.location { calSection += " @ \(loc)" }
                calSection += " (fino alle \(formatTime(current.endDate)))\n"
                if !current.attendees.isEmpty {
                    calSection += "  Partecipanti: \(current.attendees.joined(separator: ", "))\n"
                }
            }

            if !cal.todayEvents.isEmpty {
                calSection += "\n### Eventi di oggi (\(formatDate(Date()))):\n"
                for event in cal.todayEvents.prefix(10) {
                    calSection += "- \(formatTime(event.startDate))-\(formatTime(event.endDate)): \(event.title)"
                    if let loc = event.location { calSection += " @ \(loc)" }
                    calSection += "\n"
                }
            }

            if !cal.upcomingEvents.isEmpty {
                calSection += "\n### Prossimi eventi:\n"
                for event in cal.upcomingEvents.prefix(5) {
                    calSection += "- \(formatDateTime(event.startDate)): \(event.title)\n"
                }
            }

            sections.append(calSection)
        }

        // Reminder/Promemoria
        if !reminders.isEmpty {
            var reminderSection = "## PROMEMORIA\n"

            let overdue = reminders.filter { $0.isOverdue }
            let pending = reminders.filter { !$0.isCompleted && !$0.isOverdue }

            if !overdue.isEmpty {
                reminderSection += "\n### In ritardo:\n"
                for reminder in overdue.prefix(5) {
                    reminderSection += "- ⚠️ \(reminder.title)"
                    if let dueDate = reminder.dueDate {
                        reminderSection += " (scaduto \(formatDateTime(dueDate)))"
                    }
                    reminderSection += "\n"
                }
            }

            if !pending.isEmpty {
                reminderSection += "\n### Da fare:\n"
                for reminder in pending.prefix(10) {
                    let priorityIcon = reminder.priority == "high" ? "🔴" : (reminder.priority == "medium" ? "🟡" : "")
                    reminderSection += "- \(priorityIcon) \(reminder.title)"
                    if let dueDate = reminder.dueDate {
                        reminderSection += " (entro \(formatDateTime(dueDate)))"
                    }
                    if let notes = reminder.notes, !notes.isEmpty {
                        reminderSection += "\n  Note: \(String(notes.prefix(100)))"
                    }
                    reminderSection += "\n"
                }
            }

            sections.append(reminderSection)
        }

        // Posizione attuale
        if let loc = location {
            var locSection = "## POSIZIONE ATTUALE\n"
            if let placeName = loc.placeName {
                locSection += "Luogo: \(placeName)\n"
            }
            if let address = loc.address {
                locSection += "Indirizzo: \(address)\n"
            }
            locSection += "Coordinate: \(String(format: "%.4f", loc.latitude)), \(String(format: "%.4f", loc.longitude))\n"
            locSection += "Aggiornato: \(formatTime(loc.timestamp))\n"
            sections.append(locSection)
        }

        // Trascrizioni recenti
        if !transcriptions.isEmpty {
            var transSection = "## TRASCRIZIONI RECENTI\n"
            for trans in transcriptions.prefix(3) {
                transSection += "\n### \(trans.title) (\(formatDateTime(trans.date)))\n"
                // Limita a 500 caratteri per trascrizione
                let preview = String(trans.text.prefix(500))
                transSection += preview
                if trans.text.count > 500 { transSection += "..." }
                transSection += "\n"
            }
            sections.append(transSection)
        }

        // Profilo utente
        if let profile = userProfile {
            var profileSection = "## PROFILO UTENTE\n"
            if let name = profile.name { profileSection += "Nome: \(name)\n" }
            if let context = profile.aiContext, !context.isEmpty {
                profileSection += "\nContesto personale:\n\(context)\n"
            }
            sections.append(profileSection)
        }

        // Chat recenti (riassunto)
        if !recentChats.isEmpty {
            var chatSection = "## CONVERSAZIONI RECENTI\n"
            for chat in recentChats.prefix(3) {
                chatSection += "- \(chat.title) (\(formatDate(chat.lastMessageDate))): \(chat.messageCount) messaggi\n"
                if let lastMsg = chat.lastMessagePreview {
                    chatSection += "  Ultimo: \"\(String(lastMsg.prefix(100)))...\"\n"
                }
            }
            sections.append(chatSection)
        }

        if sections.isEmpty {
            return ""
        }

        return "# CONTESTO MEMORIA MARILENA\n" +
               "Aggiornato: \(formatDateTime(timestamp))\n\n" +
               sections.joined(separator: "\n---\n\n")
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM HH:mm"
        return formatter.string(from: date)
    }
}

struct CalendarContext: Codable {
    let todayEvents: [EventContext]
    let upcomingEvents: [EventContext]
    let currentEvent: EventContext?
}

struct EventContext: Codable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let attendees: [String]
    let isAllDay: Bool
}

struct TranscriptionContext: Codable {
    let id: String
    let title: String
    let text: String
    let date: Date
    let duration: TimeInterval
    let language: String?
}

struct UserProfileContext: Codable {
    let name: String?
    let email: String?
    let aiContext: String?
    let totalChats: Int
    let totalMessages: Int
}

struct ChatContext: Codable {
    let id: String
    let title: String
    let messageCount: Int
    let lastMessageDate: Date
    let lastMessagePreview: String?
}

struct ReminderContext: Codable {
    let id: String
    let title: String
    let notes: String?
    let dueDate: Date?
    let priority: String // "high", "medium", "low", "none"
    let isCompleted: Bool
    let isOverdue: Bool
    let list: String?
}

struct LocationContext: Codable {
    let latitude: Double
    let longitude: Double
    let placeName: String?
    let address: String?
    let timestamp: Date
}

// MARK: - Context Provider Service

@MainActor
class OpenClawContextProvider: ObservableObject {
    static let shared = OpenClawContextProvider()

    @Published var lastContext: OpenClawContext?
    @Published var isLoading = false

    // Configurazione
    @Published var includeCalendar = true
    @Published var includeReminders = true
    @Published var includeTranscriptions = true
    @Published var includeUserProfile = true
    @Published var includeRecentChats = true
    @Published var includeLocation = false // Disabilitato di default per privacy
    @Published var maxTranscriptions = 3
    @Published var maxRecentChats = 5
    @Published var maxReminders = 15
    @Published var transcriptionMaxLength = 1000

    private let calendarManager = CalendarManager()
    private let reminderService = ReminderService.shared
    private let locationManager = OpenClawLocationManager()
    private var context: NSManagedObjectContext {
        PersistenceController.shared.container.viewContext
    }

    private init() {
        loadSettings()
    }

    // MARK: - Public Methods

    /// Raccoglie tutto il contesto disponibile
    func gatherContext() async -> OpenClawContext {
        isLoading = true
        defer { isLoading = false }

        async let calendarContext = gatherCalendarContext()
        async let remindersContext = gatherRemindersContext()
        async let transcriptionsContext = gatherTranscriptionsContext()
        async let profileContext = gatherUserProfileContext()
        async let chatsContext = gatherRecentChatsContext()
        async let locationContext = gatherLocationContext()

        let context = OpenClawContext(
            timestamp: Date(),
            calendar: includeCalendar ? await calendarContext : nil,
            reminders: includeReminders ? await remindersContext : [],
            transcriptions: includeTranscriptions ? await transcriptionsContext : [],
            userProfile: includeUserProfile ? await profileContext : nil,
            recentChats: includeRecentChats ? await chatsContext : [],
            location: includeLocation ? await locationContext : nil
        )

        lastContext = context
        return context
    }

    /// Genera il testo del contesto per il prompt
    func getContextPrompt() async -> String {
        let context = await gatherContext()
        return context.toPromptText()
    }

    /// Versione cached se disponibile
    func getCachedContextPrompt() -> String? {
        return lastContext?.toPromptText()
    }

    // MARK: - Calendar Context

    private func gatherCalendarContext() async -> CalendarContext? {
        // Carica eventi se non già caricati
        await calendarManager.loadInitialData()

        let todayEvents = calendarManager.todayEvents.map { event in
            EventContext(
                id: event.id ?? UUID().uuidString,
                title: event.title,
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location,
                attendees: event.attendees.compactMap { $0.name },
                isAllDay: event.isAllDay
            )
        }

        let upcomingEvents = calendarManager.upcomingEvents
            .filter { !Calendar.current.isDateInToday($0.startDate) }
            .prefix(10)
            .map { event in
                EventContext(
                    id: event.id ?? UUID().uuidString,
                    title: event.title,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    location: event.location,
                    attendees: event.attendees.compactMap { $0.name },
                    isAllDay: event.isAllDay
                )
            }

        let currentEvent = calendarManager.currentEvents.first.map { event in
            EventContext(
                id: event.id ?? UUID().uuidString,
                title: event.title,
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location,
                attendees: event.attendees.compactMap { $0.name },
                isAllDay: event.isAllDay
            )
        }

        // Restituisci nil se non ci sono eventi
        if todayEvents.isEmpty && upcomingEvents.isEmpty && currentEvent == nil {
            return nil
        }

        return CalendarContext(
            todayEvents: todayEvents,
            upcomingEvents: Array(upcomingEvents),
            currentEvent: currentEvent
        )
    }

    // MARK: - Transcriptions Context

    private func gatherTranscriptionsContext() async -> [TranscriptionContext] {
        let fetchRequest: NSFetchRequest<RegistrazioneAudio> = RegistrazioneAudio.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "dataCreazione", ascending: false)]
        fetchRequest.fetchLimit = maxTranscriptions

        do {
            let recordings = try context.fetch(fetchRequest)

            return recordings.compactMap { recording -> TranscriptionContext? in
                // Ottieni la trascrizione associata
                guard let trascrizioni = recording.trascrizioni?.allObjects as? [Trascrizione],
                      let trascrizione = trascrizioni.first,
                      let testoCompleto = trascrizione.testoCompleto,
                      !testoCompleto.isEmpty else {
                    return nil
                }

                // Limita la lunghezza del testo
                let truncatedText = String(testoCompleto.prefix(transcriptionMaxLength))

                return TranscriptionContext(
                    id: recording.id?.uuidString ?? UUID().uuidString,
                    title: recording.titolo ?? "Registrazione",
                    text: truncatedText,
                    date: recording.dataCreazione ?? Date(),
                    duration: recording.durata,
                    language: trascrizione.linguaRilevata
                )
            }
        } catch {
            print("❌ OpenClawContextProvider: Errore caricamento trascrizioni: \(error)")
            return []
        }
    }

    // MARK: - User Profile Context

    private func gatherUserProfileContext() async -> UserProfileContext? {
        let profileService = ProfiloUtenteService.shared

        guard let profilo = profileService.ottieniProfiloUtente(in: context) else {
            return nil
        }

        // Conta chat e messaggi
        let chats = profilo.chats?.allObjects as? [ChatMarilena] ?? []
        let totalMessages = chats.reduce(0) { sum, chat in
            sum + (chat.messaggi?.count ?? 0)
        }

        return UserProfileContext(
            name: profilo.nome,
            email: profilo.email,
            aiContext: profilo.contestoAI,
            totalChats: chats.count,
            totalMessages: totalMessages
        )
    }

    // MARK: - Reminders Context

    private func gatherRemindersContext() async -> [ReminderContext] {
        // Carica reminder
        await reminderService.loadReminders()

        return reminderService.reminders
            .filter { !$0.isCompleted } // Solo non completati
            .prefix(maxReminders)
            .map { reminder in
                let priorityString: String
                switch reminder.priority {
                case .high: priorityString = "high"
                case .medium: priorityString = "medium"
                case .low: priorityString = "low"
                case .none: priorityString = "none"
                }

                return ReminderContext(
                    id: reminder.id,
                    title: reminder.title,
                    notes: reminder.notes,
                    dueDate: reminder.dueDate,
                    priority: priorityString,
                    isCompleted: reminder.isCompleted,
                    isOverdue: reminder.isOverdue,
                    list: reminder.list
                )
            }
    }

    // MARK: - Location Context

    private func gatherLocationContext() async -> LocationContext? {
        guard includeLocation else { return nil }

        return await locationManager.getCurrentLocation()
    }

    // MARK: - Recent Chats Context

    private func gatherRecentChatsContext() async -> [ChatContext] {
        let fetchRequest: NSFetchRequest<ChatMarilena> = ChatMarilena.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "dataCreazione", ascending: false)]
        fetchRequest.fetchLimit = maxRecentChats

        do {
            let chats = try context.fetch(fetchRequest)

            return chats.map { chat in
                let messaggi = (chat.messaggi?.allObjects as? [MessaggioMarilena] ?? [])
                    .sorted { ($0.dataCreazione ?? Date()) > ($1.dataCreazione ?? Date()) }

                let lastMessage = messaggi.first

                return ChatContext(
                    id: chat.id?.uuidString ?? UUID().uuidString,
                    title: chat.titolo ?? "Chat",
                    messageCount: messaggi.count,
                    lastMessageDate: lastMessage?.dataCreazione ?? chat.dataCreazione ?? Date(),
                    lastMessagePreview: lastMessage?.contenuto
                )
            }
        } catch {
            print("❌ OpenClawContextProvider: Errore caricamento chat: \(error)")
            return []
        }
    }

    // MARK: - Settings

    func saveSettings() {
        UserDefaults.standard.set(includeCalendar, forKey: "openclaw_context_calendar")
        UserDefaults.standard.set(includeReminders, forKey: "openclaw_context_reminders")
        UserDefaults.standard.set(includeTranscriptions, forKey: "openclaw_context_transcriptions")
        UserDefaults.standard.set(includeUserProfile, forKey: "openclaw_context_profile")
        UserDefaults.standard.set(includeRecentChats, forKey: "openclaw_context_chats")
        UserDefaults.standard.set(includeLocation, forKey: "openclaw_context_location")
        UserDefaults.standard.set(maxTranscriptions, forKey: "openclaw_context_max_transcriptions")
        UserDefaults.standard.set(maxRecentChats, forKey: "openclaw_context_max_chats")
        UserDefaults.standard.set(maxReminders, forKey: "openclaw_context_max_reminders")
    }

    private func loadSettings() {
        if UserDefaults.standard.object(forKey: "openclaw_context_calendar") != nil {
            includeCalendar = UserDefaults.standard.bool(forKey: "openclaw_context_calendar")
        }
        if UserDefaults.standard.object(forKey: "openclaw_context_reminders") != nil {
            includeReminders = UserDefaults.standard.bool(forKey: "openclaw_context_reminders")
        }
        if UserDefaults.standard.object(forKey: "openclaw_context_transcriptions") != nil {
            includeTranscriptions = UserDefaults.standard.bool(forKey: "openclaw_context_transcriptions")
        }
        if UserDefaults.standard.object(forKey: "openclaw_context_profile") != nil {
            includeUserProfile = UserDefaults.standard.bool(forKey: "openclaw_context_profile")
        }
        if UserDefaults.standard.object(forKey: "openclaw_context_chats") != nil {
            includeRecentChats = UserDefaults.standard.bool(forKey: "openclaw_context_chats")
        }
        if UserDefaults.standard.object(forKey: "openclaw_context_location") != nil {
            includeLocation = UserDefaults.standard.bool(forKey: "openclaw_context_location")
        }
        if UserDefaults.standard.object(forKey: "openclaw_context_max_transcriptions") != nil {
            maxTranscriptions = UserDefaults.standard.integer(forKey: "openclaw_context_max_transcriptions")
        }
        if UserDefaults.standard.object(forKey: "openclaw_context_max_chats") != nil {
            maxRecentChats = UserDefaults.standard.integer(forKey: "openclaw_context_max_chats")
        }
        if UserDefaults.standard.object(forKey: "openclaw_context_max_reminders") != nil {
            maxReminders = UserDefaults.standard.integer(forKey: "openclaw_context_max_reminders")
        }
    }
}

// MARK: - Location Manager for OpenClaw

class OpenClawLocationManager: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<LocationContext?, Never>?
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func getCurrentLocation() async -> LocationContext? {
        let status = locationManager.authorizationStatus

        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            // Attendi un po' per l'autorizzazione
            try? await Task.sleep(nanoseconds: 500_000_000)
            return await getCurrentLocation()

        case .restricted, .denied:
            return nil

        case .authorizedWhenInUse, .authorizedAlways:
            break

        @unknown default:
            return nil
        }

        return await withCheckedContinuation { continuation in
            self.locationContinuation = continuation
            locationManager.requestLocation()

            // Timeout dopo 10 secondi
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                if self.locationContinuation != nil {
                    self.locationContinuation?.resume(returning: nil)
                    self.locationContinuation = nil
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            locationContinuation?.resume(returning: nil)
            locationContinuation = nil
            return
        }

        // Reverse geocoding per ottenere indirizzo
        Task {
            var placeName: String?
            var address: String?

            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                if let placemark = placemarks.first {
                    placeName = placemark.name
                    address = [
                        placemark.thoroughfare,
                        placemark.subThoroughfare,
                        placemark.locality,
                        placemark.administrativeArea
                    ].compactMap { $0 }.joined(separator: ", ")
                }
            } catch {
                print("❌ OpenClawLocationManager: Errore geocoding: \(error)")
            }

            let context = LocationContext(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                placeName: placeName,
                address: address,
                timestamp: location.timestamp
            )

            locationContinuation?.resume(returning: context)
            locationContinuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ OpenClawLocationManager: Errore posizione: \(error)")
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil
    }
}

// MARK: - OpenClaw Service Extension

extension OpenClawService {
    /// Invia un messaggio con contesto RAG da Marilena
    func sendMessageWithContext(_ message: String, sessionId: String? = nil) async throws -> String {
        // Raccogli contesto
        let contextPrompt = await OpenClawContextProvider.shared.getContextPrompt()

        // Costruisci messaggio arricchito
        var enrichedMessage = message
        if !contextPrompt.isEmpty {
            enrichedMessage = """
            [CONTESTO MEMORIA MARILENA]
            \(contextPrompt)

            [RICHIESTA UTENTE]
            \(message)
            """
        }

        return try await sendMessage(enrichedMessage, sessionId: sessionId)
    }

    /// Streaming con contesto
    func streamMessageWithContext(_ message: String, sessionId: String? = nil) async -> AsyncThrowingStream<String, Error> {
        // Raccogli contesto
        let contextPrompt = await OpenClawContextProvider.shared.getContextPrompt()

        // Costruisci messaggio arricchito
        var enrichedMessage = message
        if !contextPrompt.isEmpty {
            enrichedMessage = """
            [CONTESTO MEMORIA MARILENA]
            \(contextPrompt)

            [RICHIESTA UTENTE]
            \(message)
            """
        }

        return streamMessage(enrichedMessage, sessionId: sessionId)
    }
}
