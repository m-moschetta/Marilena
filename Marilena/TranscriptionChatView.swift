import SwiftUI
import CoreData
import NaturalLanguage
import Combine

struct TranscriptionChatView: View {
    @ObservedObject var chatService: TranscriptionChatService
    @State private var messageText = ""
    @State private var isTyping = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header con info trascrizione
            chatHeaderView
            
            // Messaggi chat
            messagesView
            
            // Input area
            messageInputView
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            chatService.loadMessages()
        }
    }
    
    // MARK: - Chat Header
    
    private var chatHeaderView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
                
                Text("Assistente AI Trascrizione")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Pulsante per aprire nella lista chat
                if let chat = chatService.chatMarilena {
                    Button(action: {
                        openChatInMainList(chat)
                    }) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .foregroundColor(.blue)
                            .font(.title3)
                    }
                }
                
                if let transcription = chatService.transcription {
                    Text("\(transcription.paroleTotali) parole")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }
            }
            
            Text("Fai domande sul contenuto della trascrizione. L'AI analizzerà il testo per fornirti risposte accurate.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
    
    // MARK: - Messages View
    
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if chatService.messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(chatService.messages, id: \.id) { message in
                            ChatMessageView(message: message)
                        }
                    }
                    
                    if chatService.isProcessing {
                        TypingIndicatorView()
                    }
                }
                .padding()
            }
            .onChange(of: chatService.messages.count) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: chatService.isProcessing) { _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 64))
                .foregroundColor(.gray.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Inizia la Conversazione")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text("Puoi fare domande come:")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                SuggestedQuestionView(
                    question: "Qual è l'argomento principale?",
                    icon: "doc.text.magnifyingglass"
                ) {
                    sendMessage("Qual è l'argomento principale discusso in questa registrazione?")
                }
                
                SuggestedQuestionView(
                    question: "Riassumi i punti chiave",
                    icon: "list.bullet.circle"
                ) {
                    sendMessage("Puoi riassumere i punti chiave di questa conversazione?")
                }
                
                SuggestedQuestionView(
                    question: "Cerca parole specifiche",
                    icon: "magnifyingglass.circle"
                ) {
                    sendMessage("Cerca riferimenti a date, nomi o luoghi importanti.")
                }
                
                SuggestedQuestionView(
                    question: "Analizza il sentiment",
                    icon: "heart.circle"
                ) {
                    sendMessage("Qual è il tono generale di questa conversazione?")
                }
            }
        }
        .padding()
    }
    
    // MARK: - Message Input
    
    private var messageInputView: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5)
            
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Fai una domanda sulla trascrizione...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .focused($isTextFieldFocused)
                    .disabled(chatService.isProcessing || chatService.transcription == nil)
                
                Button {
                    sendMessage(messageText)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(canSendMessage ? .blue : .gray)
                }
                .disabled(!canSendMessage)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Computed Properties
    
    private var canSendMessage: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
        !chatService.isProcessing && 
        chatService.transcription != nil
    }
    
    // MARK: - Actions
    
    private func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        Task {
            await chatService.sendMessage(text)
        }
        
        messageText = ""
        isTextFieldFocused = false
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = chatService.messages.last {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    private func openChatInMainList(_ chat: ChatMarilena) {
        // Posta una notifica per aprire la chat nella lista principale
        NotificationCenter.default.post(
            name: NSNotification.Name("OpenChatInMainList"),
            object: chat
        )
    }
}

// MARK: - Supporting Views

struct ChatMessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 50)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(6)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                        
                        Text(message.content)
                            .font(.body)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    
                    HStack(spacing: 4) {
                        Text(formatTime(message.timestamp))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if let confidence = message.confidence {
                            Text("• \(Int(confidence * 100))% sicurezza")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.leading, 32)
                }
                
                Spacer(minLength: 50)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct SuggestedQuestionView: View {
    let question: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                Text(question)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Image(systemName: "arrow.right.circle")
                    .font(.title3)
                    .foregroundColor(.blue.opacity(0.7))
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

struct TypingIndicatorView: View {
    @State private var animationPhase = 0
    
    var body: some View {
        HStack {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(6)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
                
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.primary.opacity(0.6))
                            .frame(width: 8, height: 8)
                            .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                            .animation(.easeInOut(duration: 0.6).repeatForever(), value: animationPhase)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            
            Spacer(minLength: 50)
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { timer in
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}

// MARK: - Chat Service

@MainActor
class TranscriptionChatService: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isProcessing = false
    @Published var chatMarilena: ChatMarilena?
    
    let recording: RegistrazioneAudio
    let transcription: Trascrizione?
    private let context: NSManagedObjectContext
    private let profiloService = ProfiloUtenteService.shared
    
    // NaturalLanguage components
    private let sentimentAnalyzer = NLTagger(tagSchemes: [.sentimentScore])
    private let languageRecognizer = NLLanguageRecognizer()
    private let tokenizer = NLTokenizer(unit: .sentence)
    
    init(recording: RegistrazioneAudio, context: NSManagedObjectContext) {
        self.recording = recording
        self.context = context
        
        // Ottieni la trascrizione più recente
        let transcriptions = recording.trascrizioni?.allObjects as? [Trascrizione] ?? []
        self.transcription = transcriptions.sorted { 
            ($0.dataCreazione ?? Date()) > ($1.dataCreazione ?? Date()) 
        }.first
        
        // Crea o recupera la chat per questa registrazione
        setupChatForRecording()
    }
    
    func loadMessages() {
        guard let chat = chatMarilena else { return }
        
        // Carica messaggi dalla chat
        let messaggi = chat.messaggi?.allObjects as? [MessaggioMarilena] ?? []
        let messaggiOrdinati = messaggi.sorted { 
            ($0.dataCreazione ?? Date()) < ($1.dataCreazione ?? Date()) 
        }
        
        messages = messaggiOrdinati.map { messaggio in
            ChatMessage(
                content: messaggio.contenuto ?? "",
                isUser: messaggio.tipo == "user",
                timestamp: messaggio.dataCreazione ?? Date()
            )
        }
    }
    
    private func setupChatForRecording() {
        // Cerca se esiste già una chat per questa registrazione
        let fetchRequest: NSFetchRequest<ChatMarilena> = ChatMarilena.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "recordingId == %@", recording.id?.uuidString ?? "")
        
        do {
            let existingChats = try context.fetch(fetchRequest)
            if let existingChat = existingChats.first {
                self.chatMarilena = existingChat
                loadMessages()
                return
            }
        } catch {
            print("Errore ricerca chat esistente: \(error)")
        }
        
        // Crea nuova chat se non esiste
        createNewChat()
    }
    
    private func createNewChat() {
        let newChat = ChatMarilena(context: context)
        newChat.id = UUID()
        newChat.dataCreazione = Date()
        newChat.titolo = "Chat: \(recording.titolo ?? "Registrazione")"
        newChat.recordingId = recording.id?.uuidString
        newChat.tipo = "transcription"
        
        // Associa al profilo utente
        if let profilo = profiloService.ottieniProfiloUtente(in: context) {
            newChat.profilo = profilo
        }
        
        // Aggiungi automaticamente la trascrizione come primo messaggio
        if let transcription = transcription,
           let transcriptionText = transcription.testoCompleto,
           !transcriptionText.isEmpty {
            
            let transcriptionMessage = MessaggioMarilena(context: context)
            transcriptionMessage.id = UUID()
            transcriptionMessage.contenuto = "📝 **Trascrizione:**\n\n\(transcriptionText)"
            transcriptionMessage.tipo = "transcription"
            transcriptionMessage.dataCreazione = Date()
            transcriptionMessage.chat = newChat
            
            // Aggiungi anche alla UI
            let transcriptionChatMessage = ChatMessage(
                content: "📝 **Trascrizione:**\n\n\(transcriptionText)",
                isUser: false,
                timestamp: Date()
            )
            messages.append(transcriptionChatMessage)
        }
        
        do {
            try context.save()
            self.chatMarilena = newChat
        } catch {
            print("Errore creazione chat: \(error)")
        }
    }
    
    func sendMessage(_ text: String) async {
        guard let transcription = transcription,
              let transcriptionText = transcription.testoCompleto,
              !transcriptionText.isEmpty,
              let chat = chatMarilena else {
            return
        }
        
        // Crea e salva messaggio utente
        let userMessaggio = MessaggioMarilena(context: context)
        userMessaggio.id = UUID()
        userMessaggio.contenuto = text
        userMessaggio.tipo = "user"
        userMessaggio.dataCreazione = Date()
        userMessaggio.chat = chat
        
        // Aggiungi messaggio utente alla UI
        let userMessage = ChatMessage(
            content: text,
            isUser: true,
            timestamp: Date()
        )
        messages.append(userMessage)
        
        isProcessing = true
        
        // Elabora risposta
        let response = await processQuestion(text, transcriptionText: transcriptionText)
        
        // Crea e salva messaggio AI
        let aiMessaggio = MessaggioMarilena(context: context)
        aiMessaggio.id = UUID()
        aiMessaggio.contenuto = response.answer
        aiMessaggio.tipo = "ai"
        aiMessaggio.dataCreazione = Date()
        aiMessaggio.chat = chat
        
        // Aggiungi risposta AI alla UI
        let aiMessage = ChatMessage(
            content: response.answer,
            isUser: false,
            timestamp: Date(),
            confidence: response.confidence
        )
        messages.append(aiMessage)
        
        // Aggiorna titolo chat se necessario
        if chat.messaggi?.count == 2 { // Primo scambio
            chat.titolo = "Chat: \(recording.titolo ?? "Registrazione")"
        }
        
        // Salva tutto nel context
        do {
            try context.save()
        } catch {
            print("Errore salvataggio messaggi: \(error)")
        }
        
        isProcessing = false
    }
    
    private func processQuestion(_ question: String, transcriptionText: String) async -> (answer: String, confidence: Double) {
        
        // Analizza il tipo di domanda
        let questionType = analyzeQuestionType(question)
        
        switch questionType {
        case .summary:
            return generateSummary(transcriptionText)
            
        case .search:
            return searchInText(question, text: transcriptionText)
            
        case .sentiment:
            return analyzeSentiment(transcriptionText)
            
        case .topics:
            return extractTopics(transcriptionText)
            
        case .entities:
            return extractEntities(transcriptionText)
            
        case .general:
            return answerGeneral(question, text: transcriptionText)
        }
    }
    
    // MARK: - Question Analysis
    
    private func analyzeQuestionType(_ question: String) -> QuestionType {
        let lowercased = question.lowercased()
        
        if lowercased.contains("riassun") || lowercased.contains("sommario") || lowercased.contains("punti chiave") {
            return .summary
        }
        
        if lowercased.contains("cerca") || lowercased.contains("trova") || lowercased.contains("dove") {
            return .search
        }
        
        if lowercased.contains("sentiment") || lowercased.contains("tono") || lowercased.contains("emozione") {
            return .sentiment
        }
        
        if lowercased.contains("argomento") || lowercased.contains("tema") || lowercased.contains("di cosa parla") {
            return .topics
        }
        
        if lowercased.contains("nomi") || lowercased.contains("persone") || lowercased.contains("luoghi") || lowercased.contains("date") {
            return .entities
        }
        
        return .general
    }
    
    // MARK: - Response Generators
    
    private func generateSummary(_ text: String) -> (answer: String, confidence: Double) {
        tokenizer.string = text
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            sentences.append(String(text[range]))
            return true
        }
        // Seleziona le prime 3-5 frasi più significative
        let keywordSentences = sentences.prefix(5)
        let summary = keywordSentences.joined(separator: " ")

        // Calcola confidence basata sulla lunghezza e coerenza
        let confidence = min(Double(keywordSentences.count) / 5.0, 0.9)

        return ("**Riassunto:**\n\n\(summary)", confidence)
    }
    
    private func searchInText(_ question: String, text: String) -> (answer: String, confidence: Double) {
        // Estrai parole chiave dalla domanda
        let keywords = extractKeywords(from: question)
        
        var results: [String] = []
        let sentences = text.components(separatedBy: ".")
        
        for sentence in sentences {
            for keyword in keywords {
                if sentence.localizedCaseInsensitiveContains(keyword) {
                    results.append(sentence.trimmingCharacters(in: .whitespacesAndNewlines))
                    break
                }
            }
        }
        
        if results.isEmpty {
            return ("Non ho trovato informazioni specifiche su questo argomento nella trascrizione.", 0.3)
        }
        
        let answer = "**Risultati trovati:**\n\n" + results.prefix(3).joined(separator: "\n\n")
        let confidence = min(Double(results.count) / 3.0, 0.8)
        
        return (answer, confidence)
    }
    
    private func analyzeSentiment(_ text: String) -> (answer: String, confidence: Double) {
        sentimentAnalyzer.string = text
        
        let (sentimentTag, _) = sentimentAnalyzer.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)

        let sentimentScore = Double(sentimentTag?.rawValue ?? "0") ?? 0.0
        
        let sentimentDescription: String
        if sentimentScore > 0.3 {
            sentimentDescription = "positivo"
        } else if sentimentScore < -0.3 {
            sentimentDescription = "negativo"
        } else {
            sentimentDescription = "neutro"
        }
        
        let answer = """
        **Analisi del Sentiment:**
        
        Il tono generale della conversazione è **\(sentimentDescription)**.
        
        Punteggio sentiment: \(String(format: "%.2f", sentimentScore)) (-1.0 = molto negativo, +1.0 = molto positivo)
        """
        
        return (answer, 0.7)
    }
    
    private func extractTopics(_ text: String) -> (answer: String, confidence: Double) {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = text
        
        var keywords: [String] = []
        var entities: [String] = []
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            let word = String(text[tokenRange])
            
            if let tag = tag, tag == .noun && word.count > 4 {
                keywords.append(word.lowercased())
            }
            
            return true
        }
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, tokenRange in
            let word = String(text[tokenRange])
            
            if tag != nil {
                entities.append(word)
            }
            
            return true
        }
        
        // Rimuovi duplicati e prendi i più frequenti
        let uniqueKeywords = Array(Set(keywords)).prefix(5)
        let uniqueEntities = Array(Set(entities)).prefix(5)
        
        var answer = "**Argomenti Principali:**\n\n"
        
        if !uniqueKeywords.isEmpty {
            answer += "• " + uniqueKeywords.joined(separator: "\n• ") + "\n\n"
        }
        
        if !uniqueEntities.isEmpty {
            answer += "**Entità Riconosciute:**\n• " + uniqueEntities.joined(separator: "\n• ")
        }
        
        let confidence = Double(uniqueKeywords.count + uniqueEntities.count) / 10.0
        
        return (answer, min(confidence, 0.8))
    }
    
    private func extractEntities(_ text: String) -> (answer: String, confidence: Double) {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        
        var people: [String] = []
        var places: [String] = []
        var organizations: [String] = []
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, tokenRange in
            let entity = String(text[tokenRange])
            
            switch tag {
            case .personalName:
                people.append(entity)
            case .placeName:
                places.append(entity)
            case .organizationName:
                organizations.append(entity)
            default:
                break
            }
            
            return true
        }
        
        var answer = "**Entità Estratte:**\n\n"
        
        if !people.isEmpty {
            answer += "**Persone:** " + Array(Set(people)).joined(separator: ", ") + "\n\n"
        }
        
        if !places.isEmpty {
            answer += "**Luoghi:** " + Array(Set(places)).joined(separator: ", ") + "\n\n"
        }
        
        if !organizations.isEmpty {
            answer += "**Organizzazioni:** " + Array(Set(organizations)).joined(separator: ", ")
        }
        
        if people.isEmpty && places.isEmpty && organizations.isEmpty {
            answer = "Non ho rilevato entità specifiche (nomi, luoghi, organizzazioni) nella trascrizione."
        }
        
        let totalEntities = people.count + places.count + organizations.count
        let confidence = min(Double(totalEntities) / 5.0, 0.8)
        
        return (answer, confidence)
    }
    
    private func answerGeneral(_ question: String, text: String) -> (answer: String, confidence: Double) {
        // Per domande generali, cerca corrispondenze semantiche semplici
        let questionKeywords = extractKeywords(from: question)
        let textSentences = text.components(separatedBy: ".")
        
        var bestMatch = ""
        var bestScore = 0.0
        
        for sentence in textSentences {
            let sentenceKeywords = extractKeywords(from: sentence)
            let score = calculateSimilarity(questionKeywords, sentenceKeywords)
            
            if score > bestScore {
                bestScore = score
                bestMatch = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        if bestScore > 0.3 && !bestMatch.isEmpty {
            return ("Basandomi sulla trascrizione:\n\n\(bestMatch)", bestScore)
        } else {
            return ("Non sono riuscito a trovare informazioni specifiche su questa domanda nella trascrizione. Prova a riformulare la domanda o a essere più specifico.", 0.2)
        }
    }
    
    // MARK: - Helper Methods
    
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
}

// MARK: - Supporting Types

struct ChatMessage {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    let confidence: Double?
    
    init(content: String, isUser: Bool, timestamp: Date, confidence: Double? = nil) {
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.confidence = confidence
    }
}

enum QuestionType {
    case summary
    case search
    case sentiment
    case topics
    case entities
    case general
} 

