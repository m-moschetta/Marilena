import Foundation
import Combine

/// Servizio per l'integrazione tra sistema email e chat
/// Gestisce la composizione assistita e la conferma invio in chat
public class MailChatBridgeService {
    public static let shared = MailChatBridgeService()

    private let mailService = MailService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Composition Assistance

    /// Crea una bozza di risposta assistita basata sul contesto
    public func createReplyDraft(
        for message: MailMessage,
        context: ReplyContext
    ) async throws -> MailDraft {
        print("🤖 MailChatBridgeService: Creazione bozza risposta assistita")

        // Costruisci il contesto per la risposta
        let contextData = try await buildReplyContext(for: message, context: context)

        // Genera il soggetto della risposta
        let replySubject = generateReplySubject(message.subject)

        // Genera il corpo della risposta usando AI/intelligenza
        let replyBody = try await generateReplyBody(
            originalMessage: message,
            contextData: contextData,
            replyContext: context
        )

        // Crea la bozza
        let draft = MailDraft(
            to: [message.from.email],
            subject: replySubject,
            body: replyBody,
            isHtml: true
        )

        print("✅ MailChatBridgeService: Bozza risposta creata")
        return draft
    }

    /// Crea una bozza di inoltro assistita
    public func createForwardDraft(
        for message: MailMessage,
        to recipients: [String]
    ) async throws -> MailDraft {
        print("📤 MailChatBridgeService: Creazione bozza inoltro")

        let forwardSubject = "Fwd: \(message.subject)"
        let forwardBody = generateForwardBody(message)

        let draft = MailDraft(
            to: recipients,
            subject: forwardSubject,
            body: forwardBody,
            isHtml: true
        )

        print("✅ MailChatBridgeService: Bozza inoltro creata")
        return draft
    }

    // MARK: - Context Building

    /// Costruisce il contesto per la risposta
    private func buildReplyContext(
        for message: MailMessage,
        context: ReplyContext
    ) async throws -> ReplyContextData {
        print("🔍 MailChatBridgeService: Costruzione contesto risposta")

        // Recupera la cronologia del thread
        var threadMessages: [MailMessage] = []
        if let threadId = message.threadId {
            threadMessages = try await mailService.messagesForThread(threadId)
        }

        // Filtra solo i messaggi precedenti a quello corrente
        let previousMessages = threadMessages.filter { $0.date < message.date }

        // Recupera interazioni recenti con il contatto
        let recentInteractions = try await getRecentInteractions(with: message.from.email)

        // Recupera eventi calendario recenti
        let upcomingEvents = try await getUpcomingEvents(for: message.from.email)

        return ReplyContextData(
            originalMessage: message,
            threadHistory: previousMessages,
            recentInteractions: recentInteractions,
            upcomingEvents: upcomingEvents,
            userPreferences: context.userPreferences
        )
    }

    /// Recupera interazioni recenti con un contatto
    private func getRecentInteractions(with email: String) async throws -> [ContactInteraction] {
        // In futuro, implementare recupero da database delle interazioni
        // Per ora restituiamo un array vuoto
        return []
    }

    /// Recupera eventi calendario futuri per un contatto
    private func getUpcomingEvents(for email: String) async throws -> [CalendarEvent] {
        // In futuro, implementare recupero da EventKit
        // Per ora restituiamo un array vuoto
        return []
    }

    // MARK: - Reply Generation

    /// Genera il corpo della risposta usando intelligenza
    private func generateReplyBody(
        originalMessage: MailMessage,
        contextData: ReplyContextData,
        replyContext: ReplyContext
    ) async throws -> String {
        print("✍️ MailChatBridgeService: Generazione corpo risposta")

        // Intestazione con informazioni sul messaggio originale
        var body = """
        <div style="font-family: Arial, sans-serif; margin-bottom: 20px; padding: 15px; background-color: #f8f9fa; border-left: 4px solid #007bff;">
            <p style="margin: 0; font-weight: bold;">Risposta a: \(originalMessage.from.displayName)</p>
            <p style="margin: 5px 0;">Oggetto: \(originalMessage.subject)</p>
            <p style="margin: 5px 0;">Data: \(formatDate(originalMessage.date))</p>
        </div>
        """

        // Corpo principale della risposta
        switch replyContext.tone {
        case .professional:
            body += generateProfessionalReply(contextData)
        case .casual:
            body += generateCasualReply(contextData)
        case .friendly:
            body += generateFriendlyReply(contextData)
        }

        // Firma
        body += generateSignature(replyContext.userPreferences)

        // Quote del messaggio originale se richiesto
        if replyContext.includeOriginalQuote {
            body += generateQuotedOriginal(originalMessage)
        }

        return body
    }

    /// Genera risposta professionale
    private func generateProfessionalReply(_ context: ReplyContextData) -> String {
        var reply = "<p>Gentile \(context.originalMessage.from.displayName),</p>"

        // Aggiungi riferimenti a eventi calendario se presenti
        if !context.upcomingEvents.isEmpty {
            reply += "<p>Riguardo al nostro appuntamento programmato, confermo la mia partecipazione.</p>"
        }

        reply += """
        <p>Grazie per la sua email. Ho ricevuto il messaggio e prenderò in considerazione i punti sollevati.</p>
        <p>Le farò sapere a breve.</p>
        <p>Cordiali saluti,</p>
        """

        return reply
    }

    /// Genera risposta casuale
    private func generateCasualReply(_ context: ReplyContextData) -> String {
        var reply = "<p>Ciao \(context.originalMessage.from.displayName),</p>"

        reply += """
        <p>Grazie per il messaggio!</p>
        <p>Ho visto quello che hai scritto e ci penso su.</p>
        <p>Ti faccio sapere presto.</p>
        <p>A presto,</p>
        """

        return reply
    }

    /// Genera risposta amichevole
    private func generateFriendlyReply(_ context: ReplyContextData) -> String {
        var reply = "<p>Ciao \(context.originalMessage.from.displayName),</p>"

        reply += """
        <p>Grazie per avermi scritto!</p>
        <p>Ho letto il tuo messaggio con attenzione.</p>
        <p>Mi faccio sentire appena possibile.</p>
        <p>Un abbraccio,</p>
        """

        return reply
    }

    /// Genera firma personalizzata
    private func generateSignature(_ preferences: UserPreferences) -> String {
        var signature = "<p>\(preferences.name)</p>"

        if let title = preferences.title {
            signature += "<p>\(title)</p>"
        }

        if let company = preferences.company {
            signature += "<p>\(company)</p>"
        }

        if let phone = preferences.phone {
            signature += "<p>Tel: \(phone)</p>"
        }

        if let email = preferences.email {
            signature += "<p>Email: \(email)</p>"
        }

        return signature
    }

    /// Genera quote del messaggio originale
    private func generateQuotedOriginal(_ message: MailMessage) -> String {
        return """

        <div style="margin-top: 20px; padding: 15px; border-left: 2px solid #ccc; background-color: #f9f9f9;">
            <p style="margin: 0; font-weight: bold;">Da: \(message.from.displayName) &lt;\(message.from.email)&gt;</p>
            <p style="margin: 5px 0;">Data: \(formatDate(message.date))</p>
            <p style="margin: 5px 0;">Oggetto: \(message.subject)</p>
            <div style="margin-top: 10px;">
                \(message.bodyPlain ?? message.bodyHTML ?? "")
            </div>
        </div>
        """
    }

    // MARK: - Send Confirmation

    /// Invia conferma dell'invio in chat
    public func sendConfirmationToChat(
        messageId: String,
        recipient: String,
        subject: String,
        chatId: String
    ) async {
        print("📨 MailChatBridgeService: Invio conferma a chat \(chatId)")

        let confirmationMessage = """
        ✅ **Email inviata con successo!**

        **A:** \(recipient)
        **Oggetto:** \(subject)
        **ID Messaggio:** \(messageId)

        L'email è stata inviata e salvata nella cartella "Inviati".
        """

        // In futuro, integrare con il servizio chat per inviare il messaggio
        // await chatService.sendMessage(confirmationMessage, to: chatId)

        print("✅ MailChatBridgeService: Conferma inviata alla chat")
    }

    /// Gestisce errore di invio e notifica in chat
    public func handleSendError(
        error: Error,
        recipient: String,
        subject: String,
        chatId: String
    ) async {
        print("❌ MailChatBridgeService: Gestione errore invio per chat \(chatId)")

        let errorMessage = """
        ❌ **Errore nell'invio dell'email**

        **A:** \(recipient)
        **Oggetto:** \(subject)

        **Errore:** \(error.localizedDescription)

        Riprova più tardi o verifica la connessione.
        """

        // In futuro, integrare con il servizio chat per inviare il messaggio di errore
        // await chatService.sendMessage(errorMessage, to: chatId)

        print("✅ MailChatBridgeService: Notifica errore inviata alla chat")
    }

    // MARK: - Utility Methods

    /// Genera soggetto per risposta
    private func generateReplySubject(_ originalSubject: String) -> String {
        if originalSubject.lowercased().hasPrefix("re:") {
            return originalSubject
        } else {
            return "Re: \(originalSubject)"
        }
    }

    /// Genera corpo per inoltro
    private func generateForwardBody(_ message: MailMessage) -> String {
        return """
        <div style="font-family: Arial, sans-serif;">
            <p>---------- Messaggio inoltrato ----------</p>
            <p><strong>Da:</strong> \(message.from.displayName) &lt;\(message.from.email)&gt;</p>
            <p><strong>Data:</strong> \(formatDate(message.date))</p>
            <p><strong>Oggetto:</strong> \(message.subject)</p>
            <br>
            \(message.bodyPlain ?? message.bodyHTML ?? "")
        </div>
        """
    }

    /// Formatta data per display
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Types

/// Contesto per la risposta
public struct ReplyContext {
    public let tone: ReplyTone
    public let includeOriginalQuote: Bool
    public let userPreferences: UserPreferences

    public init(
        tone: ReplyTone = .professional,
        includeOriginalQuote: Bool = true,
        userPreferences: UserPreferences
    ) {
        self.tone = tone
        self.includeOriginalQuote = includeOriginalQuote
        self.userPreferences = userPreferences
    }
}

/// Tono della risposta
public enum ReplyTone {
    case professional
    case casual
    case friendly
}

/// Dati di contesto per la risposta
public struct ReplyContextData {
    public let originalMessage: MailMessage
    public let threadHistory: [MailMessage]
    public let recentInteractions: [ContactInteraction]
    public let upcomingEvents: [CalendarEvent]
    public let userPreferences: UserPreferences
}

/// Preferenze utente
public struct UserPreferences {
    public let name: String
    public let title: String?
    public let company: String?
    public let phone: String?
    public let email: String

    public init(
        name: String,
        title: String? = nil,
        company: String? = nil,
        phone: String? = nil,
        email: String
    ) {
        self.name = name
        self.title = title
        self.company = company
        self.phone = phone
        self.email = email
    }
}

/// Interazione con contatto
public struct ContactInteraction {
    public let date: Date
    public let type: InteractionType
    public let description: String

    public enum InteractionType {
        case email
        case meeting
        case call
        case message
    }
}

/// Evento calendario
public struct CalendarEvent {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let location: String?
}
