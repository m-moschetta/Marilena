//
//  MailChatBridge.swift
//  Marilena
//
//  Created by Marilena on 2024
//
//  Bridge per l'integrazione tra sistema mail e chat
//  Gestisce composizione assistita e conferma invio
//

import Foundation
import Combine

/// Bridge per l'integrazione mail-chat
public final class MailChatBridge: ObservableObject {

    // MARK: - Published Properties

    @Published public var replySuggestions: [MailReplySuggestion] = []
    @Published public var isGeneratingReply = false
    @Published public var lastSentMessage: MailMessage?

    // MARK: - Private Properties

    private let domainService: MailDomainService
    private let aiService: AIServiceProtocol
    private let calendarService: CalendarContextService?
    private let queue = DispatchQueue(label: "com.marilena.mail.chatbridge", qos: .userInitiated)

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        domainService: MailDomainService,
        aiService: AIServiceProtocol,
        calendarService: CalendarContextService? = nil
    ) {
        self.domainService = domainService
        self.aiService = aiService
        self.calendarService = calendarService
    }

    // MARK: - Public Methods

    /// Genera suggerimenti di risposta per un'email
    public func generateReplySuggestions(for message: MailMessage, accountId: String) async throws {
        await MainActor.run {
            isGeneratingReply = true
            replySuggestions = []
        }

        defer {
            Task { @MainActor in
                isGeneratingReply = false
            }
        }

        do {
            // Raccogli contesto per la risposta
            let context = try await gatherReplyContext(for: message, accountId: accountId)

            // Genera suggerimenti usando AI
            let suggestions = try await generateAISuggestions(for: message, context: context)

            await MainActor.run {
                replySuggestions = suggestions
            }

        } catch {
            print("❌ Errore generazione suggerimenti: \(error)")
            throw error
        }
    }

    /// Crea una bozza di risposta basata su un suggerimento
    public func createReplyDraft(from suggestion: MailReplySuggestion, originalMessage: MailMessage, accountId: String) -> MailMessage {
        let replySubject = createReplySubject(originalMessage.subject)
        let replyBody = MailBody(
            plainText: suggestion.content,
            htmlText: convertToHTML(suggestion.content),
            contentType: .html
        )

        return MailMessage(
            id: UUID().uuidString,
            threadId: originalMessage.threadId,
            subject: replySubject,
            body: replyBody,
            from: getCurrentUserParticipant(for: accountId),
            to: [originalMessage.from],
            cc: [],
            bcc: [],
            date: Date(),
            labels: ["draft"],
            flags: .init(),
            attachments: [],
            providerMessageId: nil,
            inReplyTo: originalMessage.id,
            references: (originalMessage.references + [originalMessage.id])
        )
    }

    /// Invia una risposta e notifica la chat
    public func sendReply(_ reply: MailMessage, accountId: String) async throws {
        // Invia l'email
        try await domainService.sendMessage(reply, using: accountId)

        // Salva come ultimo messaggio inviato
        await MainActor.run {
            lastSentMessage = reply
        }

        // Notifica la chat del successo
        await notifyChatOfSuccessfulSend(reply)

        print("✅ Risposta inviata con successo: \(reply.subject)")
    }

    /// Annulla la generazione di suggerimenti
    public func cancelReplyGeneration() {
        // Annulla eventuali task in corso
        queue.async {
            // Implementazione cancellazione
        }

        Task { @MainActor in
            isGeneratingReply = false
            replySuggestions = []
        }
    }

    // MARK: - Private Methods

    private func gatherReplyContext(for message: MailMessage, accountId: String) async throws -> MailReplyContext {
        var context = MailReplyContext()

        // Aggiungi cronologia del thread
        if let threadId = message.threadId {
            let threadMessages = try await domainService.loadMessages(
                for: accountId,
                filter: MailMessageFilter(threadId: threadId)
            )
            context.threadHistory = threadMessages.sorted { $0.date < $1.date }
        }

        // Aggiungi interazioni precedenti con il contatto
        let previousInteractions = try await findPreviousInteractions(
            with: message.from.email,
            accountId: accountId
        )
        context.previousInteractions = previousInteractions

        // Aggiungi contesto calendario se disponibile
        if let calendarService = calendarService {
            let calendarContext = try await calendarService.getContextForContact(
                email: message.from.email,
                timeWindow: TimeInterval(30 * 24 * 60 * 60) // 30 giorni
            )
            context.calendarEvents = calendarContext.events
            context.recordings = calendarContext.recordings
        }

        return context
    }

    private func generateAISuggestions(for message: MailMessage, context: MailReplyContext) async throws -> [MailReplySuggestion] {
        let prompt = createAIPrompt(for: message, context: context)

        // Crea richiesta AI usando il protocollo esistente
        let aiRequest = AIRequest(
            messages: [AIMessage(role: "user", content: prompt)],
            model: "gpt-4", // Usa modello predefinito
            maxTokens: 1000,
            temperature: 0.7
        )

        // Chiama il servizio AI
        let aiResponse = try await aiService.sendMessage(aiRequest)

        // Converte la risposta AI in suggerimenti strutturati
        return convertAIToSuggestions(aiResponse.content, originalMessage: message)
    }

    private func createAIPrompt(for message: MailMessage, context: MailReplyContext) -> String {
        var prompt = """
        Genera suggerimenti di risposta professionale per questa email:

        EMAIL ORIGINALE:
        Da: \(message.from.displayName) <\(message.from.email)>
        Oggetto: \(message.subject)
        Contenuto: \(message.body.displayText)

        """

        // Aggiungi contesto thread se disponibile
        if let threadHistory = context.threadHistory, threadHistory.count > 1 {
            prompt += "\nSTORIA DELLA CONVERSAZIONE:\n"
            for (index, msg) in threadHistory.prefix(5).enumerated() {
                prompt += "\(index + 1). \(msg.from.displayName): \(msg.body.displayText.prefix(100))...\n"
            }
        }

        // Aggiungi contesto calendario
        if let events = context.calendarEvents, !events.isEmpty {
            prompt += "\nEVENTI CALENDARIO RECENTI:\n"
            for event in events.prefix(3) {
                prompt += "- \(event.title) (\(formatDate(event.startDate)))\n"
            }
        }

        // Aggiungi istruzioni
        prompt += """

        ISTRUZIONI:
        - Genera 3-4 suggerimenti di risposta diversi
        - Adatta il tono al contesto (professionale, amichevole, formale)
        - Includi riferimenti a eventi calendario se rilevanti
        - Mantieni le risposte concise ma complete
        - Usa un linguaggio cortese e professionale

        """

        return prompt
    }

    private func convertAIToSuggestions(_ aiResponse: String, originalMessage: MailMessage) -> [MailReplySuggestion] {
        // Parsing semplificato della risposta AI
        let suggestions = aiResponse
            .components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .prefix(4) // Max 4 suggerimenti
            .enumerated()
            .map { (index, content) in
                let tone = inferTone(from: content)
                let style = inferStyle(from: content)

                return MailReplySuggestion(
                    id: UUID().uuidString,
                    content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                    tone: tone,
                    style: style,
                    confidence: 0.8 - Double(index) * 0.1, // Diminuisce leggermente per ogni suggerimento successivo
                    createdAt: Date()
                )
            }

        return Array(suggestions)
    }

    private func findPreviousInteractions(with email: String, accountId: String) async throws -> [MailMessage] {
        let filter = MailMessageFilter() // Filtro per contatto specifico
        let allMessages = try await domainService.loadMessages(for: accountId, filter: filter)

        return allMessages
            .filter { msg in
                msg.from.email == email ||
                msg.to.contains { $0.email == email } ||
                msg.cc.contains { $0.email == email }
            }
            .sorted { $0.date > $1.date }
            .prefix(10) // Ultime 10 interazioni
            .reversed() // Ordine cronologico
    }

    private func createReplySubject(_ originalSubject: String) -> String {
        if originalSubject.lowercased().hasPrefix("re:") {
            return originalSubject
        } else {
            return "Re: \(originalSubject)"
        }
    }

    private func getCurrentUserParticipant(for accountId: String) -> MailParticipant {
        // Placeholder - in produzione prenderebbe dall'account corrente
        return MailParticipant(email: "user@example.com", name: "User Name")
    }

    private func convertToHTML(_ plainText: String) -> String {
        // Conversione semplice plain text -> HTML
        let html = plainText
            .replacingOccurrences(of: "\n", with: "<br>")
            .replacingOccurrences(of: "  ", with: "&nbsp;&nbsp;")

        return """
        <div style="font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 14px; line-height: 1.4;">
        \(html)
        </div>
        """
    }

    private func notifyChatOfSuccessfulSend(_ message: MailMessage) async {
        // Placeholder - implementazione effettiva della notifica alla chat
        let notification = MailSendNotification(
            messageId: message.id,
            subject: message.subject,
            recipients: message.to.map { $0.displayName }.joined(separator: ", "),
            sentAt: Date(),
            success: true
        )

        // In produzione: inviare notifica alla chat
        print("📧 Notifica chat: Email inviata - \(notification.subject)")
    }

    private func inferTone(from content: String) -> MailReplyTone {
        let lowerContent = content.lowercased()

        if lowerContent.contains("gentile") || lowerContent.contains("cordiali saluti") {
            return .formal
        } else if lowerContent.contains("ciao") || lowerContent.contains("grazie mille") {
            return .friendly
        } else {
            return .professional
        }
    }

    private func inferStyle(from content: String) -> MailReplyStyle {
        if content.count < 100 {
            return .brief
        } else if content.contains("•") || content.contains("- ") {
            return .structured
        } else {
            return .conversational
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Types

/// Contesto per la generazione di risposte
public struct MailReplyContext {
    public var threadHistory: [MailMessage]?
    public var previousInteractions: [MailMessage]?
    public var calendarEvents: [CalendarEvent]?
    public var recordings: [Recording]?

    public init() {}
}

/// Suggerimento di risposta
public struct MailReplySuggestion: Identifiable {
    public let id: String
    public let content: String
    public let tone: MailReplyTone
    public let style: MailReplyStyle
    public let confidence: Double
    public let createdAt: Date
}

/// Tono della risposta
public enum MailReplyTone: String, Codable {
    case formal = "formal"
    case professional = "professional"
    case friendly = "friendly"
    case casual = "casual"

    public var displayName: String {
        switch self {
        case .formal: return "Formale"
        case .professional: return "Professionale"
        case .friendly: return "Amichevole"
        case .casual: return "Casuale"
        }
    }
}

/// Stile della risposta
public enum MailReplyStyle: String, Codable {
    case brief = "brief"
    case conversational = "conversational"
    case structured = "structured"
    case detailed = "detailed"

    public var displayName: String {
        switch self {
        case .brief: return "Breve"
        case .conversational: return "Conversazionale"
        case .structured: return "Strutturato"
        case .detailed: return "Dettagliato"
        }
    }
}

/// Notifica di invio email
public struct MailSendNotification {
    public let messageId: String
    public let subject: String
    public let recipients: String
    public let sentAt: Date
    public let success: Bool
}

// MARK: - Placeholder Protocols



/// Protocollo per il servizio calendario (placeholder)
public protocol CalendarContextService {
    func getContextForContact(email: String, timeWindow: TimeInterval) async throws -> CalendarContext
}

/// Contesto calendario
public struct CalendarContext {
    public let events: [CalendarEvent]?
    public let recordings: [Recording]?

    public init(events: [CalendarEvent]? = nil, recordings: [Recording]? = nil) {
        self.events = events
        self.recordings = recordings
    }
}

/// Registrazione (placeholder)
public struct Recording {
    public let id: String
    public let title: String
    public let date: Date
    public let duration: TimeInterval
}
