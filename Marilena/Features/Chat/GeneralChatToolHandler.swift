import Foundation
import CoreData

// MARK: - General Chat Tool Handler

@MainActor
final class GeneralChatToolHandler: ToolHandlerProtocol {
    struct UIAction {
        let title: String
        let message: String
    }

    var onUIAction: ((UIAction) -> Void)?
    private let calendarManager: CalendarManager
    private let newCalendarService: NewCalendarService?
    private let reminderService: ReminderService
    private let transcriptionContextService: TranscriptionContextService
    private let context: NSManagedObjectContext

    init(calendarManager: CalendarManager, newCalendarService: NewCalendarService? = nil, reminderService: ReminderService = .shared, context: NSManagedObjectContext) {
        self.calendarManager = calendarManager
        self.newCalendarService = newCalendarService
        self.reminderService = reminderService
        self.context = context
        self.transcriptionContextService = TranscriptionContextService(context: context)
    }
    
    // Disponibili al modello
    var availableTools: [AIToolDefinition] {
        [
            AIToolDefinition(
                name: "create_calendar_event",
                description: "Crea un evento calendario. Fornisci titolo, inizio, fine, luogo e note.",
                jsonSchema: """
                {
                  "type": "object",
                  "properties": {
                    "title": { "type": "string", "description": "Titolo dell'evento" },
                    "description": { "type": "string", "description": "Descrizione o note" },
                    "start_time": { "type": "string", "description": "Data/ora in ISO 8601" },
                    "end_time": { "type": "string", "description": "Data/ora fine in ISO 8601" },
                    "location": { "type": "string", "description": "Luogo" },
                    "attendees": { "type": "array", "items": { "type": "string" }, "description": "Email invitati" }
                  },
                  "required": ["title", "start_time", "end_time"]
                }
                """
            ),
            AIToolDefinition(
                name: "get_calendar_events",
                description: "Legge gli eventi del calendario per un periodo specifico. Default: prossime 48 ore. Mostra anche sovrapposizioni se presenti.",
                jsonSchema: """
                {
                  "type": "object",
                  "properties": {
                    "start_date": { "type": "string", "description": "Data di inizio in ISO 8601 (opzionale, default: ora)" },
                    "end_date": { "type": "string", "description": "Data di fine in ISO 8601 (opzionale, default: +48h)" },
                    "hours_ahead": { "type": "number", "description": "Numero di ore da ora in poi (opzionale, default: 48)" },
                    "check_overlaps": { "type": "boolean", "description": "Se true, verifica e segnala sovrapposizioni tra eventi (default: true)" }
                  }
                }
                """
            ),
            AIToolDefinition(
                name: "update_calendar_event",
                description: "Aggiorna o sposta un evento esistente nel calendario. Verifica automaticamente sovrapposizioni.",
                jsonSchema: """
                {
                  "type": "object",
                  "properties": {
                    "event_id": { "type": "string", "description": "ID dell'evento da aggiornare" },
                    "title": { "type": "string", "description": "Nuovo titolo (opzionale)" },
                    "description": { "type": "string", "description": "Nuova descrizione (opzionale)" },
                    "start_time": { "type": "string", "description": "Nuova data/ora inizio in ISO 8601 (opzionale)" },
                    "end_time": { "type": "string", "description": "Nuova data/ora fine in ISO 8601 (opzionale)" },
                    "location": { "type": "string", "description": "Nuovo luogo (opzionale)" },
                    "attendees": { "type": "array", "items": { "type": "string" }, "description": "Nuova lista email invitati (opzionale)" }
                  },
                  "required": ["event_id"]
                }
                """
            ),
            AIToolDefinition(
                name: "get_today_agenda",
                description: "Restituisce l'agenda formattata della giornata corrente con eventi e time blocks.",
                jsonSchema: """
                {
                  "type": "object",
                  "properties": {},
                  "required": []
                }
                """
            ),
            AIToolDefinition(
                name: "add_to_backlog",
                description: "Aggiunge un elemento al backlog (lista di cose da fare). Crea un reminder in Apple Reminders.",
                jsonSchema: """
                {
                  "type": "object",
                  "properties": {
                    "title": { "type": "string", "description": "Titolo dell'elemento del backlog" },
                    "notes": { "type": "string", "description": "Note opzionali" },
                    "priority": { "type": "string", "description": "Priorità: low, medium, high (default: medium)" }
                  },
                  "required": ["title"]
                }
                """
            ),
            AIToolDefinition(
                name: "get_backlog",
                description: "Ottiene tutti gli elementi del backlog non completati.",
                jsonSchema: """
                {
                  "type": "object",
                  "properties": {},
                  "required": []
                }
                """
            ),
            AIToolDefinition(
                name: "complete_backlog_item",
                description: "Marca un elemento del backlog come completato.",
                jsonSchema: """
                {
                  "type": "object",
                  "properties": {
                    "reminder_id": { "type": "string", "description": "ID del reminder da completare" }
                  },
                  "required": ["reminder_id"]
                }
                """
            ),
            AIToolDefinition(
                name: "get_transcription_context",
                description: "Recupera trascrizioni recenti o collegate a eventi. Utile per contesto su riunioni o conversazioni.",
                jsonSchema: """
                {
                  "type": "object",
                  "properties": {
                    "event_title": { "type": "string", "description": "Titolo dell'evento per cercare trascrizioni collegate" },
                    "limit": { "type": "number", "description": "Numero massimo di trascrizioni da recuperare (default: 5)" },
                    "search_text": { "type": "string", "description": "Testo da cercare nelle trascrizioni" },
                    "days_back": { "type": "number", "description": "Numero di giorni indietro per cercare (default: 7)" }
                  }
                }
                """
            )
        ]
    }
    
    func executeToolCall(_ toolCall: ChatCompletionToolCall) async throws -> String {
        switch toolCall.function.name {
        case "create_calendar_event":
            return try await executeCreateCalendarEvent(argumentsJSON: toolCall.function.arguments)
        case "update_calendar_event":
            return try await executeUpdateCalendarEvent(argumentsJSON: toolCall.function.arguments)
        case "get_calendar_events":
            return try await executeGetCalendarEvents(argumentsJSON: toolCall.function.arguments)
        case "get_today_agenda":
            return try await executeGetTodayAgenda(argumentsJSON: toolCall.function.arguments)
        case "add_to_backlog":
            return try await executeAddToBacklog(argumentsJSON: toolCall.function.arguments)
        case "get_backlog":
            return try await executeGetBacklog(argumentsJSON: toolCall.function.arguments)
        case "complete_backlog_item":
            return try await executeCompleteBacklogItem(argumentsJSON: toolCall.function.arguments)
        case "get_transcription_context":
            return try await executeGetTranscriptionContext(argumentsJSON: toolCall.function.arguments)
        default:
            return "Tool non supportato: \(toolCall.function.name)"
        }
    }
    
    // MARK: - Tools
    
    private func executeCreateCalendarEvent(argumentsJSON: String) async throws -> String {
        struct CalendarArgs: Decodable {
            let title: String
            let description: String?
            let start_time: String
            let end_time: String
            let location: String?
            let attendees: [String]?
        }
        
        guard let data = argumentsJSON.data(using: .utf8) else {
            return "Argomenti tool non validi"
        }
        
        let args: CalendarArgs
        do {
            args = try JSONDecoder().decode(CalendarArgs.self, from: data)
        } catch {
            return "Impossibile leggere i parametri dell'evento: \(error.localizedDescription)"
        }
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let startDate = isoFormatter.date(from: args.start_time) ?? ISO8601DateFormatter().date(from: args.start_time),
              let endDate = isoFormatter.date(from: args.end_time) ?? ISO8601DateFormatter().date(from: args.end_time) else {
            return "Non riesco a interpretare le date di inizio/fine per l'evento."
        }

        // Verifica sovrapposizioni prima di creare (se disponibile NewCalendarService)
        var overlapWarning = ""
        if let newCalService = newCalendarService {
            let overlappingEvents = newCalService.findOverlappingEvents(
                startDate: startDate,
                endDate: endDate
            )

            if !overlappingEvents.isEmpty {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "it_IT")
                formatter.dateStyle = .short
                formatter.timeStyle = .short

                overlapWarning = "\n\n⚠️ ATTENZIONE: Il nuovo evento si sovrappone con:\n"
                for overlap in overlappingEvents.prefix(3) {
                    let overlapStart = formatter.string(from: overlap.startDate)
                    let overlapEnd = formatter.string(from: overlap.endDate)
                    overlapWarning += "  • \(overlap.title) (\(overlapStart) - \(overlapEnd))\n"
                }
                if overlappingEvents.count > 3 {
                    overlapWarning += "  ... e altri \(overlappingEvents.count - 3) eventi\n"
                }
            }
        }

        let request = CalendarEventRequest(
            title: args.title,
            description: args.description,
            startDate: startDate,
            endDate: endDate,
            location: args.location,
            attendeeEmails: args.attendees ?? []
        )

        do {
            let eventId = try await calendarManager.createEvent(request)

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "it_IT")
            formatter.dateStyle = .short
            formatter.timeStyle = .short

            let startTime = formatter.string(from: startDate)
            let endTime = formatter.string(from: endDate)

            let uiAction = UIAction(
                title: "Nuovo evento creato",
                message: "\(args.title) dalle \(startDate) alle \(endDate)"
            )
            onUIAction?(uiAction) // non deve mai lanciare

            return "✅ Evento creato con successo:\n\n" +
                   "📌 **\(args.title)**\n" +
                   "🕐 \(startTime) - \(endTime)\n" +
                   (args.location != nil ? "📍 \(args.location!)\n" : "") +
                   "🆔 ID: `\(eventId)`" +
                   overlapWarning
        } catch {
            // Se il servizio calendario non è configurato, prova a usare il parsing naturale
            let fallbackText = [
                args.title,
                args.description,
                args.location,
                "Inizio: \(args.start_time)",
                "Fine: \(args.end_time)"
            ]
            do {
                let eventId = try await calendarManager.createEventFromText(fallbackText.compactMap { $0 }.joined(separator: "\n"))
                let uiAction = UIAction(
                    title: "Nuovo evento creato",
                    message: "\(args.title) dalle \(startDate) alle \(endDate)"
                )
                onUIAction?(uiAction)
                return "Evento creato tramite interpretazione testuale (id: \(eventId))."
            } catch {
                return "Non riesco a creare l'evento: \(error.localizedDescription)"
            }
        }
    }
    
    private func executeUpdateCalendarEvent(argumentsJSON: String) async throws -> String {
        struct UpdateEventArgs: Decodable {
            let event_id: String
            let title: String?
            let description: String?
            let start_time: String?
            let end_time: String?
            let location: String?
            let attendees: [String]?
        }

        guard let data = argumentsJSON.data(using: .utf8) else {
            return "Argomenti tool non validi"
        }

        let args: UpdateEventArgs
        do {
            args = try JSONDecoder().decode(UpdateEventArgs.self, from: data)
        } catch {
            return "Impossibile leggere i parametri: \(error.localizedDescription)"
        }

        // Trova l'evento esistente
        guard let existingEvent = calendarManager.events.first(where: { $0.id == args.event_id }) else {
            return "Evento non trovato con ID: \(args.event_id)"
        }

        // Prepara le date aggiornate
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let newStartDate: Date
        if let startTimeStr = args.start_time {
            guard let parsedDate = isoFormatter.date(from: startTimeStr) ?? ISO8601DateFormatter().date(from: startTimeStr) else {
                return "Impossibile interpretare la data di inizio: \(startTimeStr)"
            }
            newStartDate = parsedDate
        } else {
            newStartDate = existingEvent.startDate
        }

        let newEndDate: Date
        if let endTimeStr = args.end_time {
            guard let parsedDate = isoFormatter.date(from: endTimeStr) ?? ISO8601DateFormatter().date(from: endTimeStr) else {
                return "Impossibile interpretare la data di fine: \(endTimeStr)"
            }
            newEndDate = parsedDate
        } else {
            // Se cambiata solo la data di inizio, mantieni la stessa durata
            if args.start_time != nil {
                let duration = existingEvent.endDate.timeIntervalSince(existingEvent.startDate)
                newEndDate = newStartDate.addingTimeInterval(duration)
            } else {
                newEndDate = existingEvent.endDate
            }
        }

        // Verifica sovrapposizioni con il nuovo orario (se disponibile NewCalendarService)
        var overlapWarning = ""
        if let newCalService = newCalendarService {
            let overlappingEvents = newCalService.findOverlappingEvents(
                startDate: newStartDate,
                endDate: newEndDate,
                excludeEventId: args.event_id
            )

            if !overlappingEvents.isEmpty {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "it_IT")
                formatter.dateStyle = .short
                formatter.timeStyle = .short

                overlapWarning = "\n\n⚠️ ATTENZIONE: L'evento si sovrappone con:\n"
                for overlap in overlappingEvents.prefix(3) {
                    let overlapStart = formatter.string(from: overlap.startDate)
                    let overlapEnd = formatter.string(from: overlap.endDate)
                    overlapWarning += "  • \(overlap.title) (\(overlapStart) - \(overlapEnd))\n"
                }
                if overlappingEvents.count > 3 {
                    overlapWarning += "  ... e altri \(overlappingEvents.count - 3) eventi\n"
                }
            }
        }

        // Crea l'evento aggiornato
        let updatedEvent = CalendarEvent(
            id: existingEvent.id,
            title: args.title ?? existingEvent.title,
            description: args.description ?? existingEvent.description,
            startDate: newStartDate,
            endDate: newEndDate,
            location: args.location ?? existingEvent.location,
            isAllDay: existingEvent.isAllDay,
            recurrenceRule: existingEvent.recurrenceRule,
            attendees: args.attendees?.map { CalendarAttendee(email: $0, name: nil) } ?? existingEvent.attendees,
            calendarId: existingEvent.calendarId,
            url: existingEvent.url,
            providerId: existingEvent.providerId,
            providerType: existingEvent.providerType,
            lastModified: Date()
        )

        do {
            try await calendarManager.updateEvent(updatedEvent)

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "it_IT")
            formatter.dateStyle = .short
            formatter.timeStyle = .short

            let uiAction = UIAction(
                title: "Evento aggiornato",
                message: "\(updatedEvent.title)"
            )
            onUIAction?(uiAction)

            let startTime = formatter.string(from: newStartDate)
            let endTime = formatter.string(from: newEndDate)

            return "✅ Evento aggiornato con successo:\n\n" +
                   "📌 **\(updatedEvent.title)**\n" +
                   "🕐 \(startTime) - \(endTime)\n" +
                   (updatedEvent.location != nil ? "📍 \(updatedEvent.location!)\n" : "") +
                   overlapWarning
        } catch {
            return "❌ Errore nell'aggiornamento dell'evento: \(error.localizedDescription)"
        }
    }

    // MARK: - New Tools Implementation

    private func executeGetCalendarEvents(argumentsJSON: String) async throws -> String {
        struct CalendarEventsArgs: Decodable {
            let start_date: String?
            let end_date: String?
            let hours_ahead: Double?
            let check_overlaps: Bool?
        }
        
        guard let data = argumentsJSON.data(using: .utf8) else {
            return "Argomenti tool non validi"
        }
        
        let args: CalendarEventsArgs
        do {
            args = try JSONDecoder().decode(CalendarEventsArgs.self, from: data)
        } catch {
            return "Impossibile leggere i parametri: \(error.localizedDescription)"
        }
        
        let now = Date()
        let hoursAhead = args.hours_ahead ?? 48.0
        let endDate = Calendar.current.date(byAdding: .hour, value: Int(hoursAhead), to: now) ?? now
        
        let startDate: Date
        if let startDateStr = args.start_date {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            startDate = isoFormatter.date(from: startDateStr) ?? ISO8601DateFormatter().date(from: startDateStr) ?? now
        } else {
            startDate = now
        }
        
        let finalEndDate: Date
        if let endDateStr = args.end_date {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            finalEndDate = isoFormatter.date(from: endDateStr) ?? ISO8601DateFormatter().date(from: endDateStr) ?? endDate
        } else {
            finalEndDate = endDate
        }
        
        // Carica eventi dal calendario
        await calendarManager.loadEvents(from: startDate, to: finalEndDate)
        
        let events = calendarManager.events.filter { event in
            event.startDate >= startDate && event.startDate <= finalEndDate
        }.sorted { $0.startDate < $1.startDate }
        
        if events.isEmpty {
            return "Nessun evento trovato nel periodo specificato."
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        
        var result = "## Eventi Calendario (\(events.count) eventi)\n\n"
        
        let calendar = Calendar.current
        var currentDay: Date?
        
        for event in events {
            let eventDay = calendar.startOfDay(for: event.startDate)
            
            if currentDay == nil || !calendar.isDate(eventDay, inSameDayAs: currentDay!) {
                currentDay = eventDay
                formatter.dateStyle = .full
                result += "### \(formatter.string(from: eventDay))\n\n"
                formatter.dateStyle = .short
            }
            
            formatter.timeStyle = .short
            let startTime = formatter.string(from: event.startDate)
            let endTime = formatter.string(from: event.endDate)
            
            result += "**\(startTime) - \(endTime)**: \(event.title)\n"
            
            if let location = event.location {
                result += "📍 \(location)\n"
            }
            
            if let description = event.description, !description.isEmpty {
                result += "📝 \(description.prefix(100))\(description.count > 100 ? "..." : "")\n"
            }
            
            if !event.attendees.isEmpty {
                let attendeeNames = event.attendees.compactMap { $0.email }.joined(separator: ", ")
                result += "👥 \(attendeeNames)\n"
            }

            // Aggiungi ID evento per riferimento
            result += "🆔 ID: `\(event.id ?? "N/A")`\n"

            result += "\n"
        }

        // Verifica sovrapposizioni se richiesto e se NewCalendarService è disponibile
        let shouldCheckOverlaps = args.check_overlaps ?? true
        if shouldCheckOverlaps, let newCalService = newCalendarService {
            let overlaps = newCalService.findAllOverlaps(from: startDate, to: finalEndDate)

            if !overlaps.isEmpty {
                result += "\n---\n\n"
                result += "## ⚠️ Sovrapposizioni Rilevate\n\n"
                result += "I seguenti eventi si sovrappongono tra loro:\n\n"

                for (eventId, overlappingEvents) in overlaps {
                    if let mainEvent = events.first(where: { $0.id == eventId }) {
                        formatter.timeStyle = .short
                        let startTime = formatter.string(from: mainEvent.startDate)
                        let endTime = formatter.string(from: mainEvent.endDate)

                        result += "**\(mainEvent.title)** (\(startTime) - \(endTime))\n"
                        result += "  si sovrappone con:\n"

                        for overlap in overlappingEvents {
                            let overlapStart = formatter.string(from: overlap.startDate)
                            let overlapEnd = formatter.string(from: overlap.endDate)
                            result += "  • \(overlap.title) (\(overlapStart) - \(overlapEnd))\n"
                        }
                        result += "\n"
                    }
                }
            }
        }

        return result
    }
    
    private func executeGetTodayAgenda(argumentsJSON: String) async throws -> String {
        let now = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
        
        // Carica eventi di oggi
        await calendarManager.loadEvents(from: startOfDay, to: endOfDay)
        
        let todayEvents = calendarManager.events.filter { event in
            calendar.isDate(event.startDate, inSameDayAs: now)
        }.sorted { $0.startDate < $1.startDate }
        
        // Carica backlog
        await reminderService.loadBacklogItems()
        let backlogItems = reminderService.getBacklogItems()
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.timeStyle = .short
        
        var result = "## 📅 Agenda di Oggi\n\n"
        result += "**Data**: \(formatter.string(from: now))\n\n"
        
        if todayEvents.isEmpty {
            result += "### Nessun evento in programma oggi\n\n"
        } else {
            result += "### Eventi (\(todayEvents.count))\n\n"
            
            for event in todayEvents {
                let startTime = formatter.string(from: event.startDate)
                let endTime = formatter.string(from: event.endDate)
                let duration = Int(event.endDate.timeIntervalSince(event.startDate) / 60)
                
                result += "**\(startTime) - \(endTime)** (\(duration) min)\n"
                result += "📌 \(event.title)\n"
                
                if let location = event.location {
                    result += "📍 \(location)\n"
                }
                
                result += "\n"
            }
        }
        
        if !backlogItems.isEmpty {
            result += "### 📋 Backlog (\(backlogItems.count) elementi)\n\n"
            for (index, item) in backlogItems.prefix(5).enumerated() {
                result += "\(index + 1). \(item.title)"
                if let notes = item.notes, !notes.isEmpty {
                    result += " - \(notes.prefix(50))"
                }
                result += "\n"
            }
            if backlogItems.count > 5 {
                result += "\n... e altri \(backlogItems.count - 5) elementi\n"
            }
        }
        
        return result
    }
    
    private func executeAddToBacklog(argumentsJSON: String) async throws -> String {
        struct BacklogArgs: Decodable {
            let title: String
            let notes: String?
            let priority: String?
        }
        
        guard let data = argumentsJSON.data(using: .utf8) else {
            return "Argomenti tool non validi"
        }
        
        let args: BacklogArgs
        do {
            args = try JSONDecoder().decode(BacklogArgs.self, from: data)
        } catch {
            return "Impossibile leggere i parametri: \(error.localizedDescription)"
        }
        
        let priority: ReminderPriority
        switch args.priority?.lowercased() {
        case "high", "alta":
            priority = .high
        case "low", "bassa":
            priority = .low
        default:
            priority = .medium
        }
        
        do {
            let reminderId = try await reminderService.addToBacklog(
                title: args.title,
                notes: args.notes,
                priority: priority
            )
            
            let uiAction = UIAction(
                title: "Aggiunto al backlog",
                message: args.title
            )
            onUIAction?(uiAction)
            
            return "Elemento aggiunto al backlog con successo: \"\(args.title)\" (ID: \(reminderId))"
        } catch {
            return "Errore aggiunta al backlog: \(error.localizedDescription)"
        }
    }
    
    private func executeGetBacklog(argumentsJSON: String) async throws -> String {
        await reminderService.loadBacklogItems()
        let backlogItems = reminderService.getBacklogItems()
        
        if backlogItems.isEmpty {
            return "Il backlog è vuoto. Nessun elemento da completare."
        }
        
        var result = "## 📋 Backlog (\(backlogItems.count) elementi)\n\n"
        
        for (index, item) in backlogItems.enumerated() {
            result += "\(index + 1). **\(item.title)**"
            
            if let notes = item.notes, !notes.isEmpty {
                result += "\n   📝 \(notes)"
            }
            
            if let dueDate = item.dueDate {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "it_IT")
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                result += "\n   📅 Scadenza: \(formatter.string(from: dueDate))"
            }
            
            result += "\n   🏷️ Priorità: \(item.priority.displayName)"
            result += "\n   🆔 ID: \(item.id)\n\n"
        }
        
        return result
    }
    
    private func executeCompleteBacklogItem(argumentsJSON: String) async throws -> String {
        struct CompleteArgs: Decodable {
            let reminder_id: String
        }
        
        guard let data = argumentsJSON.data(using: .utf8) else {
            return "Argomenti tool non validi"
        }
        
        let args: CompleteArgs
        do {
            args = try JSONDecoder().decode(CompleteArgs.self, from: data)
        } catch {
            return "Impossibile leggere i parametri: \(error.localizedDescription)"
        }
        
        do {
            try await reminderService.completeBacklogItem(reminderId: args.reminder_id)
            
            let uiAction = UIAction(
                title: "Elemento completato",
                message: "Elemento del backlog completato con successo"
            )
            onUIAction?(uiAction)
            
            return "Elemento del backlog completato con successo (ID: \(args.reminder_id))"
        } catch {
            return "Errore completamento elemento: \(error.localizedDescription)"
        }
    }
    
    private func executeGetTranscriptionContext(argumentsJSON: String) async throws -> String {
        struct TranscriptionArgs: Decodable {
            let event_title: String?
            let limit: Int?
            let search_text: String?
            let days_back: Int?
        }
        
        guard let data = argumentsJSON.data(using: .utf8) else {
            return "Argomenti tool non validi"
        }
        
        let args: TranscriptionArgs
        do {
            args = try JSONDecoder().decode(TranscriptionArgs.self, from: data)
        } catch {
            return "Impossibile leggere i parametri: \(error.localizedDescription)"
        }
        
        var transcriptions: [Trascrizione] = []
        
        // Cerca per evento
        if let eventTitle = args.event_title, !eventTitle.isEmpty {
            transcriptions = transcriptionContextService.getTranscriptionsForEvent(eventTitle: eventTitle)
        }
        // Cerca per testo
        else if let searchText = args.search_text, !searchText.isEmpty {
            transcriptions = transcriptionContextService.searchTranscriptions(searchText: searchText)
        }
        // Cerca per intervallo di date
        else {
            let daysBack = args.days_back ?? 7
            let startDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
            let endDate = Date()
            transcriptions = transcriptionContextService.getTranscriptionsInDateRange(startDate: startDate, endDate: endDate)
        }
        
        // Limita i risultati
        let limit = args.limit ?? 5
        transcriptions = Array(transcriptions.prefix(limit))
        
        if transcriptions.isEmpty {
            return "Nessuna trascrizione trovata per i criteri specificati."
        }
        
        return transcriptionContextService.formatTranscriptionsForContext(transcriptions)
    }
}
