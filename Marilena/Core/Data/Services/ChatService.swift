import Foundation
import Combine
import CoreData

// MARK: - Chat Service (Riusabile)
// Servizio di chat AI modulare e riutilizzabile con tutte le funzionalità avanzate

@MainActor
public class ChatService: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var messages: [ModularChatMessage] = []
    @Published public var isProcessing = false
    @Published public var error: String?
    @Published public var currentSession: ChatSession?
    @Published public var coreDataChat: ChatMarilena?
    
    // MARK: - Configuration
    private let aiProviderManager: AIProviderManager
    private let promptManager: PromptManager
    private let configuration: ChatConfiguration?
    
    // MARK: - Core Data
    private let context: NSManagedObjectContext
    private let moduleAdapter: ModuleAdapter
    
    // MARK: - Services
    private let openAIService = OpenAIService.shared
    private let profiloService = ProfiloUtenteService.shared
    private let perplexityService = PerplexityService.shared
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var processingStartTime: Date?
    private var selectedModel = "gpt-4o-mini"
    private var selectedPerplexityModel = "sonar-pro"
    private var streamingToolCallBuilders: [UUID: [Int: ToolCallAccumulator]] = [:]
    
    private struct ToolCallAccumulator {
        var id: String?
        var name: String?
        var arguments: String
        var isCompleted: Bool

        init(id: String? = nil, name: String? = nil, arguments: String = "", isCompleted: Bool = false) {
            self.id = id
            self.name = name
            self.arguments = arguments
            self.isCompleted = isCompleted
        }
    }
    
    // MARK: - Initialization
    
    @MainActor
    public init(
        aiProviderManager: AIProviderManager,
        promptManager: PromptManager,
        configuration: ChatConfiguration? = nil,
        context: NSManagedObjectContext? = nil
    ) {
        self.aiProviderManager = aiProviderManager
        self.promptManager = promptManager
        self.configuration = configuration
        self.context = context ?? PersistenceController.shared.container.viewContext
        self.moduleAdapter = ModuleAdapter(context: self.context)
        
        // Carica modelli salvati
        self.selectedModel = UserDefaults.standard.string(forKey: "selected_model") ?? "gpt-4o-mini"
        self.selectedPerplexityModel = UserDefaults.standard.string(forKey: "selected_perplexity_model") ?? "sonar-pro"
        
        setupObservers()
        loadOrCreateDefaultSession()
    }
    
    // MARK: - Public Methods
    
    /// Invia un messaggio e riceve la risposta AI
    public func sendMessage(_ text: String, context: String = "") async {
        let userMessage = ModularChatMessage(
            content: text,
            role: .user,
            metadata: MessageMetadata(context: context)
        )
        
        messages.append(userMessage)
        isProcessing = true
        error = nil
        processingStartTime = Date()
        
        // Salva il messaggio utente in Core Data
        saveCoreDataMessage(userMessage)
        
        // Fallback streaming via Cloudflare Gateway se manca la chiave OpenAI
        let forceGateway = UserDefaults.standard.bool(forKey: "force_gateway")
        let hasOpenAIKey = (KeychainManager.shared.load(key: "openai_api_key") ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let useResponsesAPI = UserDefaults.standard.bool(forKey: "use_responses_api")
        let enableResponsesStreaming = UserDefaults.standard.bool(forKey: "enable_responses_streaming")
        if forceGateway || !hasOpenAIKey {
            let assistantId = UUID()
            let userContext = getUserContext()
            let assistantMessage = ModularChatMessage(
                id: assistantId,
                content: "",
                role: .assistant,
                metadata: MessageMetadata(
                    model: selectedModel,
                    context: userContext,
                    provider: "CloudflareGateway"
                )
            )
            messages.append(assistantMessage)

            // Costruisci cronologia
            let conversationHistory = buildConversationHistory(newMessage: text, context: userContext)
            let temperature = UserDefaults.standard.double(forKey: "temperature")
            let maxTokens = Int(UserDefaults.standard.double(forKey: "max_tokens"))

            CloudflareGatewayClient.shared.streamChat(
                messages: conversationHistory,
                model: selectedModel,
                maxTokens: maxTokens == 0 ? nil : maxTokens,
                temperature: temperature == 0 ? nil : temperature,
                onChunk: { [weak self] delta in
                    guard let self = self else { return }
                    if let idx = self.messages.firstIndex(where: { $0.id == assistantId }) {
                        let updated = ModularChatMessage(
                            id: assistantId,
                            content: self.messages[idx].content + delta,
                            role: .assistant,
                            timestamp: self.messages[idx].timestamp,
                            metadata: self.messages[idx].metadata
                        )
                        self.messages[idx] = updated
                    }
                },
                onComplete: { [weak self] in
                    guard let self = self else { return }
                    self.isProcessing = false
                    self.processingStartTime = nil
                    // Salva la risposta finale in Core Data
                    if let idx = self.messages.firstIndex(where: { $0.id == assistantId }) {
                        self.saveCoreDataMessage(self.messages[idx])
                    }
                    self.updateCurrentSession()
                    self.updateCoreDataSession()
                },
                onError: { [weak self] error in
                    guard let self = self else { return }
                    self.error = error.localizedDescription
                    self.isProcessing = false
                    self.processingStartTime = nil
                    print("❌ ChatService: Errore streaming gateway: \(error)")
                }
            )
            return
        }

        if useResponsesAPI && enableResponsesStreaming {
            let assistantId = UUID()
            let userContext = getUserContext()
            let assistantMessage = ModularChatMessage(
                id: assistantId,
                content: "",
                role: .assistant,
                metadata: MessageMetadata(
                    model: selectedModel,
                    context: userContext,
                    provider: "OpenAI"
                )
            )
            messages.append(assistantMessage)

            let conversationHistory = buildConversationHistory(newMessage: text, context: userContext)

            streamingToolCallBuilders[assistantId] = [:]

            openAIService.streamMessage(
                messages: conversationHistory,
                model: selectedModel,
                onChunk: { [weak self] delta in
                    guard let self = self else { return }
                    if let idx = self.messages.firstIndex(where: { $0.id == assistantId }) {
                        let updated = ModularChatMessage(
                            id: assistantId,
                            content: self.messages[idx].content + delta,
                            role: .assistant,
                            timestamp: self.messages[idx].timestamp,
                            metadata: self.messages[idx].metadata
                        )
                        self.messages[idx] = updated
                    }
                },
                onToolCallDelta: { [weak self] delta in
                    self?.handleToolCallDelta(delta, assistantId: assistantId)
                },
                onUsageDelta: { [weak self] usage in
                    self?.handleUsageDelta(usage, assistantId: assistantId)
                },
                onComplete: { [weak self] in
                    guard let self = self else { return }
                    self.isProcessing = false
                    self.processingStartTime = nil
                    if let idx = self.messages.firstIndex(where: { $0.id == assistantId }) {
                        self.saveCoreDataMessage(self.messages[idx])
                    }
                    self.updateCurrentSession()
                    self.updateCoreDataSession()
                    self.streamingToolCallBuilders.removeValue(forKey: assistantId)
                },
                onError: { [weak self] error in
                    guard let self = self else { return }
                    self.error = error.localizedDescription
                    self.isProcessing = false
                    self.processingStartTime = nil
                    print("❌ ChatService: Errore streaming Responses API: \(error)")
                    self.streamingToolCallBuilders.removeValue(forKey: assistantId)
                }
            )
            return
        }

        do {
            // Ottieni il contesto utente dal profilo
            let userContext = getUserContext()
            let response = try await processMessage(text, context: userContext)
            let processingTime = processingStartTime.map { Date().timeIntervalSince($0) }
            
            let aiMessage = ModularChatMessage(
                content: response,
                role: .assistant,
                metadata: MessageMetadata(
                    model: selectedModel,
                    processingTime: processingTime,
                    context: userContext,
                    provider: "OpenAI"
                )
            )
            messages.append(aiMessage)
            
            // Salva la risposta AI in Core Data
            saveCoreDataMessage(aiMessage)
            
            // Aggiorna la sessione
            updateCurrentSession()
            updateCoreDataSession()
            
        } catch {
            self.error = error.localizedDescription
            print("❌ ChatService: Errore durante l'elaborazione: \(error)")
        }
        
        isProcessing = false
        processingStartTime = nil
    }
    
    /// Ricerca con Perplexity
    public func searchWithPerplexity(_ query: String) async throws -> String {
        return try await perplexityService.search(
            query: query,
            model: selectedPerplexityModel
        )
    }
    
    /// Cancella tutti i messaggi
    public func clearMessages() {
        messages.removeAll()
        error = nil
        
        // Cancella messaggi da Core Data
        clearCoreDataMessages()
        updateCurrentSession()
        updateCoreDataSession()
    }
    
    /// Esporta la conversazione
    public func exportConversation() -> String {
        return messages.map { message in
            "\(message.role.displayName): \(message.content)"
        }.joined(separator: "\n\n")
    }
    
    /// Crea una nuova sessione di chat
    public func createSession(title: String, context: String? = nil) {
        // Crea sessione modulare
        currentSession = ChatSession(
            title: title,
            messages: messages
        )
        
        // Crea entità Core Data
        createCoreDataSession(title: title)
    }
    
    /// Carica una sessione esistente
    public func loadSession(_ session: ChatSession) {
        messages = session.messages
        currentSession = session
        error = nil
        
        // Carica la sessione Core Data corrispondente
        loadCoreDataSession(sessionId: session.id)
    }
    
    /// Carica una sessione da Core Data
    public func loadCoreDataSession(_ chat: ChatMarilena) {
        coreDataChat = chat
        
        // Carica messaggi dalla chat
        let messaggi = chat.messaggi?.allObjects as? [MessaggioMarilena] ?? []
        let messaggiOrdinati = messaggi.sorted { 
            ($0.dataCreazione ?? Date()) < ($1.dataCreazione ?? Date()) 
        }
        
        // Converti in ModularChatMessage
        messages = messaggiOrdinati.map { messaggio in
            ModularChatMessage(
                id: messaggio.id ?? UUID(),
                content: messaggio.contenuto ?? "",
                role: messaggio.isUser ? .user : .assistant,
                timestamp: messaggio.dataCreazione ?? Date(),
                metadata: MessageMetadata(
                    model: selectedModel,
                    context: getUserContext()
                )
            )
        }
        
        // Crea sessione modulare corrispondente
        currentSession = ChatSession(
            id: chat.id ?? UUID(),
            title: chat.titolo ?? "Chat",
            messages: messages,
            createdAt: chat.dataCreazione ?? Date(),
            updatedAt: Date(),
            type: chat.tipo ?? "chat"
        )
        
        error = nil
    }
    
    /// Alias per loadCoreDataSession
    public func loadChat(_ chat: ChatMarilena) {
        loadCoreDataSession(chat)
    }
    
    /// Ottieni statistiche della conversazione
    public func getConversationStats() -> ConversationStats {
        let totalMessages = messages.count
        let userMessages = messages.filter { $0.role == .user }.count
        let assistantMessages = messages.filter { $0.role == .assistant }.count
        
        let totalTokens = messages.compactMap { $0.metadata?.tokens }.reduce(0, +)
        
        let processingTimes = messages.compactMap { $0.metadata?.processingTime }
        let averageProcessingTime = processingTimes.isEmpty ? 0 : processingTimes.reduce(0, +) / Double(processingTimes.count)
        
        return ConversationStats(
            totalMessages: totalMessages,
            userMessages: userMessages,
            assistantMessages: assistantMessages,
            totalTokens: totalTokens,
            averageProcessingTime: averageProcessingTime
        )
    }
    
    /// Imposta il modello selezionato
    public func setSelectedModel(_ model: String) {
        selectedModel = model
        UserDefaults.standard.set(model, forKey: "selected_model")
    }
    
    /// Imposta il modello Perplexity selezionato
    public func setSelectedPerplexityModel(_ model: String) {
        selectedPerplexityModel = model
        UserDefaults.standard.set(model, forKey: "selected_perplexity_model")
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Osserva cambiamenti nei messaggi per aggiornare la sessione
        $messages
            .sink { [weak self] _ in
                self?.updateCurrentSession()
            }
            .store(in: &cancellables)
    }
    
    private func loadOrCreateDefaultSession() {
        // Carica l'ultima chat dell'utente o creane una nuova
        if let profilo = profiloService.ottieniProfiloUtente(in: context) {
            let chats = profilo.chats?.allObjects as? [ChatMarilena] ?? []
            let chatOrdinati = chats.sorted { 
                ($0.dataCreazione ?? Date()) > ($1.dataCreazione ?? Date()) 
            }
            
            if let ultimaChat = chatOrdinati.first, 
               let messaggi = ultimaChat.messaggi?.allObjects as? [MessaggioMarilena],
               !messaggi.isEmpty {
                // Carica l'ultima chat con messaggi
                loadCoreDataSession(ultimaChat)
            } else {
                // Crea una nuova sessione
                createSession(title: "Nuova Conversazione")
            }
        } else {
            // Crea una nuova sessione se non c'è profilo
            createSession(title: "Nuova Conversazione")
        }
    }
    
    private func processMessage(_ text: String, context: String = "") async throws -> String {
        // Costruisci la cronologia della conversazione
        let conversationHistory = buildConversationHistory(newMessage: text, context: context)
        
        // Invia a OpenAI
        let response = try await withCheckedThrowingContinuation { continuation in
            openAIService.sendMessage(
                messages: conversationHistory,
                model: selectedModel
            ) { result in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
        
        return response
    }
    
    private func buildConversationHistory(newMessage: String, context: String = "") -> [OpenAIMessage] {
        var messages: [OpenAIMessage] = []

        // Sistema prompt con contesto utente usando PromptManager
        let systemPrompt = PromptManager.getPrompt(for: .chatBase, replacements: [
            "CONTESTO_UTENTE": context.isEmpty ? "Nessun contesto specifico disponibile" : context
        ])
        messages.append(OpenAIMessage(role: "system", content: systemPrompt))

        // Aggiungi cronologia conversazione (ultimi 15 messaggi)
        let recentMessages = Array(self.messages.suffix(15))
        for message in recentMessages {
            // Salta i placeholder vuoti (ad es. assistant appena creato per streaming)
            if message.role == .assistant && message.content.isEmpty {
                continue
            }
            messages.append(OpenAIMessage(
                role: message.role.rawValue,
                content: message.content
            ))
        }
        
        // Aggiungi nuovo messaggio
        messages.append(OpenAIMessage(role: "user", content: newMessage))
        
        return messages
    }
    
    private func updateCurrentSession() {
        if let session = currentSession {
            currentSession = ChatSession(
                id: session.id,
                title: session.title,
                messages: messages,
                createdAt: session.createdAt,
                updatedAt: Date(),
                type: session.type
            )
        }
    }
    
    // MARK: - Core Data Methods
    
    private func getUserContext() -> String {
        if let profilo = profiloService.ottieniProfiloUtente(in: context) {
            return profilo.contestoAI ?? "Nessun contesto specifico disponibile"
        }
        return "Nessun contesto specifico disponibile"
    }
    
    private func createCoreDataSession(title: String) {
        let chat = ChatMarilena(context: context)
        chat.id = UUID()
        chat.dataCreazione = Date()
        chat.titolo = title
        chat.tipo = "chat"
        
        // Associa al profilo utente
        if let profilo = profiloService.ottieniProfiloUtente(in: context) {
            chat.profilo = profilo
        }
        
        coreDataChat = chat
        
        do {
            try context.save()
            print("✅ ChatService: Sessione Core Data creata")
        } catch {
            print("❌ ChatService: Errore creazione sessione: \(error)")
        }
    }
    
    private func loadCoreDataSession(sessionId: UUID) {
        let fetchRequest: NSFetchRequest<ChatMarilena> = ChatMarilena.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", sessionId as CVarArg)
        
        do {
            let chats = try context.fetch(fetchRequest)
            if let chat = chats.first {
                loadCoreDataSession(chat)
            }
        } catch {
            print("❌ ChatService: Errore caricamento sessione: \(error)")
        }
    }
    
    private func updateCoreDataSession() {
        guard let chat = coreDataChat else { return }
        
        // Aggiorna titolo se è la prima conversazione
        if messages.count == 2 && messages.first?.role == .user {
            let firstUserMessage = messages.first?.content ?? ""
            let shortTitle = String(firstUserMessage.prefix(50))
            chat.titolo = shortTitle.isEmpty ? "Nuova Conversazione" : shortTitle
        }
        
        do {
            try context.save()
        } catch {
            print("❌ ChatService: Errore aggiornamento sessione: \(error)")
        }
    }
    
    private func saveCoreDataMessage(_ message: ModularChatMessage) {
        guard let _ = coreDataChat else {
            // Se non c'è una chat, creane una
            createCoreDataSession(title: "Nuova Conversazione")
            guard coreDataChat != nil else { return }
            return saveCoreDataMessage(message) // Richiama ricorsivamente dopo aver creato la chat
        }
        
        let messaggio = MessaggioMarilena(context: context)
        messaggio.id = message.id
        messaggio.contenuto = message.content
        messaggio.isUser = message.role == .user
        messaggio.tipo = message.role.rawValue
        messaggio.dataCreazione = message.timestamp
        messaggio.chat = coreDataChat
        
        do {
            try context.save()
        } catch {
            print("❌ ChatService: Errore salvataggio messaggio: \(error)")
        }
    }
    
    private func clearCoreDataMessages() {
        guard let chat = coreDataChat else { return }
        
        let messaggi = chat.messaggi?.allObjects as? [MessaggioMarilena] ?? []
        for messaggio in messaggi {
            context.delete(messaggio)
        }
        
        do {
            try context.save()
        } catch {
            print("❌ ChatService: Errore cancellazione messaggi: \(error)")
        }
    }
}

// MARK: - Streaming Handling
private extension ChatService {
    func handleToolCallDelta(_ delta: AIToolCallDelta, assistantId: UUID) {
        guard let messageIndex = messages.firstIndex(where: { $0.id == assistantId }) else { return }

        var builders = streamingToolCallBuilders[assistantId] ?? [:]
        var builder = builders[delta.index] ?? ToolCallAccumulator()
        if let id = delta.id, !id.isEmpty { builder.id = id }
        if let name = delta.name, !name.isEmpty { builder.name = name }
        if !delta.argumentsDelta.isEmpty { builder.arguments += delta.argumentsDelta }
        if delta.isCompleted { builder.isCompleted = true }
        builders[delta.index] = builder
        streamingToolCallBuilders[assistantId] = builders

        let toolCalls = builders
            .sorted { $0.key < $1.key }
            .map { entry in
                MessageToolCall(
                    id: entry.value.id,
                    name: entry.value.name,
                    arguments: entry.value.arguments,
                    isCompleted: entry.value.isCompleted
                )
            }

        let currentMessage = messages[messageIndex]
        let updatedMetadata: MessageMetadata
        if let metadata = currentMessage.metadata {
            updatedMetadata = metadata.with(toolCalls: toolCalls)
        } else {
            updatedMetadata = MessageMetadata(
                model: selectedModel,
                provider: "OpenAI",
                toolCalls: toolCalls
            )
        }

        messages[messageIndex] = ModularChatMessage(
            id: currentMessage.id,
            content: currentMessage.content,
            role: currentMessage.role,
            timestamp: currentMessage.timestamp,
            metadata: updatedMetadata
        )
    }

    func handleUsageDelta(_ usage: AIUsageDelta, assistantId: UUID) {
        guard let messageIndex = messages.firstIndex(where: { $0.id == assistantId }) else { return }

        let currentMessage = messages[messageIndex]
        let existingMetadata = currentMessage.metadata ?? MessageMetadata(
            model: selectedModel,
            provider: "OpenAI"
        )

        let totalTokens = usage.totalTokens ?? existingMetadata.tokens ?? usage.completionTokens ?? usage.promptTokens
        let updatedMetadata = existingMetadata.with(tokens: totalTokens)

        messages[messageIndex] = ModularChatMessage(
            id: currentMessage.id,
            content: currentMessage.content,
            role: currentMessage.role,
            timestamp: currentMessage.timestamp,
            metadata: updatedMetadata
        )
    }
}

// MARK: - Conversation Stats

public struct ConversationStats {
    public let totalMessages: Int
    public let userMessages: Int
    public let assistantMessages: Int
    public let totalTokens: Int
    public let averageProcessingTime: TimeInterval
    
    public init(
        totalMessages: Int,
        userMessages: Int,
        assistantMessages: Int,
        totalTokens: Int,
        averageProcessingTime: TimeInterval
    ) {
        self.totalMessages = totalMessages
        self.userMessages = userMessages
        self.assistantMessages = assistantMessages
        self.totalTokens = totalTokens
        self.averageProcessingTime = averageProcessingTime
    }
} 
