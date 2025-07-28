import Foundation
import CoreData
import Combine
import SwiftUI

// MARK: - Email Chat Service
// Servizio specializzato per la gestione delle chat mail con analisi thread e generazione risposte

@MainActor
public class EmailChatService: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var emailChats: [ChatMarilena] = []
    @Published public var isLoading = false
    @Published public var error: String?
    @Published public var currentEmailChat: ChatMarilena?
    
    // MARK: - Private Properties
    private let emailService = EmailService()
    private let aiService = EmailAIService()
    private let context: NSManagedObjectContext
    private let profiloService = ProfiloUtenteService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(context: NSManagedObjectContext? = nil) {
        print("🔧 EmailChatService: Inizializzazione...")
        self.context = context ?? PersistenceController.shared.container.viewContext
        print("🔧 EmailChatService: Context configurato")
        setupObservers()
        loadEmailChats()
        print("✅ EmailChatService: Inizializzazione completata")
    }
    
    // MARK: - Public Methods
    
    /// Crea una nuova chat mail per un'email
    public func createEmailChat(for email: EmailMessage) async -> ChatMarilena? {
        isLoading = true
        error = nil
        
        do {
            // Verifica se esiste già una chat per questo mittente
            if let existingChat = await findExistingEmailChat(for: email.from) {
                // Aggiorna la chat esistente
                await updateExistingEmailChat(existingChat, with: email)
                currentEmailChat = existingChat
                isLoading = false
                return existingChat
            }
            
            // Crea una nuova chat mail
            let newChat = ChatMarilena(context: context)
            newChat.id = UUID()
            newChat.dataCreazione = Date()
            newChat.titolo = "Chat: \(email.from)"
            newChat.tipo = "email"
            newChat.emailSender = email.from
            newChat.emailSubject = email.subject
            newChat.emailThreadId = generateThreadId(for: email)
            newChat.lastEmailDate = email.date
            
            // Associa al profilo utente
            if let profilo = profiloService.ottieniProfiloUtente(in: context) {
                newChat.profilo = profilo
            }
            
            // Crea il thread email
            let emailThread = EmailThread(context: context)
            emailThread.id = UUID()
            emailThread.createdAt = Date()
            emailThread.sender = email.from
            emailThread.subject = email.subject
            emailThread.threadId = newChat.emailThreadId
            emailThread.accountId = emailService.currentAccount?.email
            emailThread.lastEmailDate = email.date
            emailThread.totalEmails = 1
            
            // Collega thread alla chat
            newChat.emailThread = emailThread
            
            // Aggiungi il primo messaggio (email ricevuta)
            let emailMessage = MessaggioMarilena(context: context)
            emailMessage.id = UUID()
            emailMessage.contenuto = """
            📧 **Nuova Email Ricevuta**
            
            **Da:** \(email.from)
            **Oggetto:** \(email.subject)
            **Data:** \(formatDate(email.date))
            
            **Contenuto:**
            \(email.body)
            """
            emailMessage.isUser = false
            emailMessage.tipo = "email"
            emailMessage.dataCreazione = email.date
            emailMessage.emailId = email.id
            emailMessage.chat = newChat
            
            // Analizza l'email e genera suggerimento di risposta
            await analyzeEmailAndGenerateResponse(for: email, in: newChat)
            
            try context.save()
            
            // Ricarica le chat
            loadEmailChats()
            
            currentEmailChat = newChat
            isLoading = false
            
            print("✅ EmailChatService: Creata nuova chat mail per \(email.from)")
            return newChat
            
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            print("❌ EmailChatService: Errore creazione chat mail: \(error)")
            return nil
        }
    }
    
    /// Carica tutte le chat mail esistenti
    public func loadEmailChats() {
        let fetchRequest: NSFetchRequest<ChatMarilena> = ChatMarilena.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "tipo == %@", "email")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ChatMarilena.lastEmailDate, ascending: false)]
        
        do {
            let chats = try context.fetch(fetchRequest)
            self.emailChats = chats
            print("✅ EmailChatService: Caricate \(chats.count) chat mail")
        } catch {
            print("❌ EmailChatService: Errore caricamento chat mail: \(error)")
            self.emailChats = []
        }
    }
    
    /// Invia una risposta email dalla chat
    public func sendEmailResponse(from chat: ChatMarilena, response: String) async throws {
        guard let sender = chat.emailSender else {
            throw EmailChatError.invalidChat
        }
        
        // Crea il messaggio di risposta nella chat
        let responseMessage = MessaggioMarilena(context: context)
        responseMessage.id = UUID()
        responseMessage.contenuto = response
        responseMessage.isUser = true
        responseMessage.tipo = "email_response"
        responseMessage.dataCreazione = Date()
        responseMessage.chat = chat
        
        // Invia l'email tramite EmailService
        let subject = chat.emailSubject ?? "Re: \(chat.titolo ?? "")"
        try await emailService.sendEmail(to: sender, subject: subject, body: response)
        
        // Aggiorna la data dell'ultima email
        chat.lastEmailDate = Date()
        
        try context.save()
        
        print("✅ EmailChatService: Risposta email inviata a \(sender)")
    }
    
    /// Analizza un thread email e genera suggerimenti
    public func analyzeEmailThread(for chat: ChatMarilena) async -> EmailThreadAnalysis? {
        guard let _ = chat.emailThreadId,
              let sender = chat.emailSender else {
            return nil
        }
        
        // Recupera le ultime 10 email dal mittente
        let recentEmails = await getRecentEmailsFromSender(sender, limit: 10)
        
        // Analizza il thread
        let analysis = EmailThreadAnalysis(
            sender: sender,
            totalEmails: recentEmails.count,
            lastEmailDate: recentEmails.first?.date ?? Date(),
            conversationTone: analyzeConversationTone(emails: recentEmails),
            urgency: determineUrgency(emails: recentEmails),
            suggestedResponseType: suggestResponseType(emails: recentEmails),
            context: buildConversationContext(emails: recentEmails)
        )
        
        return analysis
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        print("🔧 EmailChatService: Setup observers...")
        
        // Osserva nuove email per creare automaticamente chat
        let publisher = NotificationCenter.default.publisher(for: .newEmailReceived)
        let cancellable = publisher.sink { [weak self] notification in
            print("📧 EmailChatService: Notifica ricevuta!")
            if let email = notification.object as? EmailMessage {
                print("📧 EmailChatService: Email ricevuta da \(email.from)")
                Task {
                    await self?.handleNewEmail(email)
                }
            } else {
                print("❌ EmailChatService: Oggetto notifica non è EmailMessage")
            }
        }
        cancellables.insert(cancellable)
        
        print("✅ EmailChatService: Observer configurato")
    }
    
    private func handleNewEmail(_ email: EmailMessage) async {
        print("📧 EmailChatService: Gestione nuova email da \(email.from)")
        
        // Verifica se esiste già una chat per questo mittente
        if let existingChat = findExistingEmailChatSync(for: email.from) {
            print("📧 EmailChatService: Chat esistente trovata per \(email.from), aggiornamento...")
            await updateExistingEmailChat(existingChat, with: email)
            
            // Notifica l'aggiornamento della chat
            NotificationCenter.default.post(
                name: .emailChatCreated,
                object: existingChat,
                userInfo: ["email": email, "action": "updated"]
            )
            
            print("✅ EmailChatService: Chat aggiornata per \(email.from)")
        } else if shouldCreateEmailChat(for: email) {
            // Crea automaticamente una chat mail per email nuove e importanti
            print("📧 EmailChatService: Nuova email ricevuta da \(email.from) - Creazione chat automatica...")
            
            if let chat = await createEmailChat(for: email) {
                // Notifica la creazione della chat
                NotificationCenter.default.post(
                    name: .emailChatCreated,
                    object: chat,
                    userInfo: ["email": email, "action": "created"]
                )
                
                print("✅ EmailChatService: Chat mail creata automaticamente per \(email.from)")
            } else {
                print("❌ EmailChatService: Errore nella creazione automatica della chat per \(email.from)")
            }
        } else {
            print("📧 EmailChatService: Email da \(email.from) non qualificata per chat automatica")
        }
    }
    
    private func shouldCreateEmailChat(for email: EmailMessage) -> Bool {
        // Verifica che sia un'email ricevuta
        guard email.emailType == .received else {
            print("📧 EmailChatService: Email non ricevuta, skip creazione chat")
            return false
        }
        
        // Verifica che l'email non sia troppo vecchia (più di 1 ora)
        let oneHourAgo = Date().addingTimeInterval(-3600)
        guard email.date > oneHourAgo else {
            print("📧 EmailChatService: Email troppo vecchia (\(email.date)), skip creazione chat")
            return false
        }
        
        // Verifica che non esista già una chat per questo mittente
        let existingChat = findExistingEmailChatSync(for: email.from)
        if existingChat != nil {
            print("📧 EmailChatService: Chat già esistente per \(email.from), aggiorna invece di creare")
            return false
        }
        
        // Verifica che l'email non sia già stata processata
        if isEmailAlreadyProcessed(email) {
            print("📧 EmailChatService: Email già processata (\(email.id)), skip creazione chat")
            return false
        }
        
        print("📧 EmailChatService: Email qualificata per creazione chat: \(email.from)")
        return true
    }
    
    private func findExistingEmailChat(for sender: String) async -> ChatMarilena? {
        let fetchRequest: NSFetchRequest<ChatMarilena> = ChatMarilena.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "emailSender == %@ AND tipo == %@", sender, "email")
        fetchRequest.fetchLimit = 1
        
        do {
            let chats = try context.fetch(fetchRequest)
            return chats.first
        } catch {
            print("❌ EmailChatService: Errore ricerca chat esistente: \(error)")
            return nil
        }
    }
    
    private func findExistingEmailChatSync(for sender: String) -> ChatMarilena? {
        let fetchRequest: NSFetchRequest<ChatMarilena> = ChatMarilena.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "emailSender == %@ AND tipo == %@", sender, "email")
        fetchRequest.fetchLimit = 1
        
        do {
            let chats = try context.fetch(fetchRequest)
            return chats.first
        } catch {
            print("❌ EmailChatService: Errore ricerca chat esistente: \(error)")
            return nil
        }
    }
    
    private func isEmailAlreadyProcessed(_ email: EmailMessage) -> Bool {
        // Verifica se l'email è già stata processata controllando i messaggi esistenti
        let fetchRequest: NSFetchRequest<MessaggioMarilena> = MessaggioMarilena.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "emailId == %@", email.id)
        
        do {
            let messages = try context.fetch(fetchRequest)
            return !messages.isEmpty
        } catch {
            print("❌ EmailChatService: Errore verifica email processata: \(error)")
            return false
        }
    }
    
    private func updateExistingEmailChat(_ chat: ChatMarilena, with email: EmailMessage) async {
        // Aggiorna la data dell'ultima email
        chat.lastEmailDate = email.date
        
        // Aggiungi il nuovo messaggio email
        let emailMessage = MessaggioMarilena(context: context)
        emailMessage.id = UUID()
        emailMessage.contenuto = """
        📧 **Nuova Email Ricevuta**
        
        **Da:** \(email.from)
        **Oggetto:** \(email.subject)
        **Data:** \(formatDate(email.date))
        
        **Contenuto:**
        \(email.body)
        """
        emailMessage.isUser = false
        emailMessage.tipo = "email"
        emailMessage.dataCreazione = email.date
        emailMessage.emailId = email.id
        emailMessage.chat = chat
        
        // Analizza e genera suggerimento
        await analyzeEmailAndGenerateResponse(for: email, in: chat)
        
        try? context.save()
    }
    
    private func generateThreadId(for email: EmailMessage) -> String {
        // Genera un ID univoco per il thread basato su mittente e oggetto
        let base = "\(email.from)_\(email.subject)"
        return base.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "@", with: "_")
            .replacingOccurrences(of: ".", with: "_")
    }
    
    private func analyzeEmailAndGenerateResponse(for email: EmailMessage, in chat: ChatMarilena) async {
        print("🤖 EmailChatService: Avvio analisi AI per email da \(email.from)")
        
        do {
            // Analizza l'email
            let analysis = await aiService.analyzeEmail(email)
            let summary = await aiService.summarizeEmail(email)
            
            // Genera suggerimento di risposta
            let responseType = analysis != nil ? suggestResponseType(for: analysis!) : .custom
            
            // Crea messaggio AI con analisi
            let aiMessage = MessaggioMarilena(context: context)
            aiMessage.id = UUID()
            aiMessage.contenuto = """
            🤖 **Analisi AI**
            
            **Mittente:** \(email.from)
            **Oggetto:** \(email.subject)
            **Data:** \(formatDate(email.date))
            
            \(analysis != nil ? """
            **Categoria:** \(analysis!.category.displayName)
            **Urgenza:** \(analysis!.urgency.displayName)
            **Tono:** \(analysis!.tone)
            """ : "**Analisi:** Non disponibile")
            
            \(summary != nil ? """
            **Riassunto:**
            \(summary!)
            """ : "")
            
            **Suggerimento:** \(responseType.displayName)
            
            Clicca per generare una risposta \(responseType.displayName.lowercased()).
            """
            aiMessage.isUser = false
            aiMessage.tipo = "ai_suggestion"
            aiMessage.dataCreazione = Date()
            aiMessage.emailResponseType = responseType.rawValue
            aiMessage.chat = chat
            
            print("✅ EmailChatService: Analisi AI completata per \(email.from)")
            
        } catch {
            print("❌ EmailChatService: Errore analisi AI per \(email.from): \(error)")
            
            // Crea messaggio di fallback
            let fallbackMessage = MessaggioMarilena(context: context)
            fallbackMessage.id = UUID()
            fallbackMessage.contenuto = """
            🤖 **Analisi AI**
            
            **Mittente:** \(email.from)
            **Oggetto:** \(email.subject)
            **Data:** \(formatDate(email.date))
            
            **Stato:** Analisi non disponibile
            **Suggerimento:** Genera risposta personalizzata
            
            Clicca per generare una risposta personalizzata.
            """
            fallbackMessage.isUser = false
            fallbackMessage.tipo = "ai_suggestion"
            fallbackMessage.dataCreazione = Date()
            fallbackMessage.emailResponseType = EmailResponseType.custom.rawValue
            fallbackMessage.chat = chat
        }
    }
    
    private func getRecentEmailsFromSender(_ sender: String, limit: Int) async -> [EmailMessage] {
        // Recupera le email recenti dal mittente dalla cache
        let cachedEmails = emailService.emails.filter { $0.from == sender }
        return Array(cachedEmails.prefix(limit))
    }
    
    private func analyzeConversationTone(emails: [EmailMessage]) -> String {
        // Analisi semplificata del tono della conversazione
        let urgentKeywords = ["urgente", "immediato", "asap", "subito"]
        let formalKeywords = ["cordiali saluti", "distinti saluti", "gentile"]
        let informalKeywords = ["ciao", "salve", "grazie"]
        
        let allContent = emails.map { $0.body + " " + $0.subject }.joined(separator: " ").lowercased()
        
        if urgentKeywords.contains(where: { allContent.contains($0) }) {
            return "urgente"
        } else if formalKeywords.contains(where: { allContent.contains($0) }) {
            return "formale"
        } else if informalKeywords.contains(where: { allContent.contains($0) }) {
            return "informale"
        } else {
            return "neutro"
        }
    }
    
    private func determineUrgency(emails: [EmailMessage]) -> EmailUrgency {
        let urgentKeywords = ["urgente", "immediato", "asap", "subito", "importante"]
        let allContent = emails.map { $0.body + " " + $0.subject }.joined(separator: " ").lowercased()
        
        if urgentKeywords.contains(where: { allContent.contains($0) }) {
            return .high
        } else if emails.count > 5 {
            return .medium
        } else {
            return .normal
        }
    }
    
    private func suggestResponseType(for analysis: EmailAnalysis) -> EmailResponseType {
        switch analysis.urgency {
        case .high:
            return .yes // Risposta rapida per urgenze
        case .medium:
            return .custom // Risposta personalizzata
        case .normal:
            return .no // Risposta negativa per email normali
        case .low:
            return .no // Risposta negativa per email a bassa priorità
        }
    }
    
    private func suggestResponseType(emails: [EmailMessage]) -> EmailResponseType {
        // Logica semplificata per suggerire tipo di risposta
        if emails.count > 3 {
            return .yes // Conversazione attiva
        } else if emails.first?.subject.localizedCaseInsensitiveContains("urgente") == true {
            return .yes // Urgenza
        } else {
            return .no // Email singola
        }
    }
    
    private func buildConversationContext(emails: [EmailMessage]) -> String {
        let recentEmails = emails.prefix(3)
        return recentEmails.map { email in
            """
            **\(formatDate(email.date)) - \(email.subject)**
            \(email.body)
            """
        }.joined(separator: "\n\n")
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Types

public enum EmailResponseType: String, CaseIterable {
    case yes = "yes"
    case no = "no"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .yes: return "Sì"
        case .no: return "No"
        case .custom: return "Personalizzata"
        }
    }
    
    var icon: String {
        switch self {
        case .yes: return "checkmark.circle.fill"
        case .no: return "xmark.circle.fill"
        case .custom: return "pencil.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .yes: return .green
        case .no: return .red
        case .custom: return .blue
        }
    }
}

public struct EmailThreadAnalysis {
    let sender: String
    let totalEmails: Int
    let lastEmailDate: Date
    let conversationTone: String
    let urgency: EmailUrgency
    let suggestedResponseType: EmailResponseType
    let context: String
}

public enum EmailChatError: Error, LocalizedError {
    case invalidChat
    case noSender
    case sendFailed
    
    public var errorDescription: String? {
        switch self {
        case .invalidChat:
            return "Chat email non valida"
        case .noSender:
            return "Mittente non trovato"
        case .sendFailed:
            return "Invio email fallito"
        }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let newEmailReceived = Notification.Name("newEmailReceived")
    static let emailChatCreated = Notification.Name("emailChatCreated")
} 