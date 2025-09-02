import Foundation
import CoreData
import Combine
import SwiftUI
import NaturalLanguage

// MARK: - Enhanced Email Chat Service
// Servizio potenziato che integra email, chat e trascrizioni per assistenza Marilena completa

@MainActor
public class EnhancedEmailChatService: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var emailChats: [ChatMarilena] = []
    @Published public var isLoading = false
    @Published public var error: String?
    @Published public var currentEmailChat: ChatMarilena?
    @Published public var availableTranscriptions: [Trascrizione] = []
    @Published public var selectedTranscription: Trascrizione?
    @Published public var contextualSuggestions: [String] = []
    
    // MARK: - Private Properties
    private let emailService = EmailService()
    private let aiService = EmailAIService()
    private let transcriptionService = ModularTranscriptionService()
    private let emailChatService: EmailChatService
    private let context: NSManagedObjectContext
    private let profiloService = ProfiloUtenteService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(context: NSManagedObjectContext? = nil) {
        print("🚀 EnhancedEmailChatService: Inizializzazione...")
        self.context = context ?? PersistenceController.shared.container.viewContext
        self.emailChatService = EmailChatService(context: self.context)
        setupObservers()
        loadAvailableTranscriptions()
        print("✅ EnhancedEmailChatService: Inizializzazione completata")
    }
    
    // MARK: - Main Workflow Methods
    
    /// Workflow principale: Marilena risponde a un'email usando trascrizioni come contesto
    public func startEmailResponseWorkflow(for email: EmailMessage, with transcription: Trascrizione? = nil) async -> ChatMarilena? {
        print("📧 EnhancedEmailChatService: Avvio workflow per email da \(email.from)")
        
        isLoading = true
        error = nil
        
        do {
            // 1. Crea o ottieni chat email esistente
            guard let emailChat = await emailChatService.createEmailChat(for: email) else {
                throw EnhancedEmailChatError.chatCreationFailed
            }
            
            currentEmailChat = emailChat
            
            // 2. Se è stata fornita una trascrizione, integrala nel contesto
            if let transcription = transcription {
                selectedTranscription = transcription
                await integrateTranscriptionContext(transcription, into: emailChat)
            }
            
            // 3. Genera contesto assistente Marilena personalizzato
            await generateMarilenaContext(for: email, in: emailChat, withTranscription: transcription)
            
            // 4. Suggerisci risposte contestuali
            await generateContextualSuggestions(for: email, withTranscription: transcription)
            
            isLoading = false
            print("✅ EnhancedEmailChatService: Workflow completato per \(email.from)")
            return emailChat
            
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            print("❌ EnhancedEmailChatService: Errore workflow: \(error)")
            return nil
        }
    }
    
    /// Marilena raccoglie informazioni dalle trascrizioni per rispondere all'email
    public func gatherInformationFromTranscriptions(for email: EmailMessage, question: String) async -> String? {
        print("🔍 EnhancedEmailChatService: Raccolta informazioni per: \(question)")
        
        // Analizza tutte le trascrizioni disponibili per trovare informazioni pertinenti
        var relevantInformation: [String] = []
        
        for transcription in availableTranscriptions {
            if let transcriptionText = transcription.testoCompleto,
               let relevantInfo = await extractRelevantInfo(from: transcriptionText, for: question) {
                relevantInformation.append(relevantInfo)
            }
        }
        
        if relevantInformation.isEmpty {
            return nil
        }
        
        // Combina e sintetizza le informazioni trovate
        let combinedInfo = relevantInformation.joined(separator: "\n\n---\n\n")
        return await synthesizeInformation(combinedInfo, for: question)
    }
    
    /// Genera risposta email usando informazioni raccolte + approvazione utente
    public func generateEmailResponseWithApproval(
        for email: EmailMessage,
        using gatheredInfo: String? = nil,
        withTranscription transcription: Trascrizione? = nil,
        customInstructions: String? = nil
    ) async -> EmailDraft? {
        
        print("✍️ EnhancedEmailChatService: Generazione bozza email per \(email.from)")
        
        // Costruisci il contesto completo per la generazione
        var fullContext = "Informazioni di contesto per rispondere all'email:\n\n"
        
        // Aggiungi informazioni raccolte dalle trascrizioni
        if let gatheredInfo = gatheredInfo {
            fullContext += "**Informazioni dalle registrazioni:**\n\(gatheredInfo)\n\n"
        }
        
        // Aggiungi trascrizione specifica se disponibile
        if let transcription = transcription,
           let transcriptionText = transcription.testoCompleto {
            fullContext += "**Trascrizione recente:**\n\(transcriptionText)\n\n"
        }
        
        // Aggiungi istruzioni personalizzate
        if let customInstructions = customInstructions {
            fullContext += "**Istruzioni specifiche:**\n\(customInstructions)\n\n"
        }
        
        fullContext += """
        **Email originale:**
        Da: \(email.from)
        Oggetto: \(email.subject)
        Contenuto: \(email.body)
        
        Genera una risposta professionale e pertinente basata sulle informazioni di contesto fornite.
        """
        
        return await aiService.generateCustomResponse(for: email, basedOn: nil, withPrompt: fullContext)
    }
    
    /// Salva la bozza nel canvas per approvazione/modifica
    public func saveToCanvasForApproval(_ draft: EmailDraft, in chat: ChatMarilena) async {
        print("📝 EnhancedEmailChatService: Salvataggio bozza nel canvas")
        
        // Crea messaggio di bozza nel canvas
        let canvasMessage = MessaggioMarilena(context: context)
        canvasMessage.id = UUID()
        canvasMessage.contenuto = """
        📧 **Bozza di Risposta Generata**
        
        **Destinatario:** \(draft.originalEmail.from)
        **Oggetto:** Re: \(draft.originalEmail.subject)
        
        **Contenuto proposto:**
        \(draft.content)
        
        ✏️ **Puoi modificare questa bozza direttamente qui sopra, poi cliccare "Approva e Invia" quando sei soddisfatto.**
        """
        canvasMessage.isUser = false
        canvasMessage.tipo = "email_draft_canvas"
        canvasMessage.dataCreazione = Date()
        canvasMessage.emailId = draft.originalEmail.id
        canvasMessage.chat = chat
        
        // Aggiungi metadati per il canvas
        canvasMessage.emailResponseDraft = draft.content
        canvasMessage.emailCanEdit = true
        
        try? context.save()
        
        print("✅ EnhancedEmailChatService: Bozza salvata nel canvas")
    }
    
    /// Approva e invia la bozza modificata
    public func approveAndSendDraft(from chat: ChatMarilena, modifiedContent: String) async throws {
        guard let sender = chat.emailSender else {
            throw EnhancedEmailChatError.invalidChat
        }
        
        print("📤 EnhancedEmailChatService: Approvazione e invio bozza a \(sender)")
        
        // Invia l'email tramite il servizio standard
        try await emailChatService.sendEmailResponse(from: chat, response: modifiedContent)
        
        // Crea messaggio di conferma con stile Marilena
        let confirmationMessage = MessaggioMarilena(context: context)
        confirmationMessage.id = UUID()
        confirmationMessage.contenuto = """
        ✅ **Email Inviata con Successo!**
        
        La tua risposta è stata inviata a **\(sender)**.
        
        🤖 **Marilena dice:** "Perfetto! Ho utilizzato le informazioni dalle tue registrazioni per creare una risposta pertinente. Hai fatto delle ottime modifiche!"
        
        C'è altro che posso fare per te?
        """
        confirmationMessage.isUser = false
        confirmationMessage.tipo = "email_sent_confirmation"
        confirmationMessage.dataCreazione = Date()
        confirmationMessage.chat = chat
        
        try context.save()
        
        print("✅ EnhancedEmailChatService: Email inviata e confermata")
    }
    
    // MARK: - Transcription Integration
    
    private func loadAvailableTranscriptions() {
        let fetchRequest: NSFetchRequest<Trascrizione> = Trascrizione.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Trascrizione.dataCreazione, ascending: false)]
        fetchRequest.fetchLimit = 10 // Ultime 10 trascrizioni
        
        do {
            availableTranscriptions = try context.fetch(fetchRequest)
            print("✅ EnhancedEmailChatService: Caricate \(availableTranscriptions.count) trascrizioni")
        } catch {
            print("❌ EnhancedEmailChatService: Errore caricamento trascrizioni: \(error)")
        }
    }
    
    private func integrateTranscriptionContext(_ transcription: Trascrizione, into chat: ChatMarilena) async {
        guard let transcriptionText = transcription.testoCompleto else { return }
        
        // Crea messaggio di contesto trascrizione
        let transcriptionContext = MessaggioMarilena(context: context)
        transcriptionContext.id = UUID()
        transcriptionContext.contenuto = """
        🎤 **Trascrizione Integrata nel Contesto**
        
        **Titolo:** Registrazione Audio
        **Data:** \(formatDate(transcription.dataCreazione ?? Date()))
        **Parole:** \(transcription.paroleTotali) totali
        
        **Contenuto:**
        \(transcriptionText)
        
        💡 **Marilena userà queste informazioni per aiutarti a rispondere all'email.**
        """
        transcriptionContext.isUser = false
        transcriptionContext.tipo = "transcription_context"
        transcriptionContext.dataCreazione = Date()
        transcriptionContext.chat = chat
        
        try? context.save()
    }
    
    private func generateMarilenaContext(for email: EmailMessage, in chat: ChatMarilena, withTranscription transcription: Trascrizione?) async {
        
        let marilenaMessage = MessaggioMarilena(context: context)
        marilenaMessage.id = UUID()
        
        var contextContent = """
        🤖 **Ciao! Sono Marilena, la tua assistente AI.**
        
        Ho ricevuto questa email da **\(email.from)**:
        
        **Oggetto:** \(email.subject)
        **Contenuto:** \(email.body)
        
        """
        
        if transcription != nil {
            contextContent += """
            🎯 **Ho anche accesso alla tua trascrizione recente** che potrebbe contenere informazioni utili per rispondere.

            """
        }
        
        contextContent += """
        **Come posso aiutarti:**
        1. 🔍 Posso cercare informazioni nelle tue registrazioni
        2. ✍️ Genererò una bozza di risposta basata su quello che trovo  
        3. 📝 Tu potrai modificarla direttamente nel canvas prima dell'invio
        4. 📤 Quando sei soddisfatto, io la invierò per te
        
        **Cosa vuoi che faccia?** Scrivimi qui sotto o usa i pulsanti rapidi.
        """
        
        marilenaMessage.contenuto = contextContent
        marilenaMessage.isUser = false
        marilenaMessage.tipo = "marilena_context"
        marilenaMessage.dataCreazione = Date()
        marilenaMessage.chat = chat
        
        try? context.save()
    }
    
    private func generateContextualSuggestions(for email: EmailMessage, withTranscription transcription: Trascrizione?) async {
        var suggestions: [String] = []
        
        // Analizza l'email per suggerimenti intelligenti
        let emailAnalysis = await aiService.analyzeEmail(email)
        
        if let analysis = emailAnalysis {
            switch analysis.category {
            case .work:
                suggestions.append("Cerca informazioni lavorative nelle registrazioni")
                suggestions.append("Genera risposta professionale")
            case .personal:
                suggestions.append("Cerca informazioni personali nelle registrazioni")
                suggestions.append("Genera risposta informale")
            case .notifications:
                suggestions.append("Conferma ricezione")
                suggestions.append("Archivia notifica")
            case .promotional:
                suggestions.append("Declina educatamente")
                suggestions.append("Richiedi rimozione dalla lista")
            case .newsletter:
                suggestions.append("Leggi contenuti interessanti")
                suggestions.append("Condividi con colleghi")
            case .social:
                suggestions.append("Rispondi ai messaggi sociali")
                suggestions.append("Aggiorna stato social")
            case .finance:
                suggestions.append("Verifica informazioni finanziarie")
                suggestions.append("Contatta supporto finanziario")
            case .travel:
                suggestions.append("Controlla prenotazioni viaggio")
                suggestions.append("Cerca informazioni locali")
            case .shopping:
                suggestions.append("Verifica ordini in corso")
                suggestions.append("Gestisci resi e rimborsi")
            case .other:
                suggestions.append("Archivia per riferimento futuro")
                suggestions.append("Classifica manualmente")
            }
        }
        
        // Aggiungi suggerimenti specifici se c'è una trascrizione
        if transcription != nil {
            suggestions.append("Usa informazioni dalla trascrizione recente")
            suggestions.append("Combina email + trascrizione per risposta completa")
        }
        
        // Suggerimenti generali
        suggestions.append("Chiedi più tempo per rispondere")
        suggestions.append("Programma meeting")
        suggestions.append("Forwarda a qualcun altro")
        
        contextualSuggestions = Array(suggestions.prefix(6))
    }
    
    // MARK: - Information Extraction
    
    private func extractRelevantInfo(from transcriptionText: String, for question: String) async -> String? {
        // Usa NaturalLanguage per trovare informazioni pertinenti
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = transcriptionText
        
        // Estrai parole chiave dalla domanda
        let questionKeywords = extractKeywords(from: question)
        
        // Cerca frasi pertinenti nella trascrizione
        let sentences = transcriptionText.components(separatedBy: ".")
        var relevantSentences: [String] = []
        
        for sentence in sentences {
            let sentenceKeywords = extractKeywords(from: sentence)
            let similarity = calculateSimilarity(questionKeywords, sentenceKeywords)
            
            if similarity > 0.3 {
                relevantSentences.append(sentence.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        
        if relevantSentences.isEmpty {
            return nil
        }
        
        return relevantSentences.prefix(3).joined(separator: ". ")
    }
    
    private func synthesizeInformation(_ combinedInfo: String, for question: String) async -> String {
        // Per ora una sintesi semplice, in futuro si può usare AI
        return """
        **Informazioni trovate nelle tue registrazioni:**
        
        \(combinedInfo)
        
        **Sintesi:** Queste informazioni potrebbero essere utili per rispondere alla domanda: "\(question)"
        """
    }
    
    // MARK: - Helper Methods
    
    private func setupObservers() {
        // Osserva i cambiamenti dell'EmailChatService base
        emailChatService.$emailChats
            .receive(on: DispatchQueue.main)
            .assign(to: &$emailChats)
        
        emailChatService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)
        
        emailChatService.$error
            .receive(on: DispatchQueue.main)
            .assign(to: &$error)
    }
    
    private func extractKeywords(from text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        
        var keywords: [String] = []
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            let word = String(text[tokenRange]).lowercased()
            
            if let tag = tag, (tag == .noun || tag == .verb) && word.count > 3 {
                keywords.append(word)
            }
            
            return true
        }
        
        return keywords
    }
    
    private func calculateSimilarity(_ keywords1: [String], _ keywords2: [String]) -> Double {
        let set1 = Set(keywords1)
        let set2 = Set(keywords2)
        
        let intersection = set1.intersection(set2)
        let union = set1.union(set2)
        
        guard !union.isEmpty else { return 0.0 }
        
        return Double(intersection.count) / Double(union.count)
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

public enum EnhancedEmailChatError: Error, LocalizedError {
    case chatCreationFailed
    case invalidChat
    case noTranscriptions
    case informationExtractionFailed
    
    public var errorDescription: String? {
        switch self {
        case .chatCreationFailed:
            return "Impossibile creare chat email"
        case .invalidChat:
            return "Chat email non valida"
        case .noTranscriptions:
            return "Nessuna trascrizione disponibile"
        case .informationExtractionFailed:
            return "Impossibile estrarre informazioni dalle trascrizioni"
        }
    }
}

// MARK: - Quick Response Types

public enum QuickResponseType: String, CaseIterable {
    case searchTranscriptions = "search_transcriptions"
    case generateDraft = "generate_draft"
    case needMoreTime = "need_more_time"
    case scheduleMeeting = "schedule_meeting"
    case decline = "decline"
    case forward = "forward"
    
    public var displayName: String {
        switch self {
        case .searchTranscriptions: return "🔍 Cerca nelle registrazioni"
        case .generateDraft: return "✍️ Genera bozza"
        case .needMoreTime: return "⏰ Chiedi più tempo"
        case .scheduleMeeting: return "📅 Programma meeting"
        case .decline: return "❌ Declina"
        case .forward: return "📤 Inoltra"
        }
    }
    
    public var icon: String {
        switch self {
        case .searchTranscriptions: return "magnifyingglass"
        case .generateDraft: return "pencil.and.outline"
        case .needMoreTime: return "clock"
        case .scheduleMeeting: return "calendar"
        case .decline: return "xmark.circle"
        case .forward: return "arrowshape.turn.up.right"
        }
    }
}