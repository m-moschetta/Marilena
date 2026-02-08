//
//  PlannerPromptBuilder.swift
//  Marilena
//
//  Created by AI Assistant
//  Copyright © 2024. All rights reserved.
//

import Foundation
import CoreData

/// Builder per costruire prompt completi con contesto per l'assistente planner
@MainActor
public class PlannerPromptBuilder {
    private let calendarManager: CalendarManager
    private let reminderService: ReminderService
    private let transcriptionContextService: TranscriptionContextService
    
    public init(
        calendarManager: CalendarManager,
        reminderService: ReminderService = .shared,
        context: NSManagedObjectContext
    ) {
        self.calendarManager = calendarManager
        self.reminderService = reminderService
        self.transcriptionContextService = TranscriptionContextService(context: context)
    }
    
    // MARK: - Public Methods
    
    /// Costruisce un prompt completo con tutto il contesto disponibile
    /// - Parameters:
    ///   - userMessage: Messaggio dell'utente
    ///   - includeTranscriptions: Se includere trascrizioni recenti (default: true)
    ///   - transcriptionLimit: Numero massimo di trascrizioni da includere (default: 3)
    /// - Returns: Prompt completo formattato
    public func buildPrompt(
        userMessage: String,
        includeTranscriptions: Bool = true,
        transcriptionLimit: Int = 3
    ) async -> String {
        var prompt = ""
        
        // Header del sistema
        prompt += systemHeader
        
        // Data e ora corrente
        prompt += currentDateTimeSection
        
        // Eventi prossime 48h
        prompt += await upcomingEventsSection()
        
        // Backlog
        prompt += await backlogSection()
        
        // Trascrizioni recenti (se richiesto)
        if includeTranscriptions {
            prompt += await transcriptionsSection(limit: transcriptionLimit)
        }
        
        // Istruzioni per l'assistente
        prompt += assistantInstructions
        
        // Messaggio utente
        prompt += "\n\n## Messaggio Utente\n\n\(userMessage)\n"
        
        return prompt
    }
    
    /// Costruisce solo il contesto senza il messaggio utente
    /// - Returns: Contesto formattato
    public func buildContext() async -> String {
        var context = ""
        context += currentDateTimeSection
        context += await upcomingEventsSection()
        context += await backlogSection()
        context += await transcriptionsSection(limit: 3)
        return context
    }
    
    // MARK: - Private Sections
    
    private var systemHeader: String {
        """
        # Assistente Planner Marilena

        Sei un assistente AI specializzato nella pianificazione e organizzazione delle giornate. Il tuo obiettivo è aiutare l'utente a:
        - Raggiungere i suoi obiettivi quotidiani
        - Organizzare il tempo con timeblocking
        - Gestire il backlog di attività
        - Utilizzare il contesto di calendario e trascrizioni per suggerimenti intelligenti

        Hai accesso a:
        - Calendario con eventi prossime 48h
        - Backlog di attività (Apple Reminders)
        - Trascrizioni di riunioni e conversazioni
        - Tool per creare eventi e gestire il backlog

        """
    }
    
    private var currentDateTimeSection: String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        
        return """
        ## Data e Ora Corrente
        
        \(formatter.string(from: now))
        
        """
    }
    
    private func upcomingEventsSection() async -> String {
        let now = Date()
        let endDate = Calendar.current.date(byAdding: .hour, value: 48, to: now) ?? now
        
        await calendarManager.loadEvents(from: now, to: endDate)
        
        let events = calendarManager.events.filter { event in
            event.startDate >= now && event.startDate <= endDate
        }.sorted { $0.startDate < $1.startDate }
        
        guard !events.isEmpty else {
            return """
            ## Eventi Prossime 48h
            
            Nessun evento programmato nelle prossime 48 ore.
            
            """
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.timeStyle = .short
        
        var section = "## Eventi Prossime 48h\n\n"
        
        let calendar = Calendar.current
        var currentDay: Date?
        
        for event in events {
            let eventDay = calendar.startOfDay(for: event.startDate)
            
            if currentDay == nil || !calendar.isDate(eventDay, inSameDayAs: currentDay!) {
                currentDay = eventDay
                let dayFormatter = DateFormatter()
                dayFormatter.locale = Locale(identifier: "it_IT")
                dayFormatter.dateStyle = .full
                section += "### \(dayFormatter.string(from: eventDay))\n\n"
            }
            
            let startTime = formatter.string(from: event.startDate)
            let endTime = formatter.string(from: event.endDate)
            let duration = Int(event.endDate.timeIntervalSince(event.startDate) / 60)
            
            section += "- **\(startTime) - \(endTime)** (\(duration) min) - \(event.title)\n"
            
            if let location = event.location {
                section += "  📍 \(location)\n"
            }
            
            if let description = event.description, !description.isEmpty {
                section += "  📝 \(description.prefix(100))\(description.count > 100 ? "..." : "")\n"
            }
            
            section += "\n"
        }
        
        return section
    }
    
    private func backlogSection() async -> String {
        await reminderService.loadBacklogItems()
        let backlogItems = reminderService.getBacklogItems()
        
        guard !backlogItems.isEmpty else {
            return """
            ## Backlog
            
            Nessun elemento nel backlog.
            
            """
        }
        
        var section = "## Backlog (\(backlogItems.count) elementi)\n\n"
        
        for (index, item) in backlogItems.enumerated() {
            section += "\(index + 1). **\(item.title)**"
            
            if let notes = item.notes, !notes.isEmpty {
                section += " - \(notes)"
            }
            
            if let dueDate = item.dueDate {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "it_IT")
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                section += " (scadenza: \(formatter.string(from: dueDate)))"
            }
            
            section += " [Priorità: \(item.priority.displayName)]\n"
        }
        
        section += "\n"
        
        return section
    }
    
    private func transcriptionsSection(limit: Int) async -> String {
        let transcriptions = transcriptionContextService.getRecentTranscriptions(limit: limit)
        
        guard !transcriptions.isEmpty else {
            return """
            ## Trascrizioni Recenti
            
            Nessuna trascrizione disponibile.
            
            """
        }
        
        return transcriptionContextService.formatTranscriptionsForContext(transcriptions) + "\n"
    }
    
    private var assistantInstructions: String {
        """
        ## Istruzioni per l'Assistente
        
        Quando l'utente chiede di:
        - **Pianificare attività**: Usa `create_calendar_event` per bloccare tempo nel calendario
        - **Aggiungere al backlog**: Usa `add_to_backlog` per attività non urgenti
        - **Consultare agenda**: Usa `get_today_agenda` o `get_calendar_events`
        - **Cercare contesto**: Usa `get_transcription_context` per informazioni su riunioni passate
        
        Suggerisci sempre timeblocking quando appropriato, considerando:
        - Eventi esistenti nel calendario
        - Priorità delle attività
        - Tempo necessario per completare le attività
        - Pause e buffer time tra attività
        
        Sii proattivo nel suggerire organizzazione del tempo e gestione del backlog.
        
        """
    }
}
